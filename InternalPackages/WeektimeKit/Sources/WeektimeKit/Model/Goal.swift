//
//  Goal.swift
//  MomentumKit
//
//  Created by Mo Moosa on 26/07/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
public final class Goal {
    public private(set) var id: UUID
    public var title: String
    public var iconName: String? // SF Symbol name for the goal icon
    public var status: Status
    public var primaryTag: GoalTag // Optional tag that provides both theme and smart triggers
    public var otherTags: [GoalTag]
    public var weeklyTarget: TimeInterval // Target duration in seconds for the week
    public var dailyMinimum: TimeInterval? // Optional minimum time required each day (for strict daily habits)
    
    // Notifications
    public var notificationsEnabled: Bool // Legacy: kept for backward compatibility
    public var scheduleNotificationsEnabled: Bool = false // Whether to send notifications at scheduled times
    public var completionNotificationsEnabled: Bool = false // Whether to send notifications when daily target is reached
    
    // HealthKit Integration
    public var healthKitMetricRawValue: String? // Stores the HealthKitMetric raw value
    public var healthKitSyncEnabled: Bool = false // Whether to sync time from HealthKit
    
    // Time of Day Preferences (for AI planner)
    public var preferredTimesOfDay: [String] = [] // e.g., ["morning", "afternoon", "evening", "night"]
    
    // Detailed day-time schedule: weekday (1-7) → times of day
    public var dayTimeSchedule: [String: [String]] = [:] // e.g., ["2": ["morning", "afternoon"], "6": ["evening"]]
    
    @Relationship(deleteRule: .cascade)
    public var goalSessions: [GoalSession] = []
    @Relationship(deleteRule: .cascade) 
    public var checklistItems: [ChecklistItem] = []
    @Relationship(deleteRule: .cascade) 
    public var intervalLists: [IntervalList] = []

    public init(title: String, primaryTag: GoalTag, otherTags: [GoalTag] = [], weeklyTarget: TimeInterval = 0, notificationsEnabled: Bool = false, scheduleNotificationsEnabled: Bool = false, completionNotificationsEnabled: Bool = false, healthKitMetric: HealthKitMetric? = nil, healthKitSyncEnabled: Bool = false) {
        self.id = UUID()
        self.title = title
        self.status = .active
        self.primaryTag = primaryTag
        self.otherTags = otherTags
        self.weeklyTarget = weeklyTarget
        self.notificationsEnabled = notificationsEnabled
        self.scheduleNotificationsEnabled = scheduleNotificationsEnabled
        self.completionNotificationsEnabled = completionNotificationsEnabled
        self.healthKitMetricRawValue = healthKitMetric?.rawValue
        self.healthKitSyncEnabled = healthKitSyncEnabled
    }
    

}

public extension Goal {
    enum Status: String, Codable {
        case suggestion
        case active
        case archived
    }
    
    /// The HealthKit metric associated with this goal, if any
    var healthKitMetric: HealthKitMetric? {
        get {
            guard let rawValue = healthKitMetricRawValue else { return nil }
            return HealthKitMetric(rawValue: rawValue)
        }
        set {
            healthKitMetricRawValue = newValue?.rawValue
        }
    }
    
    // MARK: - Day-Time Schedule Convenience Methods
    
    /// Get times of day for a specific weekday (1 = Sunday, 2 = Monday, etc.)
    func timesForWeekday(_ weekday: Int) -> Set<TimeOfDay> {
        guard let timeStrings = dayTimeSchedule[String(weekday)] else {
            return []
        }
        return Set(timeStrings.compactMap { TimeOfDay(rawValue: $0) })
    }
    
    /// Set times of day for a specific weekday
    func setTimes(_ times: Set<TimeOfDay>, forWeekday weekday: Int) {
        if times.isEmpty {
            dayTimeSchedule.removeValue(forKey: String(weekday))
        } else {
            dayTimeSchedule[String(weekday)] = times.map { $0.rawValue }.sorted()
        }
    }
    
    /// Check if goal has any scheduled times
    var hasSchedule: Bool {
        !dayTimeSchedule.isEmpty
    }
    
    /// Get all weekdays that have scheduled times
    var scheduledWeekdays: [Int] {
        dayTimeSchedule.keys.compactMap { Int($0) }.sorted()
    }
    
    /// Check if a specific day and time is scheduled
    func isScheduled(weekday: Int, time: TimeOfDay) -> Bool {
        timesForWeekday(weekday).contains(time)
    }
    
    /// Get a human-readable schedule summary
    var scheduleSummary: String {
        guard hasSchedule else { return "Anytime" }
        
        let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var summaries: [String] = []
        
        for weekday in scheduledWeekdays {
            let times = timesForWeekday(weekday)
            let dayName = weekdayNames[weekday]
            let timeNames = times.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.displayName }
            summaries.append("\(dayName): \(timeNames.joined(separator: ", "))")
        }
        
        return summaries.joined(separator: "\n")
    }
    
    /// Calculate daily target based on schedule
    /// If a schedule exists, divides weekly target by number of scheduled days
    /// Otherwise, divides by 7 (every day)
    func dailyTargetFromSchedule() -> TimeInterval {
        // If dailyMinimum is set, use that
        if let dailyMinimum = dailyMinimum {
            return dailyMinimum
        }
        
        // If there's a schedule, divide by scheduled days
        if hasSchedule {
            let scheduledDaysCount = scheduledWeekdays.count
            guard scheduledDaysCount > 0 else {
                return weeklyTarget / 7
            }
            return weeklyTarget / TimeInterval(scheduledDaysCount)
        }
        
        // Default: divide by 7
        return weeklyTarget / 7
    }
}

public extension Goal {
    func tintColor(for colorScheme: ColorScheme) -> Color {
        return primaryTag.theme.color(for: colorScheme)
    }
}
