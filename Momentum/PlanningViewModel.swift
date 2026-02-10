//
//  PlanningViewModel.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import MomentumKit

/// Observable view model managing AI planning state
@MainActor
@Observable
class PlanningViewModel {
    // MARK: - Planning Configuration
    var selectedThemes: Set<String> = []
    var availableTimeMinutes: Int = 120
    
    // MARK: - Planning State
    var isPlanning: Bool = false
    var showPlanningComplete: Bool = false
    var revealedSessionIDs: Set<UUID> = []
    var hasAutoPlannedToday: Bool = false
    
    // MARK: - Cached Data
    var cachedThemes: [GoalTag] = []
    
    // MARK: - Internal State
    var planningTask: Task<Void, Never>?
    
    // MARK: - Services
    let planner: GoalSessionPlanner
    var plannerPreferences: PlannerPreferences
    
    // MARK: - Initialization
    init(
        planner: GoalSessionPlanner? = nil,
        preferences: PlannerPreferences = .default
    ) {
        self.planner = planner ?? GoalSessionPlanner()
        self.plannerPreferences = preferences
    }
    
    // MARK: - Actions
    
    /// Cancel the current planning task
    func cancelPlanning() {
        planningTask?.cancel()
        planningTask = nil
        isPlanning = false
    }
    
    /// Reset planning state for a new day
    func resetForNewDay() {
        hasAutoPlannedToday = false
        revealedSessionIDs.removeAll()
    }
    
    /// Clear cached themes
    func clearCache() {
        cachedThemes.removeAll()
    }
}
