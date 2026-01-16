//
//  HealthKitManager.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 16/01/2026.
//

import Foundation
import HealthKit
import Observation
import WeektimeKit
/// Manages HealthKit data access and queries
@MainActor
@Observable
public final class HealthKitManager {
    private let healthStore = HKHealthStore()
    public var isAuthorized = false
    public var authorizationError: Error?
    
    public init() {}
    
    /// Check if HealthKit is available on this device
    public var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// Check if a specific metric has been authorized
    public func isAuthorized(for metric: HealthKitMetric) -> Bool {
        guard isHealthKitAvailable else { return false }
        
        guard let sampleType = metric.sampleType else { return false }
        
        let status = healthStore.authorizationStatus(for: sampleType)
        return status == .sharingAuthorized
    }
    
    /// Request authorization for the specified metrics
    public func requestAuthorization(for metrics: [HealthKitMetric]) async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        // Create set of sample types to read (both quantity and category types)
        var typesToRead: Set<HKSampleType> = []
        
        for metric in metrics {
            if let sampleType = metric.sampleType {
                typesToRead.insert(sampleType)
            }
        }
        
        guard !typesToRead.isEmpty else {
            throw HealthKitError.noMetricsProvided
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
        } catch {
            authorizationError = error
            isAuthorized = false
            throw error
        }
    }
    
    /// Fetch the total duration for a metric within a date range
    public func fetchDuration(for metric: HealthKitMetric, from startDate: Date, to endDate: Date) async throws -> TimeInterval {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        // Handle quantity types (like exercise time, stand time)
        if let quantityType = metric.quantityType {
            return try await fetchQuantityDuration(quantityType: quantityType, metric: metric, from: startDate, to: endDate)
        }
        
        // Handle category types (like mindful sessions)
        if let categoryType = metric.categoryType {
            return try await fetchCategoryDuration(categoryType: categoryType, from: startDate, to: endDate)
        }
        
        throw HealthKitError.invalidMetric
    }
    
    /// Fetch duration for quantity-based metrics
    private func fetchQuantityDuration(quantityType: HKQuantityType, metric: HealthKitMetric, from startDate: Date, to endDate: Date) async throws -> TimeInterval {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result,
                      let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                
                let duration = sum.doubleValue(for: metric.unit) * 60 // Convert minutes to seconds
                continuation.resume(returning: duration)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch duration for category-based metrics (like mindful sessions)
    private func fetchCategoryDuration(categoryType: HKCategoryType, from startDate: Date, to endDate: Date) async throws -> TimeInterval {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                
                // Calculate total duration by summing up the time intervals
                let totalDuration = samples.reduce(0.0) { total, sample in
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                continuation.resume(returning: totalDuration)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch duration for a metric for today
    public func fetchTodayDuration(for metric: HealthKitMetric) async throws -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfDay = calendar.startOfDay(for: now) as Date? else {
            throw HealthKitError.invalidDateRange
        }
        
        return try await fetchDuration(for: metric, from: startOfDay, to: now)
    }
    
    /// Start observing changes to a metric (useful for live updates)
    public func observeMetric(_ metric: HealthKitMetric, onChange: @escaping (TimeInterval) -> Void) throws -> HKObserverQuery {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        guard let sampleType = metric.sampleType else {
            throw HealthKitError.invalidMetric
        }
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let duration = try await self.fetchTodayDuration(for: metric)
                    onChange(duration)
                } catch {
                    print("Error fetching updated metric: \(error)")
                }
                completionHandler()
            }
        }
        
        healthStore.execute(query)
        return query
    }
    
    /// Stop observing a query
    public func stopObserving(_ query: HKObserverQuery) {
        healthStore.stop(query)
    }
    
    /// Fetch individual samples for a metric (for displaying in history)
    public func fetchSamples(for metric: HealthKitMetric, from startDate: Date, to endDate: Date) async throws -> [HealthKitSample] {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // Handle quantity types
        if let quantityType = metric.quantityType {
            return try await fetchQuantitySamples(quantityType: quantityType, metric: metric, predicate: predicate, sortDescriptor: sortDescriptor)
        }
        
        // Handle category types
        if let categoryType = metric.categoryType {
            return try await fetchCategorySamples(categoryType: categoryType, predicate: predicate, sortDescriptor: sortDescriptor)
        }
        
        throw HealthKitError.invalidMetric
    }
    
    private func fetchQuantitySamples(quantityType: HKQuantityType, metric: HealthKitMetric, predicate: NSPredicate, sortDescriptor: NSSortDescriptor) async throws -> [HealthKitSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let healthKitSamples = samples.map { sample in
                    HealthKitSample(
                        id: sample.uuid.uuidString,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        duration: sample.endDate.timeIntervalSince(sample.startDate),
                        metric: metric,
                        sourceName: sample.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: healthKitSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchCategorySamples(categoryType: HKCategoryType, predicate: NSPredicate, sortDescriptor: NSSortDescriptor) async throws -> [HealthKitSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let healthKitSamples = samples.map { sample in
                    // Determine metric from category type
                    let metric: HealthKitMetric = {
                        switch sample.categoryType.identifier {
                        case HKCategoryTypeIdentifier.mindfulSession.rawValue:
                            return .mindfulMinutes
                        default:
                            return .mindfulMinutes // Fallback
                        }
                    }()
                    
                    return HealthKitSample(
                        id: sample.uuid.uuidString,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        duration: sample.endDate.timeIntervalSince(sample.startDate),
                        metric: metric,
                        sourceName: sample.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: healthKitSamples)
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Models

/// Represents a single HealthKit sample for display purposes
public struct HealthKitSample: Identifiable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let metric: HealthKitMetric
    public let sourceName: String
}

// MARK: - Errors

public enum HealthKitError: LocalizedError {
    case notAvailable
    case noMetricsProvided
    case invalidMetric
    case invalidDateRange
    case authorizationDenied
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .noMetricsProvided:
            return "No metrics were provided for authorization"
        case .invalidMetric:
            return "The specified metric is invalid"
        case .invalidDateRange:
            return "The date range is invalid"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        }
    }
}
