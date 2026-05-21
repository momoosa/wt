//
//  SessionProgress.swift
//  MomentumKit
//
//  Protocol for session progress calculations
//

import Foundation

// MARK: - Session Progress Provider Protocol

public protocol SessionProgressProvider {
    var currentValue: Double { get }
    var unifiedTargetValue: Double { get }
    var targetUnit: Goal.TargetUnit { get }
}

public extension SessionProgressProvider {
    /// Progress as a value from 0.0 onwards (can exceed 1.0 when over target)
    var progress: Double {
        guard unifiedTargetValue > 0 else { return 0 }
        return currentValue / unifiedTargetValue
    }

    /// Whether the daily target has been met
    var hasMetDailyTarget: Bool {
        guard unifiedTargetValue > 0 else { return false }
        return currentValue >= unifiedTargetValue
    }

    /// Remaining value to reach the daily target (in native units)
    var remainingValue: Double {
        max(unifiedTargetValue - currentValue, 0)
    }

    /// Progress as a percentage string (e.g., "75%")
    var progressPercentage: String {
        "\(Int(progress * 100))%"
    }

    /// Progress as an integer percentage (e.g., 75)
    var progressPercentageInt: Int {
        Int(progress * 100)
    }
}
