//
//  TimeConstants.swift
//  WeektimeKit
//
//  Centralized time-related constants to eliminate magic numbers throughout the codebase
//

import Foundation

/// Common time interval constants used throughout the app
public enum TimeConstants {
    // MARK: - Basic Units
    
    /// Seconds in one minute (60)
    public static let secondsPerMinute: TimeInterval = 60
    
    /// Seconds in one hour (3600)
    public static let secondsPerHour: TimeInterval = 3600
    
    /// Seconds in one day (86400)
    public static let secondsPerDay: TimeInterval = 86400
    
    // MARK: - Common Durations
    
    /// 5 minutes in seconds (300)
    public static let fiveMinutes: TimeInterval = 300
    
    /// 30 minutes in seconds (1800)
    public static let thirtyMinutes: TimeInterval = 1800
    
    /// 1 hour in seconds (3600)
    public static let oneHour: TimeInterval = 3600
    
    /// 2 hours in seconds (7200)
    public static let twoHours: TimeInterval = 7200
    
    // MARK: - App-Specific Durations
    
    /// Cache validity duration: 5 minutes
    public static let cacheValidityDuration: TimeInterval = 300
    
    /// Session merge threshold: sessions within 5 minutes are considered adjacent
    public static let sessionMergeThreshold: TimeInterval = 300
    
    /// Default manual log duration: 30 minutes
    public static let defaultManualLogDuration: TimeInterval = 1800
    
    /// Minimum session duration for logging: 1 minute
    public static let minimumSessionDuration: TimeInterval = 60
}
