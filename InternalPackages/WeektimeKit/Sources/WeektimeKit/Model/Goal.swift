//
//  Goal.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 26/07/2025.
//

import Foundation
import SwiftData

@Model
public final class Goal {
    public private(set) var id: UUID
    public var title: String
    public var status: Status
    public var primaryTheme: GoalTheme
    public var weeklyTarget: TimeInterval // Target duration in seconds for the week
    public var notificationsEnabled: Bool // Whether to send notifications when target is reached
    @Relationship
    var goalSessions: [GoalSession] = []
    @Relationship public var checklistItems: [ChecklistItem] = []
    @Relationship public var intervalLists: [IntervalList] = []

    public init(title: String, primaryTheme: GoalTheme, weeklyTarget: TimeInterval = 0, notificationsEnabled: Bool = false) {
        self.id = UUID()
        self.title = title
        self.status = .active
        self.primaryTheme = primaryTheme
        self.weeklyTarget = weeklyTarget
        self.notificationsEnabled = notificationsEnabled
    }
}

public extension Goal {
    enum Status: String, Codable {
        case suggestion
        case active
        case archived
    }
}
