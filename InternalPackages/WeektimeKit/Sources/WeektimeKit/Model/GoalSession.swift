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
        }
    }
}

@Model
public final class GoalSession: SessionProgressProvider {
    public var id: UUID
    public var title: String
    public var status: Status
    public private(set) var goal: Goal
    public private(set) var day: Day
    @Relationship public var checklist: [ChecklistItemSession] = []
    @Relationship public var intervalLists: [IntervalListSession] = []
    public var historicalSessions: [HistoricalSession] {
        day.historicalSessions.filter({ $0.goalIDs.contains(goal.id.uuidString )})
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
    
    public var dailyTarget: TimeInterval {
        return goal.weeklyTarget / 7
    }
    
    /// Total elapsed time including both manual tracking and HealthKit data
    public var elapsedTime: TimeInterval {
        // historicalSessions already includes both manual sessions and HealthKit sessions
        // (HealthKit sessions have healthKitType != nil)
        let totalTime = historicalSessions.reduce(0) { partialResult, session in
            partialResult + session.duration
        }
        
        return totalTime
    }
    
    public var formattedTime: String {
        let elapsedFormatted = elapsedTime.formatted(style: .components)
        let targetFormatted = dailyTarget.formatted(style: .components)
        return "\(elapsedFormatted)/\(targetFormatted)"
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
        self.intervalLists = goal.intervalLists.map({ interval in
            IntervalListSession(list: interval)
        })
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
}
