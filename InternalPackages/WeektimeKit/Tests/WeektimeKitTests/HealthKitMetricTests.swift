//
//  HealthKitMetricTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
import HealthKit
@testable import MomentumKit

@Suite("HealthKit Metric Tests")
struct HealthKitMetricTests {

    // MARK: - Raw Value Tests

    @Test("HealthKitMetric raw values are correct")
    func healthKitMetricRawValuesCorrect() {
        #expect(HealthKitMetric.appleExerciseTime.rawValue == "apple_exercise_time")
        #expect(HealthKitMetric.appleStandTime.rawValue == "apple_stand_time")
        #expect(HealthKitMetric.appleMoveTime.rawValue == "apple_move_time")
        #expect(HealthKitMetric.mindfulMinutes.rawValue == "mindful_minutes")
        #expect(HealthKitMetric.workoutTime.rawValue == "workout_time")
        #expect(HealthKitMetric.weightLiftingTime.rawValue == "weight_lifting_time")
        #expect(HealthKitMetric.ellipticalTime.rawValue == "elliptical_time")
        #expect(HealthKitMetric.rowingTime.rawValue == "rowing_time")
        #expect(HealthKitMetric.timeInDaylight.rawValue == "time_in_daylight")
    }

    @Test("HealthKitMetric ID matches raw value")
    func healthKitMetricIDMatchesRawValue() {
        for metric in HealthKitMetric.allCases {
            #expect(metric.id == metric.rawValue)
        }
    }

    // MARK: - Supports Write Tests

    @Test("Apple Watch metrics are read-only")
    func appleWatchMetricsAreReadOnly() {
        #expect(HealthKitMetric.appleExerciseTime.supportsWrite == false)
        #expect(HealthKitMetric.appleStandTime.supportsWrite == false)
        #expect(HealthKitMetric.appleMoveTime.supportsWrite == false)
        #expect(HealthKitMetric.timeInDaylight.supportsWrite == false)
    }

    @Test("Workout metrics support write")
    func workoutMetricsSupportWrite() {
        #expect(HealthKitMetric.workoutTime.supportsWrite == true)
        #expect(HealthKitMetric.weightLiftingTime.supportsWrite == true)
        #expect(HealthKitMetric.ellipticalTime.supportsWrite == true)
        #expect(HealthKitMetric.rowingTime.supportsWrite == true)
    }

    @Test("Mindful minutes supports write")
    func mindfulMinutesSupportWrite() {
        #expect(HealthKitMetric.mindfulMinutes.supportsWrite == true)
    }

    // MARK: - Display Name Tests

    @Test("HealthKitMetric display names are correct")
    func healthKitMetricDisplayNamesCorrect() {
        #expect(HealthKitMetric.appleExerciseTime.displayName == "Apple Exercise Minutes")
        #expect(HealthKitMetric.appleStandTime.displayName == "Apple Stand Minutes")
        #expect(HealthKitMetric.appleMoveTime.displayName == "Apple Move Minutes")
        #expect(HealthKitMetric.mindfulMinutes.displayName == "Mindful Minutes")
        #expect(HealthKitMetric.workoutTime.displayName == "Workout Duration")
        #expect(HealthKitMetric.weightLiftingTime.displayName == "Weight Lifting Duration")
        #expect(HealthKitMetric.ellipticalTime.displayName == "Elliptical Duration")
        #expect(HealthKitMetric.rowingTime.displayName == "Rowing Duration")
        #expect(HealthKitMetric.timeInDaylight.displayName == "Time in Daylight")
    }

    // MARK: - Symbol Name Tests

    @Test("HealthKitMetric symbol names are valid SF Symbols")
    func healthKitMetricSymbolNamesValid() {
        let symbolNames = [
            HealthKitMetric.appleExerciseTime.symbolName,
            HealthKitMetric.appleStandTime.symbolName,
            HealthKitMetric.appleMoveTime.symbolName,
            HealthKitMetric.mindfulMinutes.symbolName,
            HealthKitMetric.workoutTime.symbolName,
            HealthKitMetric.weightLiftingTime.symbolName,
            HealthKitMetric.ellipticalTime.symbolName,
            HealthKitMetric.rowingTime.symbolName,
            HealthKitMetric.timeInDaylight.symbolName
        ]

        for symbolName in symbolNames {
            #expect(!symbolName.isEmpty)
        }
    }

    @Test("HealthKitMetric symbol names match expected values")
    func healthKitMetricSymbolNamesMatchExpectedValues() {
        #expect(HealthKitMetric.appleExerciseTime.symbolName == "figure.run")
        #expect(HealthKitMetric.appleStandTime.symbolName == "figure.stand")
        #expect(HealthKitMetric.appleMoveTime.symbolName == "flame.fill")
        #expect(HealthKitMetric.mindfulMinutes.symbolName == "brain.head.profile")
        #expect(HealthKitMetric.workoutTime.symbolName == "figure.mixed.cardio")
        #expect(HealthKitMetric.weightLiftingTime.symbolName == "figure.strengthtraining.traditional")
        #expect(HealthKitMetric.ellipticalTime.symbolName == "figure.elliptical")
        #expect(HealthKitMetric.rowingTime.symbolName == "figure.rower")
        #expect(HealthKitMetric.timeInDaylight.symbolName == "sun.max.fill")
    }

    // MARK: - Quantity Type Identifier Tests

    @Test("Apple Watch metrics have quantity type identifiers")
    func appleWatchMetricsHaveQuantityTypeIdentifiers() {
        #expect(HealthKitMetric.appleExerciseTime.quantityTypeIdentifier == .appleExerciseTime)
        #expect(HealthKitMetric.appleStandTime.quantityTypeIdentifier == .appleStandTime)
        #expect(HealthKitMetric.appleMoveTime.quantityTypeIdentifier == .appleMoveTime)
        #expect(HealthKitMetric.timeInDaylight.quantityTypeIdentifier == .timeInDaylight)
    }

    @Test("Workout-based metrics have nil or exercise time identifier")
    func workoutBasedMetricsHaveCorrectIdentifiers() {
        #expect(HealthKitMetric.workoutTime.quantityTypeIdentifier == .appleExerciseTime)
        #expect(HealthKitMetric.weightLiftingTime.quantityTypeIdentifier == nil)
        #expect(HealthKitMetric.ellipticalTime.quantityTypeIdentifier == nil)
        #expect(HealthKitMetric.rowingTime.quantityTypeIdentifier == nil)
    }

    @Test("Mindful minutes has nil quantity type identifier")
    func mindfulMinutesHasNilQuantityTypeIdentifier() {
        #expect(HealthKitMetric.mindfulMinutes.quantityTypeIdentifier == nil)
    }

    // MARK: - Category Type Identifier Tests

    @Test("Mindful minutes has category type identifier")
    func mindfulMinutesHasCategoryTypeIdentifier() {
        #expect(HealthKitMetric.mindfulMinutes.categoryTypeIdentifier == .mindfulSession)
    }

    @Test("Non-category metrics have nil category type identifier")
    func nonCategoryMetricsHaveNilCategoryTypeIdentifier() {
        let quantityMetrics: [HealthKitMetric] = [
            .appleExerciseTime, .appleStandTime, .appleMoveTime, .timeInDaylight,
            .workoutTime, .weightLiftingTime, .ellipticalTime, .rowingTime
        ]

        for metric in quantityMetrics {
            #expect(metric.categoryTypeIdentifier == nil)
        }
    }

    // MARK: - Quantity Type Tests

    @Test("Quantity metrics have valid quantity types")
    func quantityMetricsHaveValidQuantityTypes() {
        #expect(HealthKitMetric.appleExerciseTime.quantityType != nil)
        #expect(HealthKitMetric.appleStandTime.quantityType != nil)
        #expect(HealthKitMetric.appleMoveTime.quantityType != nil)
        #expect(HealthKitMetric.timeInDaylight.quantityType != nil)
        #expect(HealthKitMetric.workoutTime.quantityType != nil)
    }

    @Test("Category-based metrics have nil quantity type")
    func categoryBasedMetricsHaveNilQuantityType() {
        #expect(HealthKitMetric.mindfulMinutes.quantityType == nil)
        #expect(HealthKitMetric.weightLiftingTime.quantityType == nil)
        #expect(HealthKitMetric.ellipticalTime.quantityType == nil)
        #expect(HealthKitMetric.rowingTime.quantityType == nil)
    }

    // MARK: - Category Type Tests

    @Test("Mindful minutes has valid category type")
    func mindfulMinutesHasValidCategoryType() {
        #expect(HealthKitMetric.mindfulMinutes.categoryType != nil)
    }

    @Test("Quantity-based metrics have nil category type")
    func quantityBasedMetricsHaveNilCategoryType() {
        let quantityMetrics: [HealthKitMetric] = [
            .appleExerciseTime, .appleStandTime, .appleMoveTime, .timeInDaylight,
            .workoutTime, .weightLiftingTime, .ellipticalTime, .rowingTime
        ]

        for metric in quantityMetrics {
            #expect(metric.categoryType == nil)
        }
    }

    // MARK: - Sample Type Tests

    @Test("All metrics have valid sample types")
    func allMetricsHaveValidSampleTypes() {
        for metric in HealthKitMetric.allCases {
            #expect(metric.sampleType != nil)
        }
    }

    @Test("Sample type returns quantity type when available")
    func sampleTypeReturnsQuantityTypeWhenAvailable() {
        let metric = HealthKitMetric.appleExerciseTime
        #expect(metric.sampleType === metric.quantityType)
    }

    @Test("Sample type returns category type when quantity type unavailable")
    func sampleTypeReturnsCategoryTypeWhenQuantityTypeUnavailable() {
        let metric = HealthKitMetric.mindfulMinutes
        #expect(metric.sampleType === metric.categoryType)
    }

    // MARK: - Unit Tests

    @Test("All metrics use minute unit")
    func allMetricsUseMinuteUnit() {
        for metric in HealthKitMetric.allCases {
            #expect(metric.unit == .minute())
        }
    }

    // MARK: - Description Tests

    @Test("All metrics have non-empty descriptions")
    func allMetricsHaveNonEmptyDescriptions() {
        for metric in HealthKitMetric.allCases {
            #expect(!metric.description.isEmpty)
        }
    }

    @Test("Descriptions mention tracking")
    func descriptionsMentionTracking() {
        for metric in HealthKitMetric.allCases {
            let description = metric.description.lowercased()
            #expect(description.contains("track"))
        }
    }

    // MARK: - CaseIterable Tests

    @Test("HealthKitMetric has all expected cases")
    func healthKitMetricHasAllExpectedCases() {
        #expect(HealthKitMetric.allCases.count == 9)
    }

    @Test("HealthKitMetric allCases contains all metrics")
    func healthKitMetricAllCasesContainsAllMetrics() {
        let allCases = HealthKitMetric.allCases
        #expect(allCases.contains(.appleExerciseTime))
        #expect(allCases.contains(.appleStandTime))
        #expect(allCases.contains(.appleMoveTime))
        #expect(allCases.contains(.mindfulMinutes))
        #expect(allCases.contains(.workoutTime))
        #expect(allCases.contains(.weightLiftingTime))
        #expect(allCases.contains(.ellipticalTime))
        #expect(allCases.contains(.rowingTime))
        #expect(allCases.contains(.timeInDaylight))
    }

    // MARK: - Codable Tests

    @Test("HealthKitMetric is Codable")
    func healthKitMetricIsCodable() throws {
        let metric = HealthKitMetric.appleExerciseTime

        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)

        let decoder = JSONDecoder()
        let decodedMetric = try decoder.decode(HealthKitMetric.self, from: data)

        #expect(decodedMetric == metric)
    }

    @Test("HealthKitMetric encodes to raw value")
    func healthKitMetricEncodesToRawValue() throws {
        let metric = HealthKitMetric.mindfulMinutes

        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("mindful_minutes") == true)
    }
}
