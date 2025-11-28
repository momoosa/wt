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
    @Relationship
    var goalSessions: [GoalSession] = []
    @Relationship public var checklistItems: [ChecklistItem] = []
    @Relationship public var intervalLists: [IntervalList] = []

    public init(title: String, primaryTheme: GoalTheme) {
        self.id = UUID()
        self.title = title
        self.status = .active
        self.primaryTheme = primaryTheme
    }
}

public extension Goal {
    enum Status: String, Codable {
        case suggestion
        case active
        case archived
    }
}
