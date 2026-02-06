//
//  SessionProgress.swift
//  WeektimeKit
//
//  Protocol for session progress calculations
//

import Foundation

// MARK: - Session Progress Provider Protocol

public protocol SessionProgressProvider {
    var elapsedTime: TimeInterval { get }
    var dailyTarget: TimeInterval { get }
}

public extension SessionProgressProvider {
    /// Progress as a value between 0.0 and 1.0
    var progress: Double {
        guard dailyTarget > 0 else { return 0 }
        return min(elapsedTime / dailyTarget, 1.0)
    }

    /// Whether the daily target has been met
    var hasMetDailyTarget: Bool {
        elapsedTime >= dailyTarget
    }

    /// Remaining time to reach the daily target
    var remainingTime: TimeInterval {
        max(dailyTarget - elapsedTime, 0)
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
