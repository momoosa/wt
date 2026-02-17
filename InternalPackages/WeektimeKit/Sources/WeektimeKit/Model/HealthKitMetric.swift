//
//  HealthKitMetric.swift
//  MomentumKit
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
    case weightLiftingTime = "weight_lifting_time"
    case ellipticalTime = "elliptical_time"
    case rowingTime = "rowing_time"
    case timeInDaylight = "time_in_daylight"
    
    public var id: String { rawValue }
    
    /// Whether this metric can be written to (logged by the app)
    public var supportsWrite: Bool {
        switch self {
        case .appleExerciseTime, .appleStandTime, .appleMoveTime, .timeInDaylight:
            return false // Read-only, calculated by Apple Watch
        case .mindfulMinutes:
            return true // Can log meditation sessions
        case .workoutTime, .weightLiftingTime, .ellipticalTime, .rowingTime:
            return true // Can create workout sessions
        }
    }
    
    /// Display name for the metric
    public var displayName: String {
        switch self {
        case .appleExerciseTime: return "Apple Exercise Minutes"
        case .appleStandTime: return "Apple Stand Minutes"
        case .appleMoveTime: return "Apple Move Minutes"
        case .mindfulMinutes: return "Mindful Minutes"
        case .workoutTime: return "Workout Duration"
        case .weightLiftingTime: return "Weight Lifting Duration"
        case .ellipticalTime: return "Elliptical Duration"
        case .rowingTime: return "Rowing Duration"
        case .timeInDaylight: return "Time in Daylight"
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
        case .weightLiftingTime: return "figure.strengthtraining.traditional"
        case .ellipticalTime: return "figure.elliptical"
        case .rowingTime: return "figure.rower"
        case .timeInDaylight: return "sun.max.fill"
        }
    }
    
    /// The corresponding HealthKit quantity type identifier (nil for category types)
    public var quantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .appleExerciseTime: return .appleExerciseTime
        case .appleStandTime: return .appleStandTime
        case .appleMoveTime: return .appleMoveTime
        case .mindfulMinutes: return nil // Uses category type instead
        case .timeInDaylight: return .timeInDaylight
        case .workoutTime: return .appleExerciseTime // Workouts use exercise time
        case .weightLiftingTime: return nil // Uses workout type instead
        case .ellipticalTime: return nil // Uses workout type instead
        case .rowingTime: return nil // Uses workout type instead
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
        case .appleExerciseTime, .appleStandTime, .appleMoveTime, .mindfulMinutes, .workoutTime, .weightLiftingTime, .ellipticalTime, .rowingTime, .timeInDaylight:
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
        case .weightLiftingTime:
            return "Track traditional strength training and weight lifting workouts"
        case .ellipticalTime:
            return "Track elliptical trainer workouts"
        case .rowingTime:
            return "Track rowing machine workouts"
        case .timeInDaylight:
            return "Track time spent in natural daylight from your Apple Watch"
        }
    }
}
