//
//  SessionInteractionHandlers.swift
//  Momentum
//
//  Extracted from ContentView.swift — Timer, start time, and daily goal adjustment handlers
//

import SwiftUI
import SwiftData
import MomentumKit
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Session Interaction Handlers

extension ContentView {
    
    func handleTimerToggle(for session: GoalSession) {
        guard let timerManager else { return }
        
        // Check state before toggling
        let wasCompleted = session.hasMetDailyTarget
        let wasRunning = timerManager.activeSession?.id == session.id
        
        // Capture celebration data BEFORE stopping (only on first completion)
        var celebration: CelebrationData?
        if wasRunning && !wasCompleted {
            celebration = captureCelebrationData(for: session)
        }
        
        // Toggle the timer
        timerManager.toggleTimer(for: session, in: day)
        
        // Show celebration if this stop caused first completion
        if let celebration {
            // If NowPlaying is showing, it will dismiss first and the onDismiss triggers celebration
            if navigation.showNowPlaying {
                pendingCelebrationData = celebration
                navigation.showNowPlaying = false
            } else {
                navigation.celebrationData = celebration
            }
        } else if wasCompleted && timerManager.activeSession?.id == session.id {
            // If it was already completed and we just started it, show toast
            navigation.toastConfig = ToastConfig(
                message: "Session resumed - moved to Today",
                showUndo: false
            )
        }
    }
    
    func handleStartTimeAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        guard let timerManager,
              let activeSession = timerManager.activeSession,
              activeSession.id == session.id else { return }
        
        // Adjust start time using the ActiveSessionDetails method
        activeSession.adjustStartTime(by: adjustment)
        
        // Save to UserDefaults
        if let defaults = UserDefaults(suiteName: "group.com.moosa.momentum.ios") {
            defaults.set(activeSession.startDate.timeIntervalSince1970, forKey: "ActiveSessionStartDateV1")
            defaults.synchronize()
        }
        
        let minutes = Int(abs(adjustment) / 60)
        let direction = adjustment > 0 ? "earlier" : "later"
        navigation.toastConfig = ToastConfig(
            message: "Adjusted start time: \(minutes)m \(direction)",
            showUndo: false
        )
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handleDailyGoalAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        // Delegate to ViewModel
        viewModel.adjustDailyTarget(for: session, by: adjustment)
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handle(event: ActionView.Event) {
        guard let timerManager else { return }
        switch event {
        case .stopTapped:
            if let session = sessions.first(where: { $0.id == timerManager.activeSession?.id }) {
                handleTimerToggle(for: session)
            }
        }
    }
    
    func timerText(for session: GoalSession) -> String {
        return timerManager?.timerText(for: session) ?? "00:00"
    }
    
    // MARK: - Celebration Data
    
    func captureCelebrationData(for session: GoalSession) -> CelebrationData? {
        guard let timerManager,
              let activeSession = timerManager.activeSession,
              activeSession.id == session.id,
              let goal = session.goal else { return nil }
        
        // Calculate this session's duration
        let thisSessionDuration = activeSession.elapsedTime + Date().timeIntervalSince(activeSession.startDate)
        
        // Check if target is met (already met or will be met after this session)
        let target = session.effectiveTargetValue
        guard target > 0 else { return nil }
        
        let willBeMet: Bool
        if session.hasMetDailyTarget {
            willBeMet = true
        } else if session.targetUnit.isTimeBased {
            let totalAfterStop = (session.currentValue > 0 ? session.currentValue : session.elapsedTime) + thisSessionDuration
            willBeMet = totalAfterStop >= target
        } else {
            willBeMet = session.currentValue >= target
        }
        
        guard willBeMet else { return nil }
        
        // Count completed sessions today (include this one since it will be complete)
        let todayDoneCount = sessions.filter { $0.hasMetDailyTarget }.count + (session.hasMetDailyTarget ? 0 : 1)
        
        // Calculate streak
        let streak = calculateStreak(for: goal)
        
        // Get suggested next session (exclude the completed goal)
        let suggestedNext: GoalSession? = {
            // Try recommended sessions first
            let recommended = getRecommendedSessions()
            if let next = recommended.first(where: { $0.goal?.id != goal.id && !$0.hasMetDailyTarget }) {
                return next
            }
            // Fall back to any incomplete session
            return sessions.first {
                $0.goal?.id != goal.id && !$0.hasMetDailyTarget && $0.isActiveGoal
            }
        }()
        
        return CelebrationData(
            goalTitle: goal.title,
            goalID: goal.id,
            sessionDuration: thisSessionDuration,
            todayDoneCount: todayDoneCount,
            targetUnit: session.targetUnit,
            theme: session.theme,
            streak: streak,
            suggestedNextSession: suggestedNext
        )
    }
    
    // MARK: - Streak Calculation
    
    private func calculateStreak(for goal: Goal) -> Int {
        let calendar = Calendar.current
        let goalIDString = goal.id.uuidString
        var streak = 1 // Today counts (celebration only triggers when target met)
        
        var checkDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let maxLookback = 365
        
        for _ in 0..<maxLookback {
            let weekday = calendar.component(.weekday, from: checkDate)
            
            // Skip non-scheduled days (don't break streak)
            guard goal.isScheduledDay(weekday) else {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                continue
            }
            
            let dayTarget = goal.unifiedTarget(for: weekday)
            guard dayTarget > 0 else {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                continue
            }
            
            // Fetch the Day by ID
            let dayID = checkDate.yearMonthDayID(with: calendar)
            let descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })
            
            guard let days = try? modelContext.fetch(descriptor),
                  let day = days.first,
                  let historicalSessions = day.historicalSessions else {
                break // No day record = streak broken
            }
            
            let totalDuration = historicalSessions
                .filter { $0.goalIDs.contains(goalIDString) }
                .reduce(0.0) { $0 + $1.duration }
            
            if totalDuration >= dayTarget {
                streak += 1
            } else {
                break // Streak broken
            }
            
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        return streak
    }
    
    // MARK: - Break Session
    
    func startBreakSession() {
        guard let timerManager else { return }
        
        // Find or create a reusable archived "Break" goal
        // Archived status keeps it out of the main goal list and session refresh
        let breakGoal: Goal
        let breakTitle = "Break"
        let descriptor = FetchDescriptor<Goal>(predicate: #Predicate<Goal> { $0.title == breakTitle })
        
        if let existing = (try? modelContext.fetch(descriptor))?.first(where: { $0.status == .archived }) {
            breakGoal = existing
        } else {
            breakGoal = Goal(title: breakTitle)
            breakGoal.iconName = "cup.and.saucer"
            breakGoal.unifiedDailyTarget = 300 // 5 minutes in seconds
            breakGoal.themeID = "palette_07"
            breakGoal.status = .archived
            // Schedule for all days so the session init picks up the target
            for weekday in 1...7 {
                breakGoal.setTimes(Set(TimeOfDay.allCases), forWeekday: weekday)
                breakGoal.perDayTargets[String(weekday)] = 300
            }
            modelContext.insert(breakGoal)
        }
        
        // Create a session for the break
        let breakSession = GoalSession(title: breakTitle, goal: breakGoal, day: day)
        modelContext.insert(breakSession)
        
        // Start the timer and open NowPlaying
        timerManager.toggleTimer(for: breakSession, in: day)
        navigation.showNowPlaying = true
    }
}
