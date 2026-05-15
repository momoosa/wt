//
//  PlanningIntegration.swift
//  Momentum
//
//  Extracted from ContentView.swift — AI Planning methods
//

import SwiftUI
import SwiftData
import MomentumKit
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - AI Planning

extension ContentView {
    
    /// Parse a time string (e.g., "09:30") and combine it with a date to create a full Date object
    func parseTimeString(_ timeString: String, for date: Date) -> Date? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else {
            return nil
        }
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hours
        dateComponents.minute = minutes
        dateComponents.second = 0
        
        return calendar.date(from: dateComponents)
    }
    
    /// Generate a daily plan and create GoalSession objects
    func generateDailyPlan() async {
        await MainActor.run {
            planningViewModel.isPlanning = true
            planningViewModel.showPlanningComplete = false
            // Clear previous revealed sessions
            planningViewModel.revealedSessionIDs.removeAll()
        }
        defer { 
            Task { @MainActor in
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    planningViewModel.isPlanning = false
                    planningViewModel.planningTask = nil
                    return
                }
                
                // Show completion state immediately when planning finishes
                planningViewModel.isPlanning = false
                planningViewModel.planningTask = nil
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    planningViewModel.showPlanningComplete = true
                }
                
                // Keep completion state visible for 0.6 seconds
                try? await Task.sleep(for: .seconds(0.6))
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    planningViewModel.showPlanningComplete = false
                }
                
                // Update timestamp to cache when plan was last generated
                lastPlanGeneratedTimestamp = Date().timeIntervalSince1970
                AppLogger.planner.debug("Updated plan generation timestamp")
                
                // Reload widgets to show updated sessions
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
        
        do {
            // Generate the plan using active goals
            var activeGoals = goals.filter { $0.status == .active }
            
            // Filter by selected themes if any are selected
            if !planningViewModel.selectedThemes.isEmpty {
                activeGoals = activeGoals.filter { goal in
                    guard let primaryTag = goal.primaryTag else { return false }
                    return planningViewModel.selectedThemes.contains(primaryTag.themeID)
                }
            }
            
            // Set max sessions in planner preferences
            var preferences = planningViewModel.plannerPreferences
            if !unlimitedPlannedSessions {
                preferences.maxSessionsPerDay = maxPlannedSessions
            } else {
                preferences.maxSessionsPerDay = 100 // Effectively unlimited
            }
            
            // Apply time-based limit (assuming ~30 minutes per session on average)
            let timeBasedMaxSessions = planningViewModel.availableTimeMinutes / 30
            preferences.maxSessionsPerDay = min(
                preferences.maxSessionsPerDay,
                max(1, timeBasedMaxSessions)
            )
            
            // Clear planning details at the start to give a "from scratch" appearance
            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    for session in sessions {
                        session.clearPlanningDetails()
                    }
                    modelContext.safeSave()
                }
            }
            
            // Use streaming to get real-time updates
            let stream = planningViewModel.planner.streamDailyPlan(
                for: activeGoals,
                goalSessions: sessions,
                currentDate: day.startDate,
                userPreferences: preferences
            )
            
            var latestPlan: DailyPlan?
            
            for try await partialPlan in stream {
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    AppLogger.planner.debug("Planning cancelled by user")
                    return
                }
                
                // Convert partial plan to full plan if we have sessions
                if let sessions = partialPlan.sessions {
                    let fullyGeneratedSessions = sessions.compactMap { partialSession -> PlannedSession? in
                        guard let id = partialSession.id,
                              let goalTitle = partialSession.goalTitle,
                              let recommendedStartTime = partialSession.recommendedStartTime,
                              let suggestedDuration = partialSession.suggestedDuration,
                              let priority = partialSession.priority,
                              let reasoning = partialSession.reasoning else {
                            return nil
                        }
                        
                        return PlannedSession(
                            id: id,
                            goalTitle: goalTitle,
                            recommendedStartTime: recommendedStartTime,
                            suggestedDuration: suggestedDuration,
                            priority: priority,
                            reasoning: reasoning
                        )
                    }
                    
                    // Only update latestPlan - don't apply yet to avoid reordering during streaming
                    if !fullyGeneratedSessions.isEmpty {
                        let plan = DailyPlan(
                            sessions: fullyGeneratedSessions,
                            overallStrategy: partialPlan.overallStrategy ?? nil
                        )
                        latestPlan = plan
                    }
                }
            }
            
            // Apply the final plan once after streaming completes
            if let plan = latestPlan {
                await applyPlan(plan)
                await animatePlannedSessions(plan)

                
                // Clear planning details for sessions NOT in the plan
                await MainActor.run {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        let plannedGoalIDs = Set(plan.sessions.compactMap { UUID(uuidString: $0.id) })
                        for session in sessions {
                            guard let goalID = session.goal?.id else { continue }
                            if !plannedGoalIDs.contains(goalID) {
                                session.clearPlanningDetails()
                            }
                        }
                        modelContext.safeSave()
                    }
                }
            }
            
            // Ensure all active goals have sessions (even if not in the plan)
            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    let allActiveGoals = goals.filter { $0.status == .active }
                    let existingSessionGoalIDs = Set(sessions.compactMap { $0.goal?.id })
                    
                    for goal in allActiveGoals {
                        if !existingSessionGoalIDs.contains(goal.id) {
                            // Create session for goal not in the plan
                            let session = GoalSession(title: goal.title, goal: goal, day: day)
                            session.status = .active
                            modelContext.insert(session)
                            
                            // Create checklist item sessions for this goal session
                            if let checklistItems = goal.checklistItems {
                                for checklistItem in checklistItems {
                                    let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                                    modelContext.insert(itemSession)
                                    session.checklist?.append(itemSession)
                                }
                            }
                        }
                    }
                    
                    modelContext.safeSave()
                }
            }
            
        } catch {
            AppLogger.planner.error("Planning failed: \(error)")
            
            // Show error alert
            #if os(iOS)
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            #endif
        }
    }
    
    /// Animate the reveal of planned sessions one by one
    func animatePlannedSessions(_ plan: DailyPlan) async {
        // Provide haptic feedback for completion
        #if os(iOS)
        await MainActor.run {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        }
        #endif
    }
    
    /// Analyze historical sessions to find usage patterns for a goal
    func analyzeUsagePattern(for goal: Goal, session: GoalSession, currentHour: Int) -> Bool {
        // Get historical sessions for this specific GoalSession
        let historicalSessions = session.historicalSessions
        
        // Filter to sessions in the past 2 weeks
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recentSessions = historicalSessions.filter { $0.startDate >= twoWeeksAgo }
        
        // Count how many times this goal was worked on in the current hour (+/- 1 hour window)
        let sessionsInTimeWindow = recentSessions.filter { histSession in
            let sessionHour = Calendar.current.component(.hour, from: histSession.startDate)
            return abs(sessionHour - currentHour) <= 1
        }
        
        // If this goal has been worked on 3+ times in this time window over the past 2 weeks, consider it a pattern
        return sessionsInTimeWindow.count >= 3
    }
    
    /// Calculate recommendation reasons for a session
    func calculateRecommendationReasons(for session: GoalSession, goal: Goal) -> [RecommendationReason] {
        var reasons: [RecommendationReason] = []
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let currentWeekday = calendar.component(.weekday, from: Date())
        
        // 1. Weekly Progress - check if behind for the day of week
        let dailyTarget = session.unifiedTargetValue
        let currentProgress = session.currentValue
        let daysIntoWeek = currentWeekday // Sunday = 1, Saturday = 7
        // Use daily target as proxy for weekly progress check
        if currentProgress < dailyTarget * 0.5 && daysIntoWeek >= 4 { // Less than 50% and past Wednesday
            reasons.append(.weeklyProgress)
        }
        
        // 2. Quick Finish - less than 25% remaining
        let remaining = dailyTarget - currentProgress
        if remaining > 0 && remaining < dailyTarget * 0.25 {
            reasons.append(.quickFinish)
        }
        
        // 3. Preferred Time - matches user's preferred time of day
        let preferredTimes = goal.timesForWeekday(currentWeekday)
        if !preferredTimes.isEmpty {
            let matchesPreferred = preferredTimes.contains { timeOfDay in
                switch timeOfDay {
                case .morning: return currentHour >= 6 && currentHour < 10
                case .midday: return currentHour >= 10 && currentHour < 14
                case .afternoon: return currentHour >= 14 && currentHour < 18
                case .evening: return currentHour >= 18 && currentHour < 22
                case .night: return currentHour >= 22 || currentHour < 6
                }
            }
            if matchesPreferred {
                reasons.append(.preferredTime)
            }
        }
        
        // 4. Energy Level - morning/early afternoon are typically high energy
        if (6...9).contains(currentHour) || (13...15).contains(currentHour) {
            reasons.append(.energyLevel)
        }
        
        // 5. Planned Theme - check if matches selected themes
        if let primaryTag = goal.primaryTag, planningViewModel.selectedThemes.contains(primaryTag.themeID) {
            reasons.append(.plannedTheme)
        }
        
        // 6. Usual Time - based on historical usage patterns
        if analyzeUsagePattern(for: goal, session: session, currentHour: currentHour) {
            reasons.append(.usualTime)
        }
        
        return reasons
    }
    
    /// Apply the generated plan by creating GoalSession objects
    @MainActor
    func applyPlan(_ plan: DailyPlan) async {
            // Sort planned sessions by start time to maintain stable order during streaming
            let sortedPlannedSessions = plan.sessions.sorted { session1, session2 in
                // Parse time strings to compare
                if let time1 = parseTimeString(session1.recommendedStartTime, for: day.startDate),
                   let time2 = parseTimeString(session2.recommendedStartTime, for: day.startDate) {
                    return time1 < time2
                }
                // Fallback to priority if times can't be parsed
                return session1.priority < session2.priority
            }
            
            // Create new GoalSession objects for each planned session
            for plannedSession in sortedPlannedSessions {
                // Try to find the goal by UUID first
                var goal: Goal?
                if let goalID = UUID(uuidString: plannedSession.id) {
                    // UUID parsing succeeded - find by ID
                    goal = goals.first(where: { $0.id == goalID })
                }
                
                
                // Fallback: if UUID parsing failed or goal not found, try matching by title
                if goal == nil {
                    goal = goals.first(where: { $0.title == plannedSession.goalTitle })
                }
                
                guard let matchedGoal = goal else {
                    AppLogger.planner.warning("Could not find goal for planned session: \(plannedSession.goalTitle) (ID: \(plannedSession.id))")
                    continue
                }
                
                // Check if a session already exists for this goal
                if let existingSession = sessions.first(where: { $0.goal?.id == matchedGoal.id }) {
                    // Update existing session's planning details
                    // Convert time string (e.g., "09:30") to Date for today
                    if let startTime = parseTimeString(plannedSession.recommendedStartTime, for: day.startDate) {
                        let reasons = calculateRecommendationReasons(for: existingSession, goal: matchedGoal)
                        existingSession.updatePlanningDetails(
                            startTime: startTime,
                            duration: plannedSession.suggestedDuration,
                            priority: plannedSession.priority,
                            reasoning: plannedSession.reasoning,
                            reasons: reasons
                        )
                    }
                    existingSession.status = .active
                } else {
                    // Create a new GoalSession only if one doesn't exist
                    let session = GoalSession(title: matchedGoal.title, goal: matchedGoal, day: day)
                    
                    // Apply planning details
                    // Convert time string (e.g., "09:30") to Date for today
                    if let startTime = parseTimeString(plannedSession.recommendedStartTime, for: day.startDate) {
                        let reasons = calculateRecommendationReasons(for: session, goal: matchedGoal)
                        session.updatePlanningDetails(
                            startTime: startTime,
                            duration: plannedSession.suggestedDuration,
                            priority: plannedSession.priority,
                            reasoning: plannedSession.reasoning,
                            reasons: reasons
                        )
                    }
                    
                    // Mark as active
                    session.status = .active
                    
                    // Insert into model context
                    modelContext.insert(session)
                    
                    // Create checklist item sessions for this goal session
                    if let checklistItems = matchedGoal.checklistItems {
                        for checklistItem in checklistItems {
                            let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                            modelContext.insert(itemSession)
                            session.checklist?.append(itemSession)
                        }
                    }
                }
            }
            
            // Save the new/updated sessions without triggering animations
            var transaction = Transaction()
            transaction.disablesAnimations = true
            _ = withTransaction(transaction) {
                modelContext.safeSave()
            }
    }
}
