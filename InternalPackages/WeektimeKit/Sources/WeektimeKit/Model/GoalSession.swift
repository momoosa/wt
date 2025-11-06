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
    public private(set) var goal: Goal
    public private(set) var day: Day
    @Relationship public var checklist: [ChecklistItemSession] = []
    public var historicalSessions: [HistoricalSession] {
        day.historicalSessions.filter({ $0.goalIDs.contains(goal.id.uuidString )})
    }
    
    public var dailyTarget: TimeInterval {
        return 600
    }
    public var elapsedTime: TimeInterval {
        historicalSessions.reduce(0) { partialResult, session in
            partialResult + session.duration
        }
    }
    
    public var formattedTime: String {
        return "\(Duration.seconds(elapsedTime).formatted())/\(Duration.seconds(dailyTarget).formatted(.time(pattern: .hourMinute)))"
    }

    public var progress: Double {
        elapsedTime / dailyTarget
    }
    
    public init(title: String, goal: Goal, day: Day) {
        self.id = UUID()
        self.title = title
        self.goal = goal
        self.day = day
    }
}
