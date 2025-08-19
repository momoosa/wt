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
    
    public init(title: String, goal: Goal, day: Day) {
        self.id = UUID()
        self.title = title
        self.goal = goal
        self.day = day
    }
}
