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
    /// Check if this session represents an active goal (has schedule and a target)
    public var isActiveGoal: Bool {
        guard let goal = goal else { return false }
        return goal.hasSchedule && (goal.unifiedDailyTarget > 0 || !goal.perDayTargets.isEmpty)
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
    
    // MARK: - Unified Target System
    
    /// The target unit for this session, cached from the goal at creation time
    private var targetUnitRawValue: String = "seconds"
    
    /// The target value for this session in the goal's native unit (cached from goal)
    public var unifiedTargetValue: Double = 0
    
    /// Current progress value in the goal's native unit.
    /// For time goals: synced from elapsedTime. For metric goals: synced from HealthKit.
    public var currentValue: Double = 0
    
    /// The target unit for this session
    public var targetUnit: Goal.TargetUnit {
        Goal.TargetUnit(rawValue: targetUnitRawValue) ?? .seconds
    }
    
    /// Whether this session has been manually marked as complete for the day
    public var markedComplete: Bool = false
    
    /// Total elapsed time including both manual tracking and HealthKit data
    /// Deduplicates overlapping sessions to avoid double-counting time
    public var elapsedTime: TimeInterval {
        let sortedSessions = historicalSessions.sorted { $0.startDate < $1.startDate }
        let hasHKSessions = sortedSessions.contains { $0.healthKitType != nil }
        
        if !hasHKSessions && healthKitTime > 0 {
            // Aggregate path: no individual HK sessions, use healthKitTime directly
            // Manual sessions still need interval merging for deduplication
            let manualIntervals = sortedSessions.map { (start: $0.startDate, end: $0.endDate) }
            let manualTime = mergedDuration(from: manualIntervals)
            return healthKitTime + manualTime
        }
        
        // Standard path: merge all historical sessions (manual + HK)
        let intervals = sortedSessions.map { (start: $0.startDate, end: $0.endDate) }
        return mergedDuration(from: intervals)
    }
    
    /// Calculate total duration from a list of time intervals, merging overlaps
    private func mergedDuration(from intervals: [(start: Date, end: Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        
        var merged: [(start: Date, end: Date)] = []
        
        for interval in intervals {
            if merged.isEmpty {
                merged.append(interval)
            } else {
                let lastIndex = merged.count - 1
                let last = merged[lastIndex]
                
                if interval.start <= last.end {
                    merged[lastIndex].end = max(last.end, interval.end)
                } else {
                    merged.append(interval)
                }
            }
        }
        
        return merged.reduce(0.0) { sum, interval in
            sum + interval.end.timeIntervalSince(interval.start)
        }
    }
    
    /// Progress as a value from 0.0 onwards (can exceed 1.0 when over target)
    public var progress: Double {
        guard unifiedTargetValue > 0 else { return 0 }
        // For time-based goals, currentValue may not be synced yet for older sessions,
        // so fall back to elapsedTime
        if targetUnit.isTimeBased {
            let value = currentValue > 0 ? currentValue : elapsedTime
            return value / unifiedTargetValue
        }
        return currentValue / unifiedTargetValue
    }
    
    /// Whether the daily target has been met (either by time or manual completion)
    public var hasMetDailyTarget: Bool {
        if markedComplete { return true }
        guard unifiedTargetValue > 0 else { return false }
        if targetUnit.isTimeBased {
            let value = currentValue > 0 ? currentValue : elapsedTime
            return value >= unifiedTargetValue
        }
        return currentValue >= unifiedTargetValue
    }
    
    public var formattedTime: String {
        if targetUnit.isTimeBased {
            let value = currentValue > 0 ? currentValue : elapsedTime
            return value.formattedProgress(target: unifiedTargetValue)
        }
        
        let current = Int(currentValue)
        let target = Int(unifiedTargetValue)
        switch targetUnit {
        case .kilocalories:
            return "\(current) cal/\(target) cal"
        case .steps:
            return "\(current.formatted())/\(target.formatted())"
        case .seconds:
            return elapsedTime.formattedProgress(target: unifiedTargetValue)
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
        
        // Set unified target from goal's schedule
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.startDate)
        self.targetUnitRawValue = goal.targetUnit.rawValue
        if goal.isScheduledDay(weekday) {
            self.unifiedTargetValue = goal.unifiedTarget(for: weekday)
        } else {
            self.unifiedTargetValue = 0
        }
        self.currentValue = 0
        
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
    func updateHealthKitTime(_ time: TimeInterval) {
        healthKitTime = time
        // For time-based goals, sync currentValue from elapsed time
        if targetUnit.isTimeBased {
            syncCurrentValueFromElapsedTime()
        }
    }
    
    /// Update the primary metric value (for count/calorie-based goals)
    func updatePrimaryMetricValue(_ value: Double) {
        if !targetUnit.isTimeBased {
            currentValue = value
        }
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
    
    /// Sync currentValue from elapsedTime (for time-based goals only)
    func syncCurrentValueFromElapsedTime() {
        guard targetUnit.isTimeBased else { return }
        currentValue = elapsedTime
    }
    
    /// Update the unified target value from the goal's current schedule
    func updateUnifiedTarget() {
        guard let goal = goal, let day = day else {
            unifiedTargetValue = 0
            return
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.startDate)
        targetUnitRawValue = goal.targetUnit.rawValue
        
        if goal.isScheduledDay(weekday) {
            unifiedTargetValue = goal.unifiedTarget(for: weekday)
        } else {
            unifiedTargetValue = 0
        }
    }
    
    /// Update the cached target from the goal's current schedule
    /// Call this when the goal's schedule changes
    func updateDailyTarget() {
        guard let goal = goal, let day = day else {
            self.unifiedTargetValue = 0
            return
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.startDate)
        self.targetUnitRawValue = goal.targetUnit.rawValue
        
        if goal.isScheduledDay(weekday) {
            self.unifiedTargetValue = goal.unifiedTarget(for: weekday)
        } else {
            self.unifiedTargetValue = 0
        }
    }
}


