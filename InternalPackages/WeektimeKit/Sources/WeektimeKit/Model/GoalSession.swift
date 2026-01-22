//
//  GoalSession.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 27/07/2025.
//

import Foundation
import SwiftData

@Model
public final class GoalSession {
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
    
    /// Recommended start time from AI planner (stored as time component like "09:30")
    public var plannedStartTime: String?
    
    /// Suggested duration from AI planner in minutes
    public var plannedDuration: Int?
    
    /// Priority assigned by AI planner (1-5, where 1 is highest)
    public var plannedPriority: Int?
    
    /// AI reasoning for this session's scheduling
    public var plannedReasoning: String?
    
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
    
    public var hasMetDailyTarget: Bool {
        return elapsedTime >= dailyTarget
    }
    
    public var formattedTime: String {
        let elapsedFormatted = Duration.seconds(elapsedTime).formatted(.time(pattern: .hourMinuteSecond))
        let targetFormatted = Duration.seconds(dailyTarget).formatted(.time(pattern: .hourMinuteSecond))
        return "\(elapsedFormatted)/\(targetFormatted)"
    }

    public var progress: Double {
        elapsedTime / dailyTarget
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
        startTime: String,
        duration: Int,
        priority: Int,
        reasoning: String
    ) {
        self.plannedStartTime = startTime
        self.plannedDuration = duration
        self.plannedPriority = priority
        self.plannedReasoning = reasoning
    }
    
    /// Clear planning details
    func clearPlanningDetails() {
        self.plannedStartTime = nil
        self.plannedDuration = nil
        self.plannedPriority = nil
        self.plannedReasoning = nil
    }
}
