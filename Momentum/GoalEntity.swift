//
//  GoalEntity.swift
//  Momentum
//
//  Created by Assistant on 07/03/2026.
//

import Foundation
import AppIntents
import MomentumKit
import SwiftData

/// Entity representation of a Goal for App Intents
struct GoalEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Goal")
    static var defaultQuery = GoalEntityQuery()
    
    var id: String
    var title: String
    var iconName: String?
    var weeklyTarget: TimeInterval
    var isActive: Bool
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: isActive ? "Active" : "Inactive",
            image: iconName.map { .init(systemName: $0) }
        )
    }
    
    /// Initialize from a Goal model
    init(from goal: Goal) {
        self.id = goal.id.uuidString
        self.title = goal.title
        self.iconName = goal.iconName
        self.weeklyTarget = goal.weeklyTarget
        self.isActive = goal.status == .active
    }
}

/// Query provider for goals
struct GoalEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [GoalEntity] {
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Goal>()
        let goals = try context.fetch(descriptor)
        
        return goals
            .filter { identifiers.contains($0.id.uuidString) }
            .map { GoalEntity(from: $0) }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [GoalEntity] {
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Goal>()
        let goals = try context.fetch(descriptor)
        
        return goals
            .filter { $0.status == .active }
            .prefix(5)
            .map { GoalEntity(from: $0) }
    }
    
    @MainActor
    func defaultResult() async -> GoalEntity? {
        let container = try? createSharedModelContainer()
        guard let container = container else { return nil }
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Goal>()
        let goals = try? context.fetch(descriptor)
        return goals?.first(where: { $0.status == .active }).map { GoalEntity(from: $0) }
    }
}

/// String query for finding goals by name
extension GoalEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [GoalEntity] {
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Goal>()
        let goals = try context.fetch(descriptor)
        let lowercased = string.lowercased()
        
        return goals
            .filter { $0.status == .active && $0.title.lowercased().contains(lowercased) }
            .map { GoalEntity(from: $0) }
    }
}
