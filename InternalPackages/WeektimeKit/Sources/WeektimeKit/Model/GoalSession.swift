//
//  GoalSession.swift
//  MomentumKit
//
//  Created by Mo Moosa on 27/07/2025.
//

import Foundation
import SwiftData

/// Reasons why a goal session is recommended
public enum RecommendationReason: String, Codable, CaseIterable, Hashable {
    case weeklyProgress = "weekly_progress"      // Behind on weekly target for the day of week
    case userPriority = "user_priority"          // User has set this as high priority
    case weather = "weather"                     // Weather matches goal preferences
    case availableTime = "available_time"        // Fits in user's available time
    case plannedTheme = "planned_theme"          // Matches theme selected in planner
    case quickFinish = "quick_finish"            // Close to completing (< 25% remaining)
    case preferredTime = "preferred_time"        // Matches user's preferred time of day
    case energyLevel = "energy_level"            // Optimal for current time's energy level
    case usualTime = "usual_time"                // Based on historical usage patterns
    case constrained = "constrained"             // Goal is only active now, not later in the day
    
    public var displayName: String {
        switch self {
        case .weeklyProgress: return "Behind Schedule"
        case .userPriority: return "High Priority"
        case .weather: return "Good Weather"
        case .availableTime: return "Fits Schedule"
        case .plannedTheme: return "Planned Theme"
        case .quickFinish: return "Quick Finish"
        case .preferredTime: return "Preferred Time"
        case .energyLevel: return "Peak Energy"
        case .usualTime: return "Usual Time"
        case .constrained: return "Time-Limited"
        }
    }
    
    public var icon: String {
        switch self {
        case .weeklyProgress: return "chart.line.uptrend.xyaxis"
        case .userPriority: return "star.fill"
        case .weather: return "cloud.sun.fill"
        case .availableTime: return "clock.fill"
        case .plannedTheme: return "tag.fill"
        case .quickFinish: return "flag.checkered"
        case .preferredTime: return "calendar"
        case .energyLevel: return "bolt.fill"
        case .usualTime: return "clock.arrow.circlepath"
        case .constrained: return "hourglass"
        }
    }
    
    public var description: String {
        switch self {
        case .weeklyProgress: return "You're behind on your weekly target"
        case .userPriority: return "You marked this as important"
        case .weather: return "Current weather is ideal"
        case .availableTime: return "Fits your available time"
        case .plannedTheme: return "Matches your focus area"
        case .quickFinish: return "Almost done - finish it now"
        case .preferredTime: return "Your preferred time slot"
        case .energyLevel: return "Best time for focus"
        case .usualTime: return "You often work on this now"
        case .constrained: return "Only available during this time window"
        }
    }
}

// MARK: - Active Goal Helpers

extension GoalSession {
    /// Check if this session represents an active goal (has schedule and weekly target)
    public var isActiveGoal: Bool {
        guard let goal = goal else { return false }
        return goal.hasSchedule && (goal.weeklyTarget ?? 0) > 0
    }
}

// MARK: - Theme Helpers

import SwiftUI

extension GoalSession {
    /// Get the goal's theme preset, or default preset if no theme is set
    public var theme: ThemePreset {
        goal?.primaryTag?.theme ?? themePresets[0]
    }
    
    /// Alias for backward compatibility
    public var themePreset: ThemePreset {
        theme
    }
    
    /// Get the theme's dark color, or gray if no theme is set
    public var themeDark: Color {
        goal?.primaryTag?.themePreset.dark ?? .gray
    }
    
    /// Get the theme's neon color, or gray if no theme is set
    public var themeNeon: Color {
        goal?.primaryTag?.themePreset.neon ?? .gray
    }
    
    /// Get the theme's light color, or gray if no theme is set
    public var themeLight: Color {
        goal?.primaryTag?.themePreset.light ?? .gray
    }
    
    /// Get the theme's gradient, or default gradient if no theme is set
    public var themeGradient: LinearGradient {
        goal?.primaryTag?.themePreset.gradient ?? themePresets[0].gradient
    }
    
    /// Get the theme's color for the current color scheme
    public func themeColor(for colorScheme: ColorScheme) -> Color {
        goal?.primaryTag?.themePreset.color(for: colorScheme) ?? themePresets[0].color(for: colorScheme)
    }
    
    /// Get the theme's text color for the current color scheme
    public func themeTextColor(for colorScheme: ColorScheme) -> Color {
        goal?.primaryTag?.theme.textColor(for: colorScheme) ?? .primary
    }
}

@Model
public final class GoalSession: SessionProgressProvider {
    public var id: UUID = UUID()
    public var title: String = ""
    private var statusRawValue: String = "active"
    
    // Computed property for status
    public var status: Status {
        get { Status(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .nullify)
    public var goal: Goal?
    
    @Relationship(deleteRule: .nullify)
    public var day: Day?
    
    /// Cached goal ID to avoid accessing deleted goal
    public var goalID: String = ""
    
    @Relationship(deleteRule: .cascade)
    public var checklist: [ChecklistItemSession]? = []
    
    @Relationship(deleteRule: .cascade)
    public var intervalLists: [IntervalListSession]? = []
    public var historicalSessions: [HistoricalSession] {
        day?.historicalSessions?.filter({ $0.goalIDs.contains(goalID)}) ?? []
    }
    
    /// Time tracked from HealthKit for this session (if enabled)
    public private(set) var healthKitTime: TimeInterval = 0
    
    /// Primary metric value for count/calorie-based goals (e.g., steps, calories)
    public var primaryMetricValue: Double = 0
    
    /// Target value for the primary metric (cached from goal at creation time)
    public var primaryMetricTarget: Double = 0
    
    // MARK: - AI Planning Properties
    
    /// Recommended start time from AI planner
    public var plannedStartTime: Date?
    
    /// Suggested duration from AI planner in minutes
    public var plannedDuration: Int?
    
    /// Priority assigned by AI planner (1-5, where 1 is highest)
    public var plannedPriority: Int?
    
    /// AI reasoning for this session's scheduling
    public var plannedReasoning: String?
    
    /// Structured recommendation reasons
    public var recommendationReasons: [RecommendationReason] = []
    
    /// Whether this session is pinned to appear in widgets
    public var pinnedInWidget: Bool = false
    
    /// Cached daily target to avoid accessing deleted goal
    /// This is set when the session is created and doesn't change
    public var dailyTarget: TimeInterval = 0
    
    /// Whether this session has been manually marked as complete for the day
    public var markedComplete: Bool = false
    
    /// Total elapsed time including both manual tracking and HealthKit data
    /// Deduplicates overlapping sessions to avoid double-counting time
    public var elapsedTime: TimeInterval {
        // historicalSessions already includes both manual sessions and HealthKit sessions
        // (HealthKit sessions have healthKitType != nil)
        
        // Sort sessions by start date for efficient merging
        let sortedSessions = historicalSessions.sorted { $0.startDate < $1.startDate }
        
        // Merge overlapping time intervals
        var mergedIntervals: [(start: Date, end: Date)] = []
        
        for session in sortedSessions {
            if mergedIntervals.isEmpty {
                mergedIntervals.append((session.startDate, session.endDate))
            } else {
                let lastIndex = mergedIntervals.count - 1
                let last = mergedIntervals[lastIndex]
                
                // Check if current session overlaps with the last merged interval
                if session.startDate <= last.end {
                    // Overlapping - extend the last interval if needed
                    mergedIntervals[lastIndex].end = max(last.end, session.endDate)
                } else {
                    // Non-overlapping - add as new interval
                    mergedIntervals.append((session.startDate, session.endDate))
                }
            }
        }
        
        // Calculate total time from merged intervals
        let totalTime = mergedIntervals.reduce(0.0) { sum, interval in
            sum + interval.end.timeIntervalSince(interval.start)
        }
        
        return totalTime
    }
    
    /// Progress as a value from 0.0 onwards (can exceed 1.0 when over target)
    /// Overrides the default SessionProgressProvider implementation to handle count/calorie goals
    public var progress: Double {
        guard let goal = goal else {
            // Fallback to time-based progress if goal is nil
            guard dailyTarget > 0 else { return 0 }
            return elapsedTime / dailyTarget
        }
        
        switch goal.goalType {
        case .time:
            guard dailyTarget > 0 else { return 0 }
            return elapsedTime / dailyTarget
        case .count, .calories:
            guard primaryMetricTarget > 0 else { return 0 }
            return primaryMetricValue / primaryMetricTarget
        }
    }
    
    /// Whether the daily target has been met (either by time or manual completion)
    public var hasMetDailyTarget: Bool {
        // If manually marked complete, always return true
        if markedComplete {
            return true
        }
        
        // Check based on goal type
        guard let goal = goal else {
            // Fallback to time-based check if goal is nil
            return elapsedTime >= dailyTarget
        }
        
        switch goal.goalType {
        case .time:
            return elapsedTime >= dailyTarget
        case .count, .calories:
            return primaryMetricValue >= primaryMetricTarget
        }
    }
    
    public var formattedTime: String {
        guard let goal = goal else {
            let elapsedFormatted = elapsedTime.formatted(style: .components)
            let targetFormatted = dailyTarget.formatted(style: .components)
            return "\(elapsedFormatted)/\(targetFormatted)"
        }
        
        switch goal.goalType {
        case .time:
            let elapsedFormatted = elapsedTime.formatted(style: .components)
            let targetFormatted = dailyTarget.formatted(style: .components)
            return "\(elapsedFormatted)/\(targetFormatted)"
        case .count:
            let currentValue = Int(primaryMetricValue)
            let targetValue = Int(primaryMetricTarget)
            return "\(currentValue.formatted())/\(targetValue.formatted())"
        case .calories:
            let currentValue = Int(primaryMetricValue)
            let targetValue = Int(primaryMetricTarget)
            return "\(currentValue) cal/\(targetValue) cal"
        }
    }
    
    /// Formatted planned start time (e.g., "9:30 AM")
    public var formattedPlannedStartTime: String? {
        guard let startTime = plannedStartTime else { return nil }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    public init(title: String, goal: Goal, day: Day) {
        self.id = UUID()
        self.title = title
        self.goal = goal
        self.day = day
        self.status = .active
        // Cache goal properties at creation time to avoid accessing goal after deletion
        self.goalID = goal.id.uuidString
        
        // Cache primary metric target for count/calorie goals
        self.primaryMetricTarget = goal.primaryMetricDailyTarget
        
        // Calculate daily target only if today is a scheduled day
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.startDate)
        
        if goal.hasSchedule {
            let scheduledWeekdays = goal.scheduledWeekdays
            
            if scheduledWeekdays.contains(weekday) {
                self.dailyTarget = goal.dailyTarget(for: weekday)
            } else {
                // Not a scheduled day, so no target
                self.dailyTarget = 0
            }
        } else {
            // No schedule means all days are active
            self.dailyTarget = goal.dailyTarget(for: weekday)
        }
        
        self.intervalLists = goal.intervalLists?.map({ interval in
            IntervalListSession(list: interval)
        }) ?? []
    }
}

public extension GoalSession {
    enum Status: String, Codable {
        case suggestion
        case active
        case skipped
    }
    
    /// Update the HealthKit time for this session
    public func updateHealthKitTime(_ time: TimeInterval) {
        healthKitTime = time
    }
    
    /// Update the primary metric value (for count/calorie-based goals)
    public func updatePrimaryMetricValue(_ value: Double) {
        primaryMetricValue = value
    }
    
    /// Update planning details from AI planner
    func updatePlanningDetails(
        startTime: Date,
        duration: Int,
        priority: Int,
        reasoning: String,
        reasons: [RecommendationReason] = []
    ) {
        self.plannedStartTime = startTime
        self.plannedDuration = duration
        self.plannedPriority = priority
        self.plannedReasoning = reasoning
        self.recommendationReasons = reasons
    }
    
    /// Clear planning details
    func clearPlanningDetails() {
        self.plannedStartTime = nil
        self.plannedDuration = nil
        self.plannedPriority = nil
        self.plannedReasoning = nil
        self.recommendationReasons = []
    }
    
    /// Update the cached daily target from the goal's current schedule
    /// Call this when the goal's schedule changes
    func updateDailyTarget() {
        guard let goal = goal, let day = day else {
            self.dailyTarget = 0
            return
        }
        
        // Calculate daily target only if today is a scheduled day
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.startDate)
        
        if goal.hasSchedule {
            let scheduledWeekdays = goal.scheduledWeekdays
            
            if scheduledWeekdays.contains(weekday) {
                self.dailyTarget = goal.dailyTarget(for: weekday)
            } else {
                // Not a scheduled day, so no target
                self.dailyTarget = 0
            }
        } else {
            // No schedule means all days are active
            self.dailyTarget = goal.dailyTarget(for: weekday)
        }
    }
}


