//
//  SetupMethods.swift
//  Momentum
//
//  Extracted from ContentView.swift — Setup, lifecycle, and goals change handling
//

import SwiftUI
import SwiftData
import MomentumKit
import HealthKit
import OSLog

// MARK: - Setup Methods

extension ContentView {
    
    func setupOnAppear() {
        // Guard against re-running setup (e.g., if .task re-fires)
        guard !hasCompletedSetup else { return }
        hasCompletedSetup = true
        
        // Sync ViewModel's timerManager with ContentView's (ViewModel is injected from WeektimeApp)
        viewModel.timerManager = timerManager

        // Initialize timer manager if needed
        if timerManager == nil {
            let manager = SessionTimerManager(goalStore: goalStore, modelContext: modelContext)
            
            // Set up callback for external changes (e.g., widget stopping timer)
            manager.onExternalChange = { [weak manager] in
                // Note: SwiftData automatically tracks changes from other contexts
                // We just need to reload the timer state to sync with UserDefaults
                manager?.loadTimerState(sessions: sessions)
            }
            
            timerManager = manager
        }
        
        // Load saved timer states from UserDefaults
        timerManager?.loadTimerState(sessions: sessions)
        
        // Update GoalStore for App Intents
        goalStore.goals = goals
        goalStore.sessions = sessions
        
        // Critical path: create missing sessions immediately so UI is populated
        refreshGoals()
        
        // Defer non-critical work to separate tasks so it doesn't block initial render.
        // Tasks are tracked for cancellation on view disappear.
        backgroundTasks.append(Task {
            // HealthKit sync runs async and updates state when done
            syncHealthKitData()
        })

        backgroundTasks.append(Task {
            // Calendar events are supplementary UI
            fetchNextCalendarEvent()
        })

        backgroundTasks.append(Task {
            // Auto-plan once per day on launch if we haven't already
            await checkAndRunAutoPlan()
        })

        backgroundTasks.append(Task {
            // Reschedule notifications for all goals with notifications enabled
            await rescheduleGoalNotifications()
        })
        
        // Initialize weather data asynchronously in background to avoid blocking launch
        backgroundTasks.append(Task(priority: .background) {
            weatherManager.refreshWeatherIfNeeded()
        })
    }
    
    /// Reschedule notifications for all goals with schedule notifications enabled
    @MainActor
    func rescheduleGoalNotifications() async {
        let notificationManager = GoalNotificationManager()
        
        // Get all active goals with schedule notifications enabled
        let notificationGoals = goals.filter { $0.scheduleNotificationsEnabled && $0.hasSchedule && $0.status == .active }
        
        guard !notificationGoals.isEmpty else {
            AppLogger.notifications.debug("No goals with notifications enabled")
            return
        }
        
        AppLogger.notifications.info("Rescheduling notifications for \(notificationGoals.count) goals...")
        
        do {
            try await notificationManager.rescheduleAllGoals(goals: notificationGoals)
        } catch {
            AppLogger.notifications.error("Failed to reschedule notifications: \(error)")
        }
    }
    
    /// Check if we should auto-plan and run it if needed
    func checkAndRunAutoPlan() async {
        AppLogger.planner.debug("Auto-plan check: hasAutoPlannedToday=\(planningViewModel.hasAutoPlannedToday), goals.count=\(goals.count)")
        
        // Skip if we've already auto-planned in this session (prevents duplicate runs)
        guard !planningViewModel.hasAutoPlannedToday else {
            AppLogger.planner.debug("Skipping: already planned in this session")
            return
        }
        
        // Mark as started immediately to prevent concurrent runs
        planningViewModel.hasAutoPlannedToday = true
        
        // Skip if there are no goals
        guard !goals.isEmpty else {
            AppLogger.planner.debug("Skipping: no goals available")
            planningViewModel.hasAutoPlannedToday = false // Reset so it can try again if goals are added
            return
        }
        
        // Check if less than 1 hour has passed since last plan generation
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastPlan = currentTime - lastPlanGeneratedTimestamp
        let oneHourInSeconds: Double = 3600
        
        if lastPlanGeneratedTimestamp > 0 && timeSinceLastPlan < oneHourInSeconds {
            let remainingMinutes = Int((oneHourInSeconds - timeSinceLastPlan) / 60)
            AppLogger.planner.debug("Skipping: Plan generated \(Int(timeSinceLastPlan / 60)) minutes ago. Will regenerate in \(remainingMinutes) minutes")
            planningViewModel.hasAutoPlannedToday = false // Reset so it can try again later
            return
        }
        
        AppLogger.planner.info("Starting auto-plan...")
        
        
        await generateDailyPlan()
    }
    
    /// Update recommendation reasons for existing planned sessions
    func updateExistingSessionReasons() async {
        await MainActor.run {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                for session in sessions where session.plannedStartTime != nil {
                    guard let goal = session.goal else { continue }
                    let reasons = calculateRecommendationReasons(for: session, goal: goal)
                    session.recommendationReasons = reasons
                }
                modelContext.safeSave(showingToast: $navigation.toastConfig)
            }
        }
    }
    
    func handleGoalsChange(old: [Goal], new: [Goal]) {
        // Refresh sessions to match the updated goals
        refreshGoals()
        
        // Only sync HealthKit if new HealthKit-enabled goals were added
        let newHealthKitGoals = new.filter { newGoal in
            newGoal.healthKitSyncEnabled &&
            newGoal.healthKitMetric != nil &&
            !old.contains(where: { $0.id == newGoal.id })
        }
        
        if !newHealthKitGoals.isEmpty {
            backgroundTasks.append(Task {
                let newMetrics = newHealthKitGoals.compactMap { $0.healthKitMetric }
                if !newMetrics.isEmpty {
                    do {
                        try await healthKitManager.requestAuthorization(for: newMetrics)
                    } catch {
                        AppLogger.healthKit.error("HealthKit authorization failed for new goals: \(error)")
                    }
                }
                // Only sync for the newly added goals
                syncHealthKitData()
            })
        }
    }
}
