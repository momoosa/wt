//
//  HealthKitSyncService.swift
//  Momentum
//
//  Service for syncing HealthKit data with goal sessions
//

import Foundation
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

    init(healthKitManager: HealthKitManaging) {
        self.healthKitManager = healthKitManager
    }

    /// Sync HealthKit data for all enabled goals
    func syncHealthKitData(
        for goals: [Goal],
        sessions: [GoalSession],
        in day: Day,
        userInitiated: Bool = false
    ) async -> HealthKitSyncResult {
        guard healthKitManager.isHealthKitAvailable else {
            return HealthKitSyncResult(syncedGoalsCount: 0, totalDurationImported: 0, errors: ["HealthKit not available"])
        }

        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }

        guard !healthKitGoals.isEmpty else {
            return HealthKitSyncResult(syncedGoalsCount: 0, totalDurationImported: 0, errors: ["No goals with HealthKit sync enabled"])
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
                let mergedSamples = HealthKitSampleMerger.mergeSamples(availableSamples)

                // Calculate total duration from merged samples
                let duration = mergedSamples.reduce(0.0) { $0 + $1.duration }

                // Update the corresponding session
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
                        do {
                            let value: Double
                            if metric.unit == .count() {
                                value = try await healthKitManager.fetchTodayCount(for: metric)
                            } else {
                                value = try await healthKitManager.fetchTodayCount(for: metric)
                            }
                            session.updatePrimaryMetricValue(value)
                            AppLogger.healthKit.info("  - Synced primary metric value: \(value)")
                        } catch {
                            AppLogger.healthKit.error("  - Failed to sync primary metric: \(error)")
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
                } else {
                    AppLogger.healthKit.warning("  - No session found for goal '\(goal.title)' (ID: \(goal.id))")
                }
            } catch {
                AppLogger.healthKit.error("Failed to fetch HealthKit data for \(goal.title): \(error)")
                syncErrors.append(goal.title)
            }
        }

        return HealthKitSyncResult(
            syncedGoalsCount: syncedGoalsCount,
            totalDurationImported: totalDurationImported,
            errors: syncErrors
        )
    }

    /// Start observing HealthKit changes for real-time updates
    func startHealthKitObservers(for goals: [Goal]) -> [HKObserverQuery] {
        guard healthKitManager.isHealthKitAvailable else { return [] }

        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }
        let uniqueMetrics = Set(healthKitGoals.compactMap { $0.healthKitMetric })

        var observers: [HKObserverQuery] = []

        for metric in uniqueMetrics {
            do {
                let observer = try healthKitManager.observeMetric(metric) { _ in
                    // When HealthKit data changes, trigger a re-sync
                    // This will be handled by the view calling syncHealthKitData
                }
                observers.append(observer)
            } catch {
                AppLogger.healthKit.error("Failed to start observer for \(metric.displayName): \(error)")
            }
        }

        return observers
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
