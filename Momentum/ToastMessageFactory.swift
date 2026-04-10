//
//  ToastMessageFactory.swift
//  Momentum
//
//  Centralized toast message creation for consistency and localization
//

import Foundation

/// Factory for creating standardized toast messages
enum ToastMessageFactory {
    // MARK: - Session Actions
    
    static func sessionSkipped() -> String {
        "Session skipped for today"
    }
    
    static func sessionResumed() -> String {
        "Session resumed - moved to Today"
    }
    
    static func dailyGoalAdjusted(by minutes: Int, increased: Bool) -> String {
        let direction = increased ? "increased" : "decreased"
        return "Daily goal \(direction) by \(minutes)m"
    }
    
    // MARK: - HealthKit Sync
    
    static func healthKitNotAvailable() -> String {
        "HealthKit not available"
    }
    
    static func noHealthKitGoals() -> String {
        "No goals with HealthKit sync enabled"
    }
    
    static func healthKitSyncSuccess(goalCount: Int, minutes: Int) -> String {
        let goalText = goalCount == 1 ? "goal" : "goals"
        return "Synced \(goalCount) \(goalText) (\(minutes)m imported)"
    }
    
    static func healthKitSyncFailed(goalCount: Int) -> String {
        let goalText = goalCount == 1 ? "goal" : "goals"
        return "Failed to sync \(goalCount) \(goalText)"
    }
    
    static func noHealthKitData() -> String {
        "No new HealthKit data to sync"
    }
    
    // MARK: - Errors
    
    static func saveFailed() -> String {
        "Failed to save changes"
    }
    
    static func genericError(_ error: Error) -> String {
        "Error: \(error.localizedDescription)"
    }
}
