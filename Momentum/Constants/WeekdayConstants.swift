//
//  WeekdayConstants.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import Foundation

/// Shared weekday constants used throughout the app
enum WeekdayConstants {
    
    /// Weekdays as (Calendar component value, short name) tuples
    /// Starting with Monday (2) and ending with Sunday (1)
    static let weekdays: [(Int, String)] = [
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat"),
        (1, "Sun")
    ]
    
    /// Weekdays as Calendar component values only
    static let weekdayValues: [Int] = weekdays.map { $0.0 }
    
    /// Weekdays as short names only
    static let weekdayNames: [String] = weekdays.map { $0.1 }
    
    /// Get short name for a Calendar weekday component value
    static func name(for weekdayValue: Int) -> String? {
        weekdays.first(where: { $0.0 == weekdayValue })?.1
    }
}
