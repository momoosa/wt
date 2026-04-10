//
//  HealthKitManaging.swift
//  Momentum
//
//  Protocol for HealthKit management to enable testing and dependency injection
//

import Foundation
import HealthKit
import MomentumKit

/// Protocol defining HealthKit management capabilities
@MainActor
protocol HealthKitManaging {
    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool { get }

    /// Check if a specific metric has been authorized
    func isAuthorized(for metric: HealthKitMetric) -> Bool

    /// Request authorization for the specified metrics
    func requestAuthorization(for metrics: [HealthKitMetric]) async throws

    /// Fetch the total duration for a metric within a date range
    func fetchDuration(for metric: HealthKitMetric, from startDate: Date, to endDate: Date) async throws -> TimeInterval

    /// Fetch today's duration for a metric
    func fetchTodayDuration(for metric: HealthKitMetric) async throws -> TimeInterval

    /// Fetch count value for a metric within a date range
    func fetchCount(for metric: HealthKitMetric, from startDate: Date, to endDate: Date) async throws -> Double

    /// Fetch today's count for a metric
    func fetchTodayCount(for metric: HealthKitMetric) async throws -> Double

    /// Observe changes to a metric
    func observeMetric(_ metric: HealthKitMetric, onChange: @escaping (TimeInterval) -> Void) throws -> HKObserverQuery

    /// Stop observing a query
    func stopObserving(_ query: HKObserverQuery)

    /// Fetch individual samples for a metric within a date range
    func fetchSamples(for metric: HealthKitMetric, from startDate: Date, to endDate: Date) async throws -> [HealthKitSample]

    /// Write a session to HealthKit
    func writeSession(metric: HealthKitMetric, startDate: Date, endDate: Date) async throws -> String
}

/// Extension to make HealthKitManager conform to the protocol
extension HealthKitManager: HealthKitManaging {}
