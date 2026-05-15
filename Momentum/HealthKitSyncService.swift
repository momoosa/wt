//
//  HealthKitSyncService.swift
//  Momentum
//
//  Service for syncing HealthKit data with goal sessions
//

import Foundation
import SwiftUI
import SwiftData
import HealthKit
import MomentumKit
import OSLog

/// Result of a HealthKit sync operation
struct HealthKitSyncResult {
    let syncedGoalsCount: Int
    let totalDurationImported: TimeInterval
    let errors: [String]

    var hasErrors: Bool { !errors.isEmpty }
    var hadData: Bool { syncedGoalsCount > 0 }
}

/// Service responsible for syncing HealthKit data to goal sessions
@MainActor
class HealthKitSyncService {
    private let healthKitManager: HealthKitManaging
    
    /// Debounce interval for observer-triggered syncs (seconds)
    private let observerDebounceInterval: TimeInterval = 5.0
    
    /// Pending debounce task for observer callbacks
    private var observerDebounceTask: Task<Void, Never>?

    init(healthKitManager: HealthKitManaging) {
        self.healthKitManager = healthKitManager
    }

    /// Sync HealthKit data for all enabled goals
    func syncHealthKitData(
        for goals: [Goal],
        sessions: [GoalSession],
        in day: Day,
        modelContext: ModelContext,
        userInitiated: Bool = false
    ) async -> HealthKitSyncResult {
        guard healthKitManager.isHealthKitAvailable else {
            return HealthKitSyncResult(syncedGoalsCount: 0, totalDurationImported: 0, errors: ["HealthKit not available"])
        }

        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }

        guard !healthKitGoals.isEmpty else {
            return HealthKitSyncResult(syncedGoalsCount: 0, totalDurationImported: 0, errors: [])
        }

        // Request authorization for all required metrics
        let metrics = healthKitGoals.compactMap { $0.healthKitMetric }
        do {
            try await healthKitManager.requestAuthorization(for: metrics)
        } catch {
            AppLogger.healthKit.error("HealthKit authorization failed: \(error)")
            return HealthKitSyncResult(syncedGoalsCount: 0, totalDurationImported: 0, errors: ["Authorization failed"])
        }

        // Track allocated samples to prevent double-counting across goals
        var allocatedSampleIDs = Set<String>()

        // Track sync results for toast notification
        var syncedGoalsCount = 0
        var totalDurationImported: TimeInterval = 0
        var syncErrors: [String] = []

        // Phase 1: Fetch all HealthKit data first (async, no model mutations)
        struct GoalSyncData {
            let goal: Goal
            let metric: HealthKitMetric
            let mergedSamples: [HealthKitSample]
            let duration: TimeInterval
            let primaryMetricValue: Double?
        }
        
        var fetchedData: [GoalSyncData] = []
        
        for goal in healthKitGoals {
            guard let metric = goal.healthKitMetric else { continue }

            do {
                let samples = try await healthKitManager.fetchSamples(
                    for: metric,
                    from: day.startDate,
                    to: day.endDate
                )

                let externalSamples = samples.filter { !$0.isFromThisApp }
                let availableSamples = externalSamples.filter { !allocatedSampleIDs.contains($0.id) }
                let mergedSamples = HealthKitSampleMerger.mergeSamples(availableSamples)
                let duration = mergedSamples.reduce(0.0) { $0 + $1.duration }

                AppLogger.healthKit.info("Syncing HealthKit data for goal '\(goal.title)' (metric: \(metric.rawValue))")
                AppLogger.healthKit.info("  - Found \(samples.count) samples total")
                AppLogger.healthKit.info("  - Filtered out \(samples.count - externalSamples.count) samples from this app")
                AppLogger.healthKit.info("  - \(availableSamples.count) external samples available after allocation")
                AppLogger.healthKit.info("  - Merged to \(mergedSamples.count) samples")
                AppLogger.healthKit.info("  - Total duration: \(duration.formatted()) seconds")

                // Mark samples as allocated for subsequent goals
                for sample in mergedSamples {
                    allocatedSampleIDs.insert(sample.id)
                }

                // Fetch primary metric value if needed (still async)
                var primaryMetricValue: Double? = nil
                if !goal.targetUnit.isTimeBased {
                    do {
                        primaryMetricValue = try await healthKitManager.fetchTodayCount(for: metric)
                        AppLogger.healthKit.info("  - Fetched primary metric value: \(primaryMetricValue ?? 0)")
                    } catch {
                        AppLogger.healthKit.error("  - Failed to fetch primary metric: \(error)")
                    }
                }

                fetchedData.append(GoalSyncData(
                    goal: goal,
                    metric: metric,
                    mergedSamples: mergedSamples,
                    duration: duration,
                    primaryMetricValue: primaryMetricValue
                ))
            } catch {
                AppLogger.healthKit.error("Failed to fetch HealthKit data for \(goal.title): \(error)")
                syncErrors.append(goal.title)
            }
        }

        // Phase 2: Apply all mutations in a single batch (no awaits, no intermediate re-renders)
        var transaction = Transaction()
        transaction.disablesAnimations = !userInitiated
        withTransaction(transaction) {
            for data in fetchedData {
                if let session = sessions.first(where: { $0.goal?.id == data.goal.id }) {
                    AppLogger.healthKit.info("  - Updating session for goal '\(data.goal.title)'")
                    session.updateHealthKitTime(data.duration)

                    if let value = data.primaryMetricValue {
                        session.updatePrimaryMetricValue(value)
                    }

                    if data.duration > 0 {
                        syncedGoalsCount += 1
                        totalDurationImported += data.duration
                    }

                    syncHistoricalSessions(from: data.mergedSamples, for: data.goal, in: session, day: day, modelContext: modelContext)
                } else {
                    AppLogger.healthKit.warning("  - No session found for goal '\(data.goal.title)' (ID: \(data.goal.id))")
                }
            }
            
            // Single save for all mutations
            modelContext.safeSave()
        }

        return HealthKitSyncResult(
            syncedGoalsCount: syncedGoalsCount,
            totalDurationImported: totalDurationImported,
            errors: syncErrors
        )
    }

    /// Sync historical sessions from HealthKit samples
    private func syncHistoricalSessions(
        from samples: [HealthKitSample],
        for goal: Goal,
        in session: GoalSession,
        day: Day,
        modelContext: ModelContext
    ) {
        // Get existing HealthKit-sourced historical sessions for this goal and day
        let existingHealthKitSessionIDs = Set(
            (day.historicalSessions ?? [])
                .filter { $0.healthKitType != nil && $0.goalIDs.contains(goal.id.uuidString) }
                .map { $0.id }
        )

        // Track which sample IDs we're keeping
        var processedSampleIDs = Set<String>()

        for sample in samples {
            processedSampleIDs.insert(sample.id)

            // Check if this sample already exists as a historical session
            if existingHealthKitSessionIDs.contains(sample.id) {
                continue
            }

            // Create new historical session from HealthKit sample
            let historicalSession = HistoricalSession(
                id: sample.id,
                title: "\(sample.metric.displayName) - \(sample.sourceName)",
                start: sample.startDate,
                end: sample.endDate,
                healthKitType: sample.metric.rawValue,
                needsHealthKitRecord: false
            )
            historicalSession.goalIDs.append(goal.id.uuidString)
            day.add(historicalSession: historicalSession)

            modelContext.insert(historicalSession)
        }

        // Remove historical sessions that no longer exist in HealthKit
        let sessionsToRemove = (day.historicalSessions ?? []).filter { session in
            guard session.healthKitType != nil,
                  session.goalIDs.contains(goal.id.uuidString) else {
                return false
            }
            return !processedSampleIDs.contains(session.id)
        }

        for session in sessionsToRemove {
            modelContext.delete(session)
        }
    }

    /// Start observing HealthKit changes for real-time updates.
    /// Observer callbacks are debounced to avoid redundant syncs from rapid HealthKit writes.
    func startHealthKitObservers(for goals: [Goal], onDataChange: @escaping () -> Void) -> [HKObserverQuery] {
        guard healthKitManager.isHealthKitAvailable else { return [] }

        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }
        let uniqueMetrics = Set(healthKitGoals.compactMap { $0.healthKitMetric })

        var observers: [HKObserverQuery] = []

        for metric in uniqueMetrics {
            do {
                let observer = try healthKitManager.observeMetric(metric) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.debouncedSync(onDataChange: onDataChange)
                    }
                }
                observers.append(observer)
            } catch {
                AppLogger.healthKit.error("Failed to start observer for \(metric.displayName): \(error)")
            }
        }

        return observers
    }
    
    /// Debounce observer-triggered syncs so rapid HealthKit writes
    /// (e.g., during a workout) don't cause many back-to-back re-syncs.
    private func debouncedSync(onDataChange: @escaping () -> Void) {
        observerDebounceTask?.cancel()
        observerDebounceTask = Task {
            try? await Task.sleep(for: .seconds(observerDebounceInterval))
            guard !Task.isCancelled else { return }
            onDataChange()
        }
    }

    /// Stop all HealthKit observers
    func stopHealthKitObservers(_ observers: [HKObserverQuery]) {
        for observer in observers {
            healthKitManager.stopObserving(observer)
        }
    }
}

/// Utility for merging HealthKit samples
enum HealthKitSampleMerger {
    /// Merge consecutive HealthKit samples that are short and have no time gap between them
    static func mergeSamples(_ samples: [HealthKitSample]) -> [HealthKitSample] {
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
    private static func createMergedSample(from samples: [HealthKitSample]) -> HealthKitSample {
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
}
