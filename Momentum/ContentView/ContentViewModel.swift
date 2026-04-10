//
//  ContentViewModel.swift
//  Momentum
//
//  Business logic and state management for ContentView
//

import SwiftUI
import SwiftData
import MomentumKit
import EventKit
import HealthKit
import OSLog
import WeatherKit

@Observable
class ContentViewModel {
    // MARK: - Dependencies

    /// Navigation state (sheet presentation, selection, etc.)
    let navigation: NavigationState

    /// Timer manager for session tracking
    var timerManager: SessionTimerManager?

    /// Planning view model
    var planningViewModel: PlanningViewModel

    /// Focus filter store
    var focusFilterStore: FocusFilterStore

    /// HealthKit manager
    var healthKitManager: HealthKitManaging
    
    /// HealthKit sync service
    var healthKitSyncService: HealthKitSyncService

    /// Weather manager
    var weatherManager: WeatherManager

    /// Calendar event store
    var calendarEventStore: EKEventStore

    // MARK: - State

    /// HealthKit observers for real-time updates
    var healthKitObservers: [HKObserverQuery] = []

    /// Is currently syncing HealthKit data
    var isSyncingHealthKit = false

    /// Next calendar event
    var nextCalendarEvent: EKEvent?

    // MARK: - Initialization

    @MainActor
    init(
        navigation: NavigationState,
        planningViewModel: PlanningViewModel,
        focusFilterStore: FocusFilterStore,
        healthKitManager: HealthKitManaging,
        healthKitSyncService: HealthKitSyncService,
        weatherManager: WeatherManager,
        calendarEventStore: EKEventStore
    ) {
        self.navigation = navigation
        self.planningViewModel = planningViewModel
        self.focusFilterStore = focusFilterStore
        self.healthKitManager = healthKitManager
        self.healthKitSyncService = healthKitSyncService
        self.weatherManager = weatherManager
        self.calendarEventStore = calendarEventStore
    }

    // MARK: - Computed Properties

    /// Get sessions filtered by focus filter
    func focusFilteredSessions(from sessions: [GoalSession]) -> [GoalSession] {
        guard focusFilterStore.isFocusFilterActive else {
            return sessions
        }

        return sessions.filter { session in
            guard let goal = session.goal else { return false }

            // Include if goal matches any active focus tag
            if let primaryTag = goal.primaryTag,
               focusFilterStore.activeFocusTagTitles.contains(primaryTag.title) {
                return true
            }

            return false
        }
    }

    /// Get all active sessions (non-skipped)
    func allActiveSessions(from sessions: [GoalSession]) -> [GoalSession] {
        sessions.filter { $0.status != .skipped }
    }

    // Note: getRecommendedSessions, sessionCountsForFilters, and getContextualSections
    // are currently handled directly in ContentView due to complex API dependencies.
    // These can be migrated later once the service APIs are stabilized.

    // MARK: - Session Actions

    /// Toggle timer for a session
    @discardableResult
    func handleTimerToggle(for session: GoalSession, in day: Day) -> Result<Void, SessionError> {
        guard let timerManager else {
            return .failure(.timerNotAvailable)
        }

        // Check if session is currently completed
        let wasCompleted = session.hasMetDailyTarget

        // Toggle the timer
        timerManager.toggleTimer(for: session, in: day)

        // If it was completed and we just started it, switch to Today filter and show toast
        if wasCompleted && timerManager.activeSession?.id == session.id {
            withAnimation {
                navigation.activeFilter = .activeToday
            }

            navigation.toastConfig = ToastConfig(
                message: ToastMessageFactory.sessionResumed(),
                showUndo: false
            )
        }
        
        return .success(())
    }

    /// Adjust daily target for a session
    @discardableResult
    func adjustDailyTarget(
        for session: GoalSession,
        by adjustment: TimeInterval,
        in modelContext: ModelContext
    ) -> Result<TimeInterval, SessionError> {
        let newTarget = max(0, session.dailyTarget + adjustment)

        // Update goal if needed
        if let goal = session.goal {
            goal.weeklyTarget = newTarget * 7
        }

        // Update session
        session.dailyTarget = newTarget

        // Update timerManager if this is the active session
        if let timerManager,
           let activeSession = timerManager.activeSession,
           activeSession.id == session.id {
            activeSession.dailyTarget = newTarget
        }

        // Save context
        guard modelContext.safeSave() else {
            navigation.toastConfig = ToastConfig(message: ToastMessageFactory.saveFailed())
            return .failure(.saveFailed)
        }
        
        let minutes = Int(abs(adjustment) / 60)
        navigation.toastConfig = ToastConfig(
            message: ToastMessageFactory.dailyGoalAdjusted(by: minutes, increased: adjustment > 0),
            showUndo: false
        )
        
        return .success(newTarget)
    }

    /// Skip a session
    @discardableResult
    func skip(_ session: GoalSession, in modelContext: ModelContext) -> Result<Void, SessionError> {
        session.status = .skipped
        
        guard modelContext.safeSave() else {
            navigation.toastConfig = ToastConfig(message: ToastMessageFactory.saveFailed())
            return .failure(.saveFailed)
        }

        navigation.toastConfig = ToastConfig(
            message: ToastMessageFactory.sessionSkipped(),
            showUndo: true,
            onUndo: {
                session.status = .active
                modelContext.safeSave()
            }
        )
        
        return .success(())
    }

    // MARK: - HealthKit Integration

    /// Sync HealthKit data for all enabled goals
    func syncHealthKitData(
        for goals: [Goal],
        sessions: [GoalSession],
        in day: Day,
        modelContext: ModelContext,
        userInitiated: Bool = false
    ) async {
        isSyncingHealthKit = true
        
        // Delegate to service for the actual sync
        let result = await healthKitSyncService.syncHealthKitData(
            for: goals,
            sessions: sessions,
            in: day,
            userInitiated: userInitiated
        )
        
        isSyncingHealthKit = false
        
        // Show toast if user-initiated
        if userInitiated {
            if result.hadData {
                let minutes = Int(result.totalDurationImported / 60)
                navigation.toastConfig = ToastConfig(
                    message: ToastMessageFactory.healthKitSyncSuccess(
                        goalCount: result.syncedGoalsCount,
                        minutes: minutes
                    )
                )
            } else if result.hasErrors {
                navigation.toastConfig = ToastConfig(
                    message: ToastMessageFactory.healthKitSyncFailed(goalCount: result.errors.count)
                )
            } else {
                navigation.toastConfig = ToastConfig(
                    message: ToastMessageFactory.noHealthKitData()
                )
            }
        }
    }

    /// Start observing HealthKit changes for real-time updates
    func startHealthKitObservers(for goals: [Goal]) {
        // Stop any existing observers first
        stopHealthKitObservers()
        
        // Delegate to service for observer setup
        healthKitObservers = healthKitSyncService.startHealthKitObservers(for: goals)
    }

    /// Stop all HealthKit observers
    func stopHealthKitObservers() {
        healthKitSyncService.stopHealthKitObservers(healthKitObservers)
        healthKitObservers.removeAll()
    }

    // MARK: - Lifecycle

    /// Clean up resources
    func cleanup() {
        stopHealthKitObservers()
    }
}
