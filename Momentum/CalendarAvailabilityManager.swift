//
//  CalendarAvailabilityManager.swift
//  Momentum
//
//  Created by Assistant on 20/03/2026.
//

import Foundation
import EventKit
import Combine

/// Manages calendar event fetching and availability calculation
@MainActor
public class CalendarAvailabilityManager: ObservableObject {
    
    private let eventStore = EKEventStore()
    @Published public var hasCalendarAccess = false
    
    public init() {}
    
    // MARK: - Authorization
    
    /// Request calendar access permission
    public func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            hasCalendarAccess = granted
            return granted
        } catch {
            print("Calendar access error: \(error)")
            hasCalendarAccess = false
            return false
        }
    }
    
    /// Check current authorization status
    public func checkAuthorizationStatus() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = (status == .fullAccess)
        return hasCalendarAccess
    }
    
    // MARK: - Availability Calculation
    
    /// Calculate available time for each weekday in the current week
    /// Returns a map of weekday (1-7, where 1=Sunday) to available seconds
    public func calculateWeeklyAvailability(
        workingHoursStart: Int = 6,  // 6 AM
        workingHoursEnd: Int = 22,    // 10 PM
        sleepHours: TimeInterval = 8 * 3600  // 8 hours of sleep
    ) async -> [Int: TimeInterval] {
        guard hasCalendarAccess else {
            print("No calendar access - cannot calculate availability")
            return [:]
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get start and end of current week
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now),
              let weekStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: weekInterval.start),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return [:]
        }
        
        // Fetch all events for the week
        let predicate = eventStore.predicateForEvents(
            withStart: weekStart,
            end: weekEnd,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)
        
        // Calculate availability for each day
        var availability: [Int: TimeInterval] = [:]
        
        for dayOffset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: dayStart)
            
            // Calculate total working hours for the day
            let workingHoursPerDay = TimeInterval((workingHoursEnd - workingHoursStart) * 3600)
            var availableTime = workingHoursPerDay
            
            // Subtract time for calendar events on this day
            let dayEvents = events.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: dayStart)
            }
            
            for event in dayEvents {
                // Skip all-day events
                guard !event.isAllDay else { continue }
                
                let duration = event.endDate.timeIntervalSince(event.startDate)
                availableTime -= duration
            }
            
            // Ensure non-negative
            availableTime = max(0, availableTime)
            
            availability[weekday] = availableTime
        }
        
        return availability
    }
    
    /// Calculate availability for a specific date range
    public func calculateAvailability(
        from startDate: Date,
        to endDate: Date,
        workingHoursStart: Int = 6,
        workingHoursEnd: Int = 22
    ) async -> [Int: TimeInterval] {
        guard hasCalendarAccess else {
            return [:]
        }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)
        
        let calendar = Calendar.current
        var availability: [Int: TimeInterval] = [:]
        
        var currentDate = startDate
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Working hours per day
            let workingHoursPerDay = TimeInterval((workingHoursEnd - workingHoursStart) * 3600)
            var availableTime = workingHoursPerDay
            
            // Get events for this day
            let dayEvents = events.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: currentDate)
            }
            
            for event in dayEvents {
                guard !event.isAllDay else { continue }
                let duration = event.endDate.timeIntervalSince(event.startDate)
                availableTime -= duration
            }
            
            availableTime = max(0, availableTime)
            
            // Add to existing availability for this weekday
            availability[weekday] = (availability[weekday] ?? 0) + availableTime
            
            // Move to next day
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDay
            } else {
                break
            }
        }
        
        // Average the availability across multiple weeks if applicable
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let weekCount = max(1, dayCount / 7)
        
        if weekCount > 1 {
            for (weekday, total) in availability {
                availability[weekday] = total / TimeInterval(weekCount)
            }
        }
        
        return availability
    }
    
    /// Get a human-readable summary of availability
    public func availabilitySummary(_ availability: [Int: TimeInterval]) -> String {
        let calendar = Calendar.current
        let dayNames = calendar.weekdaySymbols
        
        var lines: [String] = []
        for weekday in 1...7 {
            let dayName = dayNames[weekday - 1]
            let hours = (availability[weekday] ?? 0) / 3600
            lines.append("\(dayName): \(String(format: "%.1f", hours))h available")
        }
        
        return lines.joined(separator: "\n")
    }
}
