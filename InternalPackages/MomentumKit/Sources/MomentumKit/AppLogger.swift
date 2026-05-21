//
//  AppLogger.swift
//  MomentumKit
//
//  Created by Mo Moosa on 03/03/2026.
//

import OSLog

/// Centralized logging for the Momentum app (shared across iOS and watchOS)
public enum AppLogger {
    private static let subsystem = "com.moosa.ios.momentum"
    
    /// General app logging
    public static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Session timer related logging
    public static let sessionTimer = Logger(subsystem: subsystem, category: "SessionTimer")
    
    /// Goal editor related logging
    public static let goalEditor = Logger(subsystem: subsystem, category: "GoalEditor")
    
    /// Planner related logging
    public static let planner = Logger(subsystem: subsystem, category: "Planner")
    
    /// Notification related logging
    public static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    
    /// Data persistence logging
    public static let data = Logger(subsystem: subsystem, category: "Data")
    
    /// HealthKit related logging
    public static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    
    /// Widget related logging
    public static let widget = Logger(subsystem: subsystem, category: "Widget")
    
    /// Background tasks logging
    public static let background = Logger(subsystem: subsystem, category: "Background")
    
    /// Watch connectivity logging
    public static let watch = Logger(subsystem: subsystem, category: "Watch")
    
    /// Screentime related logging
    public static let screentime = Logger(subsystem: subsystem, category: "Screentime")
}
