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
    var healthKitManager: HealthKitManager

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
        healthKitManager: HealthKitManager,
        weatherManager: WeatherManager,
        calendarEventStore: EKEventStore
    ) {
        self.navigation = navigation
        self.planningViewModel = planningViewModel
        self.focusFilterStore = focusFilterStore
        self.healthKitManager = healthKitManager
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
    func handleTimerToggle(for session: GoalSession, in day: Day) {
        guard let timerManager else { return }

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
                message: "Session resumed - moved to Today",
                showUndo: false
            )
        }
    }

    /// Adjust daily target for a session
    func adjustDailyTarget(
        for session: GoalSession,
        by adjustment: TimeInterval,
        in modelContext: ModelContext
    ) {
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
        if modelContext.safeSave() {
            let minutes = Int(abs(adjustment) / 60)
            let direction = adjustment > 0 ? "increased" : "decreased"
            navigation.toastConfig = ToastConfig(
                message: "Daily goal \(direction) by \(minutes)m",
                showUndo: false
            )
        }
    }

    /// Skip a session
    func skip(_ session: GoalSession, in modelContext: ModelContext) {
        session.status = .skipped
        modelContext.safeSave()

        navigation.toastConfig = ToastConfig(
            message: "Session skipped for today",
            showUndo: true,
            onUndo: {
                session.status = .active
                modelContext.safeSave()
            }
        )
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
        guard healthKitManager.isHealthKitAvailable else {
            if userInitiated {
                await MainActor.run {
                    navigation.toastConfig = ToastConfig(message: "HealthKit not available")
                }
            }
            return
        }

        await MainActor.run {
            isSyncingHealthKit = true
        }

        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }

        guard !healthKitGoals.isEmpty else {
            await MainActor.run {
                isSyncingHealthKit = false
                if userInitiated {
                    navigation.toastConfig = ToastConfig(message: "No goals with HealthKit sync enabled")
                }
            }
            return
        }

        // Track allocated samples to prevent double-counting across goals
        var allocatedSampleIDs = Set<String>()

        // Track sync results for toast notification
        var syncedGoalsCount = 0
        var totalDurationImported: TimeInterval = 0
        var syncErrors: [String] = []

        // Fetch and allocate data for each goal (first-come-first-served)
        for goal in healthKitGoals {
            guard let metric = goal.healthKitMetric else { continue }

            do {
                // Fetch individual samples (for history display)
                let samples = try await healthKitManager.fetchSamples(
                    for: metric,
                    from: day.startDate,
                    to: day.endDate
                )

                // Filter out samples created by this app to prevent double-counting
                let externalSamples = samples.filter { !$0.isFromThisApp }

                // Filter out samples already allocated to other goals
                let availableSamples = externalSamples.filter { !allocatedSampleIDs.contains($0.id) }

                // Merge samples to avoid double-counting
                let mergedSamples = mergeSamples(availableSamples)

                // Calculate total duration from merged samples
                let duration = mergedSamples.reduce(0.0) { $0 + $1.duration }

                // Update the corresponding session
                await MainActor.run {
                    AppLogger.healthKit.info("Syncing HealthKit data for goal '\(goal.title)' (metric: \(metric.rawValue))")
                    AppLogger.healthKit.info("  - Found \(samples.count) samples total")
                    AppLogger.healthKit.info("  - Filtered out \(samples.count - externalSamples.count) samples from this app")
                    AppLogger.healthKit.info("  - \(availableSamples.count) external samples available after allocation")
                    AppLogger.healthKit.info("  - Merged to \(mergedSamples.count) samples")
                    AppLogger.healthKit.info("  - Total duration: \(duration.formatted()) seconds")

                    if let session = sessions.first(where: { $0.goal?.id == goal.id }) {
                        AppLogger.healthKit.info("  - Found matching session for goal '\(goal.title)'")
                        session.updateHealthKitTime(duration)

                        // Sync primary metric value for count/calorie goals
                        if goal.goalType == .count || goal.goalType == .calories {
                            Task {
                                do {
                                    let value: Double
                                    if metric.unit == .count() {
                                        value = try await self.healthKitManager.fetchTodayCount(for: metric)
                                    } else {
                                        value = try await self.healthKitManager.fetchTodayCount(for: metric)
                                    }
                                    await MainActor.run {
                                        session.updatePrimaryMetricValue(value)
                                        AppLogger.healthKit.info("  - Synced primary metric value: \(value)")
                                    }
                                } catch {
                                    AppLogger.healthKit.error("  - Failed to sync primary metric: \(error)")
                                }
                            }
                        }

                        // Mark these samples as allocated
                        for sample in mergedSamples {
                            allocatedSampleIDs.insert(sample.id)
                        }

                        // Track sync results
                        if duration > 0 {
                            syncedGoalsCount += 1
                            totalDurationImported += duration
                        }

                        // Note: Historical session sync moved back to ContentView due to API changes
                    } else {
                        AppLogger.healthKit.warning("  - No session found for goal '\(goal.title)' (ID: \(goal.id))")
                    }
                }
            } catch {
                AppLogger.healthKit.error("Failed to fetch HealthKit data for \(goal.title): \(error)")
                syncErrors.append(goal.title)
            }
        }

        // Reset syncing state and show toast when done
        await MainActor.run {
            isSyncingHealthKit = false

            // Only show toast if user-initiated
            if userInitiated {
                if syncedGoalsCount > 0 {
                    let minutes = Int(totalDurationImported / 60)
                    navigation.toastConfig = ToastConfig(
                        message: "Synced \(syncedGoalsCount) goal\(syncedGoalsCount == 1 ? "" : "s") (\(minutes)m imported)"
                    )
                } else if !syncErrors.isEmpty {
                    navigation.toastConfig = ToastConfig(
                        message: "Failed to sync \(syncErrors.count) goal\(syncErrors.count == 1 ? "" : "s")"
                    )
                } else {
                    navigation.toastConfig = ToastConfig(message: "No new HealthKit data to sync")
                }
            }
        }
    }

    // Note: syncHistoricalSessions moved back to ContentView due to HistoricalSession API changes

    /// Merge consecutive HealthKit samples that are short and have no time gap between them
    private func mergeSamples(_ samples: [HealthKitSample]) -> [HealthKitSample] {
        guard !samples.isEmpty else { return [] }

        // Sort by start date
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var merged: [HealthKitSample] = []
        var currentGroup: [HealthKitSample] = [sorted[0]]

        for i in 1..<sorted.count {
            let previous = sorted[i - 1]
            let current = sorted[i]

            // Check if we should merge with the current group
            let timeBetween = current.startDate.timeIntervalSince(previous.endDate)
            let shouldMerge = timeBetween <= 0 && // No gap (or overlap)
                              previous.duration < 300 && // Previous session < 5 minutes
                              current.duration < 300 && // Current session < 5 minutes
                              previous.metric == current.metric && // Same metric type
                              previous.sourceName == current.sourceName // Same source app

            if shouldMerge {
                currentGroup.append(current)
            } else {
                // Finalize the current group
                merged.append(createMergedSample(from: currentGroup))
                currentGroup = [current]
            }
        }

        // Don't forget the last group
        merged.append(createMergedSample(from: currentGroup))

        return merged
    }

    /// Create a single merged sample from a group of samples
    private func createMergedSample(from samples: [HealthKitSample]) -> HealthKitSample {
        guard !samples.isEmpty else {
            fatalError("Cannot create merged sample from empty array")
        }

        // If only one sample, return it as-is
        if samples.count == 1 {
            return samples[0]
        }

        // Merge multiple samples
        let sortedByDate = samples.sorted { $0.startDate < $1.startDate }
        let earliestStart = sortedByDate.first!.startDate
        let latestEnd = sortedByDate.max { $0.endDate < $1.endDate }!.endDate
        let totalDuration = latestEnd.timeIntervalSince(earliestStart)

        // Create a combined ID from all merged sample IDs
        let combinedID = sortedByDate.map { $0.id }.joined(separator: "_")

        return HealthKitSample(
            id: combinedID,
            startDate: earliestStart,
            endDate: latestEnd,
            duration: totalDuration,
            metric: samples[0].metric,
            sourceName: samples[0].sourceName
        )
    }

    /// Start observing HealthKit changes for real-time updates
    func startHealthKitObservers(for goals: [Goal]) {
        // Stop any existing observers first
        stopHealthKitObservers()

        guard healthKitManager.isHealthKitAvailable else { return }

        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }
        let uniqueMetrics = Set(healthKitGoals.compactMap { $0.healthKitMetric })

        for metric in uniqueMetrics {
            do {
                let observer = try healthKitManager.observeMetric(metric) { _ in
                    // When HealthKit data changes, trigger a re-sync
                    // This will be handled by the view calling syncHealthKitData
                }
                healthKitObservers.append(observer)
            } catch {
                AppLogger.healthKit.error("Failed to start observer for \(metric.displayName): \(error)")
            }
        }
    }

    /// Stop all HealthKit observers
    func stopHealthKitObservers() {
        for observer in healthKitObservers {
            healthKitManager.stopObserving(observer)
        }
        healthKitObservers.removeAll()
    }

    // MARK: - Lifecycle

    /// Clean up resources
    func cleanup() {
        stopHealthKitObservers()
    }
}
