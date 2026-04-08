//
//  Calendar+Extensions.swift
//  WeektimeKit
//
//  Utilities for calendar-based date comparisons
//

import Foundation

public extension Calendar {
    /// Checks if two dates fall on the same calendar day
    /// - Parameters:
    ///   - date1: First date to compare
    ///   - date2: Second date to compare
    /// - Returns: true if both dates are on the same day (year, month, day)
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let components1 = dateComponents([.year, .month, .day], from: date1)
        let components2 = dateComponents([.year, .month, .day], from: date2)
        
        return components1.year == components2.year &&
               components1.month == components2.month &&
               components1.day == components2.day
    }
    
    /// Finds a Day object matching the given date from an array of days
    /// - Parameters:
    ///   - date: The date to match
    ///   - days: Array of Day objects to search
    /// - Returns: The matching Day object, or nil if not found
    func findDay(matching date: Date, in days: [Day]) -> Day? {
        let targetComponents = dateComponents([.year, .month, .day], from: date)
        
        return days.first { day in
            let dayComponents = dateComponents([.year, .month, .day], from: day.startDate)
            return dayComponents.year == targetComponents.year &&
                   dayComponents.month == targetComponents.month &&
                   dayComponents.day == targetComponents.day
        }
    }
}
