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
    var availableTimeMinutes: Int = 60
    var selectedWeather: WeatherCondition? = nil // nil means current/auto
    
    // MARK: - Planning State
    var isPlanning: Bool = false
    var showPlanningComplete: Bool = false
    var revealedSessionIDs: Set<UUID> = []
    var hasAutoPlannedToday: Bool = false
    
    /// Whether a stagger-in animation is currently running
    var isStaggering: Bool = false
    
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
        isStaggering = false
    }
    
    /// Stagger-reveal a list of session IDs one by one
    func staggerReveal(sessionIDs: [UUID]) {
        guard !sessionIDs.isEmpty else { return }
        
        revealedSessionIDs.removeAll()
        isStaggering = true
        
        Task {
            // Small delay to let SwiftUI process data changes before animating
            try? await Task.sleep(for: .seconds(0.15))
            
            for (index, id) in sessionIDs.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .seconds(0.06))
                }
                withAnimation(.easeOut(duration: 0.35)) {
                    revealedSessionIDs.insert(id)
                }
            }
            
            // Mark stagger complete after last animation finishes
            try? await Task.sleep(for: .seconds(0.35))
            isStaggering = false
        }
    }
    
    /// Clear cached themes
    func clearCache() {
        cachedThemes.removeAll()
    }
}
