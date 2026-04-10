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

    /// Session view model for session-specific operations
    var sessionViewModel: SessionViewModel
    
    /// Timer manager for session tracking (delegated to SessionViewModel)
    var timerManager: SessionTimerManager? {
        get { sessionViewModel.timerManager }
        set { sessionViewModel.timerManager = newValue }
    }
    
    /// HealthKit view model for HealthKit operations
    var healthKitViewModel: HealthKitViewModel
    
    /// Is currently syncing HealthKit data (delegated to HealthKitViewModel)
    var isSyncingHealthKit: Bool {
        healthKitViewModel.isSyncingHealthKit
    }
    
    /// Calendar view model for calendar operations
    var calendarViewModel: CalendarViewModel
    
    /// Next calendar event (delegated to CalendarViewModel)
    var nextCalendarEvent: EKEvent? {
        get { calendarViewModel.nextCalendarEvent }
        set { calendarViewModel.nextCalendarEvent = newValue }
    }

    /// Planning view model
    var planningViewModel: PlanningViewModel

    /// Focus filter store
    var focusFilterStore: FocusFilterStore

    /// HealthKit manager
    var healthKitManager: HealthKitManaging

    /// Weather manager
    var weatherManager: WeatherManager

    // MARK: - Initialization

    @MainActor
    init(
        navigation: NavigationState,
        sessionViewModel: SessionViewModel,
        healthKitViewModel: HealthKitViewModel,
        calendarViewModel: CalendarViewModel,
        planningViewModel: PlanningViewModel,
        focusFilterStore: FocusFilterStore,
        healthKitManager: HealthKitManaging,
        weatherManager: WeatherManager
    ) {
        self.navigation = navigation
        self.sessionViewModel = sessionViewModel
        self.healthKitViewModel = healthKitViewModel
        self.calendarViewModel = calendarViewModel
        self.planningViewModel = planningViewModel
        self.focusFilterStore = focusFilterStore
        self.healthKitManager = healthKitManager
        self.weatherManager = weatherManager
    }

    // MARK: - Computed Properties

    /// Get sessions filtered by focus filter
    func focusFilteredSessions(from sessions: [GoalSession]) -> [GoalSession] {
        FilterService.focusFilteredSessions(from: sessions, focusFilterStore: focusFilterStore)
    }

    /// Get all active sessions (non-skipped)
    func allActiveSessions(from sessions: [GoalSession]) -> [GoalSession] {
        FilterService.allActiveSessions(from: sessions)
    }

    // Note: getRecommendedSessions, sessionCountsForFilters, and getContextualSections
    // are currently handled directly in ContentView due to complex API dependencies.
    // These can be migrated later once the service APIs are stabilized.

    // MARK: - Session Actions

    /// Toggle timer for a session
    @discardableResult
    func handleTimerToggle(for session: GoalSession, in day: Day) -> Result<Void, SessionError> {
        // Check if session is currently completed before toggling
        let wasCompleted = session.hasMetDailyTarget

        // Delegate to SessionViewModel
        let result = sessionViewModel.toggleTimer(for: session, in: day)
        
        // Handle navigation and toast if successful
        if case .success = result {
            // If it was completed and we just started it, switch to Today filter and show toast
            if wasCompleted && timerManager?.activeSession?.id == session.id {
                withAnimation {
                    navigation.activeFilter = .activeToday
                }

                navigation.toastConfig = ToastConfig(
                    message: ToastMessageFactory.sessionResumed(),
                    showUndo: false
                )
            }
        }
        
        return result
    }

    /// Adjust daily target for a session
    @discardableResult
    func adjustDailyTarget(
        for session: GoalSession,
        by adjustment: TimeInterval
    ) -> Result<TimeInterval, SessionError> {
        // Delegate to SessionViewModel
        let result = sessionViewModel.adjustDailyTarget(for: session, by: adjustment)
        
        // Handle toast notification based on result
        switch result {
        case .success(let newTarget):
            let minutes = Int(abs(adjustment) / 60)
            navigation.toastConfig = ToastConfig(
                message: ToastMessageFactory.dailyGoalAdjusted(by: minutes, increased: adjustment > 0),
                showUndo: false
            )
            return .success(newTarget)
            
        case .failure(let error):
            navigation.toastConfig = ToastConfig(message: ToastMessageFactory.saveFailed())
            return .failure(error)
        }
    }

    /// Skip a session
    @discardableResult
    func skip(_ session: GoalSession) -> Result<Void, SessionError> {
        // Delegate to SessionViewModel
        let result = sessionViewModel.skip(session)
        
        // Handle toast notification based on result
        switch result {
        case .success:
            navigation.toastConfig = ToastConfig(
                message: ToastMessageFactory.sessionSkipped(),
                showUndo: true,
                onUndo: { [weak sessionViewModel] in
                    sessionViewModel?.resumeSession(session)
                }
            )
            return .success(())
            
        case .failure(let error):
            navigation.toastConfig = ToastConfig(message: ToastMessageFactory.saveFailed())
            return .failure(error)
        }
    }

    // MARK: - HealthKit Integration

    /// Sync HealthKit data for all enabled goals
    func syncHealthKitData(
        for goals: [Goal],
        sessions: [GoalSession],
        in day: Day,
        userInitiated: Bool = false
    ) async {
        // Delegate to HealthKitViewModel
        let result = await healthKitViewModel.syncHealthKitData(
            for: goals,
            sessions: sessions,
            in: day,
            userInitiated: userInitiated
        )
        
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
        // Delegate to HealthKitViewModel
        healthKitViewModel.startHealthKitObservers(for: goals)
    }

    /// Stop all HealthKit observers
    func stopHealthKitObservers() {
        // Delegate to HealthKitViewModel
        healthKitViewModel.stopHealthKitObservers()
    }

    // MARK: - Lifecycle

    /// Clean up resources
    func cleanup() {
        stopHealthKitObservers()
    }
}
