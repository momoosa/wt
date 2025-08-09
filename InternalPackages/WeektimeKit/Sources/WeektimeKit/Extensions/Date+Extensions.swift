//
//  Date+Extensions.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 27/07/2025.
//

import Foundation

extension Optional<Date>: @retroactive Comparable {
    public static func < (lhs: Optional, rhs: Optional) -> Bool {
        guard let lhsVal = lhs else {
            return true
        }
        
        guard let rhsVal = rhs else {
            return false
        }
        
        return lhsVal < rhsVal
    }
}

public extension Date {
    func hour(with calendar: Calendar = .current) -> Int {
        return calendar.component(.hour, from: self)
    }
    
    func round(precision: TimeInterval) -> Date {
        return round(precision: precision, rule: .toNearestOrAwayFromZero)
    }
    
    func ceil(precision: TimeInterval) -> Date {
        return round(precision: precision, rule: .up)
    }
    
    func floor(precision: TimeInterval) -> Date {
        return round(precision: precision, rule: .down)
    }
    
    private func round(precision: TimeInterval, rule: FloatingPointRoundingRule) -> Date {
        let seconds = (self.timeIntervalSinceReferenceDate / precision).rounded(rule) * precision;
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
    
    func yearMonthDayID(with calendar: Calendar, timeZoneCorrected: Bool = true) -> String {
        var date = self
        if timeZoneCorrected {
            date.addTimeInterval(TimeInterval(calendar.timeZone.secondsFromGMT()))
        }
        return date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }
    
    
    func startOfDay(in calendar: Calendar = .current) -> Date? {
        return calendar.startOfDay(for: self)
    }
    
    func endOfDay(in calendar: Calendar = .current) -> Date? {
        guard let startOfDay = startOfDay(in: calendar) else { return nil }
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay)!
        
    }
    func startOfWeek(in calendar: Calendar = .current) -> Date? {
        calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date!
    }
    
    func endOfWeek(in calendar: Calendar = .current) -> Date? {
        guard let startOfWeek = startOfWeek(in: calendar) else { return nil }
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfWeek)
        
    }
    
    func weekProgress(calendar: Calendar) -> Double {
        guard let startOfWeek = startOfWeek(in: calendar), let endOfWeek = endOfWeek(in: calendar) else {
            return 0.0
        }
        guard self >= startOfWeek && self <= endOfWeek else {
            return 0.0
        }
        
        return self.timeIntervalSince(startOfWeek) / endOfWeek.timeIntervalSince(startOfWeek)
    }
    
    func remainingTimeInWeek(calendar: Calendar) -> Double {
        guard let startOfWeek = startOfWeek(in: calendar), let endOfWeek = endOfWeek(in: calendar) else {
            return 0.0
        }
        guard self >= startOfWeek && self <= endOfWeek else {
            return 0.0
        }
        
        return endOfWeek.timeIntervalSince(startOfWeek) - self.timeIntervalSince(startOfWeek)
    }
}


public extension ClosedRange where Bound == Date {
    func overlapPercentage(with otherRange: ClosedRange<Bound>) -> Double {
        
        // Scenario 1: Complete overlap
        if contains(otherRange.lowerBound) && contains(otherRange.upperBound) {
            return otherRange.upperBound.timeIntervalSince(otherRange.lowerBound) / upperBound.timeIntervalSince(lowerBound)
        }
        // Scenario 2: Partial overlap
        if otherRange.lowerBound >= lowerBound && upperBound > otherRange.lowerBound {
            return upperBound.timeIntervalSince(otherRange.lowerBound) / upperBound.timeIntervalSince(lowerBound)
        }
        // Scenario 3: Partial overlap
        if otherRange.lowerBound <= lowerBound && otherRange.upperBound > lowerBound { // The `other` range in Scenario 2
            return otherRange.upperBound.timeIntervalSince(lowerBound) / upperBound.timeIntervalSince(lowerBound)
        }
        return 0
    }
}
