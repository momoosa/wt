// ChecklistItem.swift
// MomentumKit
//
// Created by Mo Moosa on 09/08/2025.

import Foundation
import SwiftData

@Model
public final class ChecklistItem {
    public var id: String = UUID().uuidString
    public var title: String
    
    @Relationship(inverse: \Goal.checklistItems)
    public var goal: Goal?
    
    public init(title: String, goal: Goal? = nil) {
        self.title = title
        self.goal = goal
    }
}
