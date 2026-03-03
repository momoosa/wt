//
//  AppLogger.swift
//  MomentumWatch
//
//  Created by Mo Moosa on 03/03/2026.
//

import OSLog

/// Centralized logging for the Momentum watch app
enum AppLogger {
    private static let subsystem = "com.moosa.ios.momentum"
    
    /// General app logging
    static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Session timer related logging
    static let sessionTimer = Logger(subsystem: subsystem, category: "SessionTimer")
    
    /// Goal editor related logging
    static let goalEditor = Logger(subsystem: subsystem, category: "GoalEditor")
    
    /// Planner related logging
    static let planner = Logger(subsystem: subsystem, category: "Planner")
    
    /// Notification related logging
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    
    /// Data persistence logging
    static let data = Logger(subsystem: subsystem, category: "Data")
    
    /// HealthKit related logging
    static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    
    /// Widget related logging
    static let widget = Logger(subsystem: subsystem, category: "Widget")
    
    /// Background tasks logging
    static let background = Logger(subsystem: subsystem, category: "Background")
    
    /// Watch connectivity logging
    static let watch = Logger(subsystem: subsystem, category: "Watch")
    
    /// Screentime related logging
    static let screentime = Logger(subsystem: subsystem, category: "Screentime")
}
