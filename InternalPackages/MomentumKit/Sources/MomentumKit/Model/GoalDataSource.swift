//
//  GoalDataSource.swift
//  MomentumKit
//
//  Created by Mo Moosa on 26/07/2025.
//

import HealthKit

public enum GoalDataSource: String, CaseIterable, Codable {
    case appleExerciseMinutes
    case mindfulMinutes
    case walkingWorkout
    case ellipticalWorkout
    case timeInDaylight
    case none
    var title: String {
        switch self {
        case .appleExerciseMinutes:
            "Exercise Minutes"
        case .ellipticalWorkout:
            "Elliptical Workout"
        case .mindfulMinutes:
            "Mindful Minutes"
        case .timeInDaylight:
            "Time in Daylight"
        case .walkingWorkout:
            "Walking Workout"
        case .none:
            "None"
        }
    }
    
    public var sampleType: HKSampleType? {
        switch self {
        case .appleExerciseMinutes:
            return HealthKitSampleType.exerciseMinutesType
        case .mindfulMinutes:
            return HealthKitSampleType.mindfulType
        case .timeInDaylight:
            return HealthKitSampleType.timeInDaylightType
        case .ellipticalWorkout, .walkingWorkout, .none:
            return nil // TODO: Check
        }
    }
    
    public var workoutType: HKWorkoutActivityType? {
        switch self {
        case .appleExerciseMinutes, .mindfulMinutes, .none, .timeInDaylight:
            return nil
        case .ellipticalWorkout:
            return .elliptical
        case .walkingWorkout:
            return .walking
        }
    }
}

public struct HealthKitSampleType {
    static let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)
    static let exerciseMinutesType = HKQuantityType(.appleExerciseTime)
    static let timeInDaylightType = HKQuantityType(.timeInDaylight)
    static let workoutType = HKSeriesType.workoutType()
}
