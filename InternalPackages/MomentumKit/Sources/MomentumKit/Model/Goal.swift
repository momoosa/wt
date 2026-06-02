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
    public private(set) var id: UUID = UUID()
    public var title: String = ""
    public var iconName: String? // SF Symbol name for the goal icon
    private var statusRawValue: String = "active"
    /// Legacy: kept as stored property for SwiftData schema compatibility. Use `targetUnit` instead.
    private var goalTypeRawValue: String = "time"
    
    @Relationship(deleteRule: .nullify)
    public var primaryTag: GoalTag? // Optional tag that provides both theme and smart triggers
    
    /// Denormalized theme ID stored directly on the goal so the color survives
    /// even when the `primaryTag` relationship hasn't been resolved yet (e.g. after
    /// a reinstall while CloudKit is still syncing).
    public var themeID: String?
    
    @Relationship(deleteRule: .nullify)
    public var otherTags: [GoalTag]? = []
    
    public var dailyMinimum: TimeInterval? // Optional minimum time required each day (for strict daily habits)
    
    // Notifications
    public var scheduleNotificationsEnabled: Bool = false // Whether to send notifications at scheduled times
    public var completionNotificationsEnabled: Bool = false // Whether to send notifications when daily target is reached
    
    // Completion Behavior
    private var completionBehaviorsRawValue: [String] = [] // Stores CompletionBehavior raw values
    
    // HealthKit Integration
    public var healthKitMetricRawValue: String? // Stores the HealthKitMetric raw value
    public var healthKitSyncEnabled: Bool = false // Whether to sync time from HealthKit
    public var lastHealthKitSyncDate: Date? // Last time HealthKit data was synced
    
    // Screen Time Integration
    public var screenTimeEnabled: Bool = false // Whether this goal tracks screen time
    public var screenTimeApplicationTokensData: Data? // Serialized Set<ApplicationToken>
    public var screenTimeCategoryTokensData: Data? // Serialized Set<ActivityCategoryToken>
    public var screenTimeWebDomainTokensData: Data? // Serialized Set<WebDomainToken>
    public var screenTimeIsInverseGoal: Bool = false // true = limit usage, false = encourage usage
    public var screenTimeBlockingEnabled: Bool = false // Whether to block apps until goal is complete
    public var screenTimeBlockingStartHour: Int? // Hour when blocking starts (0-23)
    public var screenTimeBlockingEndHour: Int? // Hour when blocking ends (0-23)
    public var screenTimeBlockingWeekdays: [Int] = [] // Days when blocking applies (1=Sun, 2=Mon, etc.)
    
    // Time of Day Preferences (for AI planner)
    public var preferredTimesOfDay: [String] = [] // e.g., ["morning", "afternoon", "evening", "night"]
    
    // Detailed day-time schedule: weekday (1-7) → times of day
    public var dayTimeSchedule: [String: [String]] = [:] // e.g., ["2": ["morning", "afternoon"], "6": ["evening"]]
    
    // MARK: - Unified Target System
    
    /// The unit for this goal's target (seconds, steps, kilocalories). Default is seconds for time-based goals.
    private var targetUnitRawValue: String = "seconds"
    
    /// The canonical daily target value in the goal's native unit (e.g., 1800 seconds, 10000 steps, 500 kcal)
    public var unifiedDailyTarget: Double = 0
    
    /// Per-weekday target overrides in the goal's native unit. Keys are weekday strings ("1"-"7").
    public var perDayTargets: [String: Double] = [:]
    
    // Notes and Resources
    public var notes: String? // User's notes about the goal
    public var link: String? // Optional URL for reference (tutorial, article, etc.)
    
    // Weather-based triggers (overrides tag settings if set)
    public var weatherConditions: [String]? // WeatherCondition raw values
    public var minTemperature: Double? // Celsius
    public var maxTemperature: Double? // Celsius
    public var weatherEnabled: Bool = false // Whether weather-based visibility is enabled
    
    @Relationship(deleteRule: .cascade)
    public var goalSessions: [GoalSession]? = []
    
    @Relationship(deleteRule: .cascade) 
    public var checklistItems: [ChecklistItem]? = []
    
    @Relationship(deleteRule: .cascade) 
    public var intervalLists: [IntervalList]? = []
    
    // Computed property for status
    public var status: Status {
        get { Status(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }
    
    public init(title: String, primaryTag: GoalTag? = nil, otherTags: [GoalTag] = [], scheduleNotificationsEnabled: Bool = false, completionNotificationsEnabled: Bool = false, healthKitMetric: HealthKitMetric? = nil, healthKitSyncEnabled: Bool = false) {
        self.id = UUID()
        self.title = title
        self.status = .active
        self.primaryTag = primaryTag
        self.otherTags = otherTags
        self.scheduleNotificationsEnabled = scheduleNotificationsEnabled
        self.completionNotificationsEnabled = completionNotificationsEnabled
        self.healthKitMetricRawValue = healthKitMetric?.rawValue
        self.healthKitSyncEnabled = healthKitSyncEnabled
    }
    

}

public extension Goal {
    /// Unified target unit for all goal types
    enum TargetUnit: String, Codable, CaseIterable {
        case seconds = "seconds"
        case steps = "steps"
        case kilocalories = "kilocalories"
        
        /// Whether this unit represents time (and thus uses the timer as its primary tracker)
        public var isTimeBased: Bool { self == .seconds }
        
        /// Short label for display (e.g., "min", "steps", "cal")
        public var label: String {
            switch self {
            case .seconds: return "min"
            case .steps: return "steps"
            case .kilocalories: return "cal"
            }
        }
        
        /// Human-readable display name
        public var displayName: String {
            switch self {
            case .seconds: return "Time"
            case .steps: return "Count"
            case .kilocalories: return "Calories"
            }
        }
        
    }
    
    enum Status: String, Codable {
        case suggestion
        case active
        case archived
    }
    
    enum CompletionBehavior: String, Codable, CaseIterable, Identifiable {
        case notify = "notify"
        case moveToCompleted = "move_to_completed"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .notify:
                return "Notify me"
            case .moveToCompleted:
                return "Move to completed section"
            }
        }
        
        public var description: String {
            switch self {
            case .notify:
                return "Send a notification when daily target is reached"
            case .moveToCompleted:
                return "Automatically move goal to completed section"
            }
        }
        
        public var icon: String {
            switch self {
            case .notify:
                return "bell.fill"
            case .moveToCompleted:
                return "checkmark.circle.fill"
            }
        }
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
    

    /// Completion behaviors for this goal
    var completionBehaviors: Set<CompletionBehavior> {
        get {
            var behaviors = Set(completionBehaviorsRawValue.compactMap { CompletionBehavior(rawValue: $0) })
            
            // Migration: if completionNotificationsEnabled is true and no behaviors set, add notify
            if completionNotificationsEnabled && behaviors.isEmpty {
                behaviors.insert(.notify)
            }
            
            return behaviors
        }
        set {
            completionBehaviorsRawValue = newValue.map { $0.rawValue }
            
            // Keep completionNotificationsEnabled in sync for backward compatibility
            completionNotificationsEnabled = newValue.contains(.notify)
        }
    }
    
    // MARK: - Unified Target Computed Properties
    
    /// The unit for this goal's target
    var targetUnit: TargetUnit {
        get { TargetUnit(rawValue: targetUnitRawValue) ?? .seconds }
        set { targetUnitRawValue = newValue.rawValue }
    }
    
    /// Get the unified daily target for a specific weekday, respecting per-day overrides
    func unifiedTarget(for weekday: Int) -> Double {
        if let perDayValue = perDayTargets[String(weekday)] {
            return perDayValue
        }
        return unifiedDailyTarget
    }
    
    /// Computed weekly target from the unified system: sum of per-day targets for scheduled days,
    /// filling unscheduled days with the default daily target
    var unifiedWeeklyTarget: Double {
        if hasSchedule {
            return scheduledWeekdays.reduce(0.0) { sum, weekday in
                sum + unifiedTarget(for: weekday)
            }
        }
        // No schedule means every day
        return (1...7).reduce(0.0) { sum, weekday in
            sum + unifiedTarget(for: weekday)
        }
    }
    
    /// Whether today is a scheduled day for this goal (checks the weekday in the dayTimeSchedule)
    func isScheduledDay(_ weekday: Int) -> Bool {
        guard hasSchedule else { return true }
        return scheduledWeekdays.contains(weekday)
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
    
}

public extension Goal {
    /// Resolved theme preset: prefers `primaryTag.theme`, falls back to the
    /// denormalized `themeID` stored on the goal, then to `ThemeStore.defaultPreset`.
    var resolvedTheme: ThemePreset {
        if let tag = primaryTag {
            return tag.theme
        }
        if let id = themeID {
            return ThemeStore.resolve(for: id)
        }
        return ThemeStore.defaultPreset
    }
    
    func tintColor(for colorScheme: ColorScheme) -> Color {
        return resolvedTheme.color(for: colorScheme)
    }
    
    // MARK: - Weather Helpers
    
    /// Get weather conditions as typed enum array
    var weatherConditionsTyped: [WeatherCondition]? {
        get {
            weatherConditions?.compactMap { WeatherCondition(rawValue: $0) }
        }
        set {
            weatherConditions = newValue?.map { $0.rawValue }
        }
    }
    
    /// Get temperature range if both min and max are set
    var temperatureRange: ClosedRange<Double>? {
        guard let min = minTemperature, let max = maxTemperature else { return nil }
        return min...max
    }
    
    /// Check if goal has any weather-based triggers (either on goal or primary tag)
    var hasWeatherTriggers: Bool {
        if weatherEnabled && (weatherConditions != nil || minTemperature != nil || maxTemperature != nil) {
            return true
        }
        guard let primaryTag = primaryTag else { return false }
        return primaryTag.isSmart && (
            primaryTag.weatherConditions != nil ||
            primaryTag.minTemperature != nil ||
            primaryTag.maxTemperature != nil
        )
    }
    
    /// Get effective weather conditions (goal overrides tag)
    var effectiveWeatherConditions: [WeatherCondition]? {
        if weatherEnabled, let conditions = weatherConditionsTyped {
            return conditions
        }
        return primaryTag?.weatherConditionsTyped
    }
    
    /// Get effective min temperature (goal overrides tag)
    var effectiveMinTemperature: Double? {
        if weatherEnabled, let temp = minTemperature {
            return temp
        }
        return primaryTag?.minTemperature
    }
    
    /// Get effective max temperature (goal overrides tag)
    var effectiveMaxTemperature: Double? {
        if weatherEnabled, let temp = maxTemperature {
            return temp
        }
        return primaryTag?.maxTemperature
    }
}
