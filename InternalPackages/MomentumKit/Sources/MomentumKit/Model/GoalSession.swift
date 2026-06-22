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
    case usualTime = "usual_time"                // Based on historical usage patterns
    case constrained = "constrained"             // Goal is only active now, not later in the day
    case goalSequence = "goal_sequence"          // Linked goal sequence suggests this
    
    public var displayName: String {
        switch self {
        case .weeklyProgress: return "Behind Schedule"
        case .userPriority: return "High Priority"
        case .weather: return "Good Weather"
        case .availableTime: return "Fits Schedule"
        case .plannedTheme: return "Planned Theme"
        case .quickFinish: return "Quick Finish"
        case .preferredTime: return "Preferred Time"
        case .usualTime: return "Usual Time"
        case .constrained: return "Time-Limited"
        case .goalSequence: return "Goal Sequence"
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
        case .usualTime: return "clock.arrow.circlepath"
        case .constrained: return "hourglass"
        case .goalSequence: return "arrow.right.arrow.left.circle.fill"
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
        case .usualTime: return "You often work on this now"
        case .constrained: return "Only available during this time window"
        case .goalSequence: return "Follows your usual flow"
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
    /// Get the goal's theme preset, or default preset if no theme is set.
    /// Uses `Goal.resolvedTheme` which falls back to the denormalized `themeID`
    /// when the `primaryTag` relationship hasn't synced yet.
    public var theme: ThemePreset {
        goal?.resolvedTheme ?? ThemeStore.defaultPreset
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
    @Transient private var _cachedHistoricalSessions: [HistoricalSession]?
    @Transient private var _historicalSessionsCacheKey: Int = -1
    
    public var historicalSessions: [HistoricalSession] {
        let allSessions = day?.historicalSessions
        let currentKey = allSessions?.count ?? -1
        if let cached = _cachedHistoricalSessions, currentKey == _historicalSessionsCacheKey {
            return cached
        }
        let result = allSessions?.filter({ $0.goalIDs.contains(goalID) }) ?? []
        _cachedHistoricalSessions = result
        _historicalSessionsCacheKey = currentKey
        return result
    }
    
    /// Clears the cached historicalSessions so the next access recomputes from the Day's data.
    /// Call after mutating HistoricalSession goalIDs or after HealthKit sync.
    public func invalidateHistoricalSessionsCache() {
        _cachedHistoricalSessions = nil
        _historicalSessionsCacheKey = -1
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
    
    /// The effective target value, auto-repairing from the goal if the cached value
    /// is stale (e.g. session was created before iCloud sync delivered the goal's target).
    public var effectiveTargetValue: Double {
        if unifiedTargetValue > 0 { return unifiedTargetValue }
        // Cached target is 0 — check if the goal actually has a target for this day
        guard let goal = goal, let day = day else { return 0 }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.startDate)
        guard goal.isScheduledDay(weekday) else { return 0 }
        let goalTarget = goal.unifiedTarget(for: weekday)
        if goalTarget > 0 {
            // Auto-repair: persist the corrected value
            unifiedTargetValue = goalTarget
            targetUnitRawValue = goal.targetUnit.rawValue
        }
        return goalTarget
    }
    
    /// Progress as a value from 0.0 onwards (can exceed 1.0 when over target)
    public var progress: Double {
        let target = effectiveTargetValue
        guard target > 0 else { return 0 }
        // For time-based goals that have a count-based HealthKit metric,
        // use the metric value for progress instead of elapsed time
        if targetUnit.isTimeBased {
            if let goal = goal,
               goal.healthKitSyncEnabled,
               goal.healthKitMetric?.isCountBased == true,
               currentValue > 0 {
                return currentValue / target
            }
            let value = currentValue > 0 ? currentValue : elapsedTime
            return value / target
        }
        return currentValue / target
    }
    
    /// Whether the daily target has been met (either by time or manual completion)
    public var hasMetDailyTarget: Bool {
        if markedComplete { return true }
        let target = effectiveTargetValue
        guard target > 0 else { return false }
        // For time-based goals that have a count-based HealthKit metric,
        // use the metric value for completion instead of elapsed time
        if targetUnit.isTimeBased {
            if let goal = goal,
               goal.healthKitSyncEnabled,
               goal.healthKitMetric?.isCountBased == true,
               currentValue > 0 {
                return currentValue >= target
            }
            let value = currentValue > 0 ? currentValue : elapsedTime
            return value >= target
        }
        return currentValue >= target
    }
    
    public var formattedTime: String {
        let target = effectiveTargetValue
        // For time-based goals that have a count-based HealthKit metric,
        // show metric format instead of time format
        if targetUnit.isTimeBased {
            if let goal = goal,
               goal.healthKitSyncEnabled,
               let metric = goal.healthKitMetric,
               metric.isCountBased {
                let current = Int(currentValue)
                let targetInt = Int(target)
                switch metric {
                case .activeEnergyBurned:
                    return "\(current) cal/\(targetInt) cal"
                case .stepCount:
                    return "\(current.formatted())/\(targetInt.formatted())"
                default:
                    return "\(current)/\(targetInt)"
                }
            }
            let value = currentValue > 0 ? currentValue : elapsedTime
            return value.formattedProgress(target: target)
        }
        
        let current = Int(currentValue)
        let targetInt = Int(target)
        switch targetUnit {
        case .kilocalories:
            return "\(current) cal/\(targetInt) cal"
        case .steps:
            return "\(current.formatted())/\(targetInt.formatted())"
        case .seconds, .screenTime:
            return elapsedTime.formattedProgress(target: target)
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
    
    /// Update the primary metric value (for count/calorie-based goals).
    /// Also accepts values when the goal has a count-based HealthKit metric
    /// even if `targetUnit` is time-based (handles misconfigured goals).
    func updatePrimaryMetricValue(_ value: Double) {
        if !targetUnit.isTimeBased {
            currentValue = value
        } else if let goal = goal,
                  goal.healthKitSyncEnabled,
                  goal.healthKitMetric?.isCountBased == true {
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
    
    /// Sync currentValue from elapsedTime (for time-based goals only).
    /// Skips sync for goals with count-based HealthKit metrics to avoid
    /// overwriting the metric value (e.g., step count) with elapsed time.
    func syncCurrentValueFromElapsedTime() {
        guard targetUnit.isTimeBased else { return }
        // Don't overwrite count-based metric values with elapsed time
        if let goal = goal,
           goal.healthKitSyncEnabled,
           goal.healthKitMetric?.isCountBased == true {
            return
        }
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

// MARK: - Safe SwiftData Access

public extension GoalSession {
    /// Safely access recommendationReasons — returns empty array if the SwiftData
    /// backing store has been invalidated (e.g. session deleted mid-evaluation).
    var safeRecommendationReasons: [RecommendationReason] {
        guard (try? persistentModelID) != nil else { return [] }
        return recommendationReasons
    }
}


