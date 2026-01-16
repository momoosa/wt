//
//  HealthKitMetric.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 16/01/2026.
//


import Foundation
import HealthKit

/// Represents a HealthKit metric that can be connected to a goal
public enum HealthKitMetric: String, Codable, CaseIterable, Identifiable {
    case appleExerciseTime = "apple_exercise_time"
    case appleStandTime = "apple_stand_time"
    case appleMoveTime = "apple_move_time"
    case mindfulMinutes = "mindful_minutes"
    case workoutTime = "workout_time"
    
    public var id: String { rawValue }
    
    /// Display name for the metric
    public var displayName: String {
        switch self {
        case .appleExerciseTime: return "Apple Exercise Minutes"
        case .appleStandTime: return "Apple Stand Minutes"
        case .appleMoveTime: return "Apple Move Minutes"
        case .mindfulMinutes: return "Mindful Minutes"
        case .workoutTime: return "Workout Duration"
        }
    }
    
    /// SF Symbol icon for the metric
    public var symbolName: String {
        switch self {
        case .appleExerciseTime: return "figure.run"
        case .appleStandTime: return "figure.stand"
        case .appleMoveTime: return "flame.fill"
        case .mindfulMinutes: return "brain.head.profile"
        case .workoutTime: return "figure.mixed.cardio"
        }
    }
    
    /// The corresponding HealthKit quantity type identifier (nil for category types)
    public var quantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .appleExerciseTime: return .appleExerciseTime
        case .appleStandTime: return .appleStandTime
        case .appleMoveTime: return .appleMoveTime
        case .mindfulMinutes: return nil // Uses category type instead
        case .workoutTime: return .appleExerciseTime // Workouts use exercise time
        }
    }
    
    /// The corresponding HealthKit category type identifier (nil for quantity types)
    public var categoryTypeIdentifier: HKCategoryTypeIdentifier? {
        switch self {
        case .mindfulMinutes: return .mindfulSession
        default: return nil
        }
    }
    
    /// Returns the HKQuantityType for this metric (nil for category-based metrics)
    public var quantityType: HKQuantityType? {
        guard let identifier = quantityTypeIdentifier else { return nil }
        return HKQuantityType.quantityType(forIdentifier: identifier)
    }
    
    /// Returns the HKCategoryType for this metric (nil for quantity-based metrics)
    public var categoryType: HKCategoryType? {
        guard let identifier = categoryTypeIdentifier else { return nil }
        return HKCategoryType.categoryType(forIdentifier: identifier)
    }
    
    /// Returns the HKSampleType (works for both quantity and category types)
    public var sampleType: HKSampleType? {
        return quantityType ?? categoryType
    }
    
    /// The unit to use when querying this metric
    public var unit: HKUnit {
        switch self {
        case .appleExerciseTime, .appleStandTime, .appleMoveTime, .mindfulMinutes, .workoutTime:
            return .minute()
        }
    }
    
    /// Description of what this metric tracks
    public var description: String {
        switch self {
        case .appleExerciseTime:
            return "Track exercise minutes from your Apple Watch"
        case .appleStandTime:
            return "Track stand minutes from your Apple Watch"
        case .appleMoveTime:
            return "Track active calorie burn time from your Apple Watch"
        case .mindfulMinutes:
            return "Track mindfulness session duration"
        case .workoutTime:
            return "Track total workout duration"
        }
    }
}
