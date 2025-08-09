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
    public var title: String
    public var primaryTheme: GoalTheme
    @Relationship
    var goalSessions: [GoalSession] = []
    @Relationship public var checklistItems: [ChecklistItem] = []

    public init(title: String, primaryTheme: GoalTheme) {
        self.title = title
        self.primaryTheme = primaryTheme
    }
}
