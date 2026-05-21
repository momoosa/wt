// ChecklistItem.swift
// MomentumKit
//
// Created by Mo Moosa on 09/08/2025.

import Foundation
import SwiftData

@Model
public final class ChecklistItem {
    public var id: String = UUID().uuidString
    public var title: String = ""
    public var notes: String? // Optional notes for the checklist item
    
    @Relationship(deleteRule: .nullify)
    public var goal: Goal?
    
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItemSession.checklistItem)
    public var sessions: [ChecklistItemSession]? = []
    
    public init(title: String, notes: String? = nil, goal: Goal? = nil) {
        self.title = title
        self.notes = notes
        self.goal = goal
    }
}
