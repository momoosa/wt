// ChecklistItem.swift
// MomentumKit
//
// Created by Mo Moosa on 09/08/2025.

import Foundation
import SwiftData

@Model
public final class ChecklistItemSession {
    public var id: String = UUID().uuidString
    
    @Relationship(deleteRule: .nullify)
    public var checklistItem: ChecklistItem?
    
    public var isCompleted: Bool = false
    
    @Relationship(deleteRule: .nullify)
    public var session: GoalSession?
    
    public init(checklistItem: ChecklistItem, isCompleted: Bool = false, session: GoalSession) {
        self.checklistItem = checklistItem
        self.isCompleted = isCompleted
        self.session = session
    }
}
