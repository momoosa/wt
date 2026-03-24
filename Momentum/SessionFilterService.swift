//
//  SessionFilterService.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import Foundation
import MomentumKit
import SwiftData

/// Service for filtering and counting goal sessions
struct SessionFilterService {
    
    /// Count sessions matching a filter
    /// - Parameters:
    ///   - sessions: All sessions to count
    ///   - filter: The filter to apply
    /// - Returns: Count of matching sessions
    static func count(_ sessions: [GoalSession], for filter: ContentView.Filter) -> Int {
        switch filter {
        case .skippedSessions:
            return sessions.filter { $0.status == .skipped }.count
        case .activeToday:
            return sessions.filter { 
                $0.goal?.status != .archived && 
                $0.status != .skipped && 
                ($0.dailyTarget > 0 || $0.isActiveGoal)
            }.count
        case .theme(let goalTheme):
            return sessions.filter {
                $0.goal?.primaryTag?.themeID == goalTheme.themeID &&
                $0.goal?.status != .archived &&
                $0.status != .skipped &&
                ($0.dailyTarget > 0 || $0.isActiveGoal)
            }.count
        case .completedToday:
            return sessions.filter { $0.hasMetDailyTarget && $0.dailyTarget > 0 }.count
        case .inactive:
            // Only truly inactive goals: no schedule or no weekly target
            return sessions.filter { 
                $0.dailyTarget == 0 && !$0.isActiveGoal
            }.count
        }
    }
    
    /// Filter sessions and sort appropriately
    /// - Parameters:
    ///   - sessions: All sessions to filter
    ///   - filter: The filter to apply
    ///   - validationCheck: Closure to check if a session's goal is still valid
    ///   - weatherManager: Optional weather manager for weather-based filtering
    /// - Returns: Filtered and sorted sessions
    static func filter(
        _ sessions: [GoalSession],
        by filter: ContentView.Filter,
        validationCheck: (GoalSession) -> Bool,
        weatherManager: WeatherManager? = nil
    ) -> [GoalSession] {
        let filtered = sessions.filter { session in
            // Check if not deleted first, before accessing any properties
            guard (try? session.persistentModelID) != nil else {
                return false
            }
            
            // Filter out sessions with deleted goals
            guard validationCheck(session) else {
                return false
            }
            
            // Apply weather filtering if enabled for this goal
            if let weatherManager = weatherManager, let goal = session.goal, goal.hasWeatherTriggers {
                // If goal has weather triggers but they're not met, filter it out
                guard meetsWeatherRequirements(goal, weatherManager: weatherManager) else {
                    return false
                }
            }
            
            // Safely access status properties that might be faults
            let isArchived: Bool
            let isSkipped: Bool
            
            do {
                isArchived = session.goal?.status == .archived
                isSkipped = session.status == .skipped
            } catch {
                // If we can't access the status, assume it's not valid
                return false
            }
            
            switch filter {
            case .activeToday:
                // Show in Today if:
                // 1. Not archived or skipped
                // 2. Has a daily target OR is an active goal with a schedule (may show in Available section)
                // 3. Not completed with "move to completed" behavior
                let shouldHideWhenComplete = session.hasMetDailyTarget && 
                                            session.goal?.completionBehaviors.contains(.moveToCompleted) == true
                return !isArchived && !isSkipped && !shouldHideWhenComplete && (session.dailyTarget > 0 || session.isActiveGoal)
            case .skippedSessions:
                return isSkipped
            case .theme(let goalTheme):
                // Same logic as activeToday for theme filters
                let shouldHideWhenComplete = session.hasMetDailyTarget && 
                                            session.goal?.completionBehaviors.contains(.moveToCompleted) == true
                return session.goal?.primaryTag?.themeID == goalTheme.themeID && !isArchived && !isSkipped && !shouldHideWhenComplete && (session.dailyTarget > 0 || session.isActiveGoal)
            case .completedToday:
                return session.hasMetDailyTarget && session.dailyTarget > 0
            case .inactive:
                // Only truly inactive goals: no schedule or no weekly target
                return session.dailyTarget == 0 && !session.isActiveGoal
            }
        }
        
        // Sort by planned start time if available, otherwise by goal title
        return filtered.sorted { session1, session2 in
            // First, prioritize sessions with planned times
            let has1 = session1.plannedStartTime != nil
            let has2 = session2.plannedStartTime != nil
            
            if has1 && has2 {
                // Both have planned times - sort by time
                return session1.plannedStartTime! < session2.plannedStartTime!
            } else if has1 {
                // Only session1 has a planned time - it comes first
                return true
            } else if has2 {
                // Only session2 has a planned time - it comes first
                return false
            } else {
                // Neither has a planned time - sort by goal title
                return (session1.goal?.title ?? "") < (session2.goal?.title ?? "")
            }
        }
    }
    
    /// Get top 3 recommended sessions based on planning and scoring
    /// - Parameters:
    ///   - sessions: All sessions to consider
    ///   - filter: Active filter
    ///   - planner: Goal session planner for scoring
    ///   - preferences: Planner preferences
    ///   - validationCheck: Closure to check if a session's goal is still valid
    /// - Returns: Up to 3 recommended sessions
    static func getRecommendedSessions(
        from sessions: [GoalSession],
        filter: ContentView.Filter,
        planner: GoalSessionPlanner,
        preferences: PlannerPreferences,
        validationCheck: (GoalSession) -> Bool,
        weatherManager: WeatherManager? = nil
    ) -> [GoalSession] {
        // Filter out deleted/invalid sessions first
        let validSessions = sessions.filter { (try? $0.persistentModelID) != nil }
        let filtered = self.filter(validSessions, by: filter, validationCheck: validationCheck, weatherManager: weatherManager)
        
        // During planning or if we have planned sessions, show top 3 with planning details as recommended
        let plannedSessions = filtered
            .filter { $0.plannedStartTime != nil && !$0.recommendationReasons.isEmpty }
            .sorted { ($0.plannedStartTime ?? Date.distantFuture) < ($1.plannedStartTime ?? Date.distantFuture) }
        
        if !plannedSessions.isEmpty {
            return Array(plannedSessions.prefix(3))
        }
        
        // Fallback: try to get AI-generated recommendations from the daily plan
        if let aiRecommendations = planner.getRecommendedSessionsFromPlan(allSessions: filtered),
           !aiRecommendations.isEmpty {
            // Use AI recommendations - filter to only show ones with recommendation reasons
            let recommendationsWithReasons = aiRecommendations.filter { !$0.recommendationReasons.isEmpty }
            
            if !recommendationsWithReasons.isEmpty {
                return Array(recommendationsWithReasons.prefix(3))
            }
        }
        
        // Only show fallback recommendations if we have enough sessions
        guard sessions.count > 4 else {
            return []
        }
        
        // Fallback: Use scoring algorithm (soft refresh)
        let scored = filtered.compactMap { session -> (GoalSession, Double)? in
            guard validationCheck(session), let goal = session.goal else { return nil }
            
            let score = planner.scoreSession(
                for: goal,
                session: session,
                at: Date(),
                preferences: preferences
            )
            return (session, score)
        }
        
        // Sort by score and take top 3
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }
    }
    
    /// Build available filters from tags and sessions
    /// - Parameters:
    ///   - tags: Available goal tags
    ///   - sessions: All sessions
    /// - Returns: Array of available filters
    static func buildAvailableFilters(
        from tags: [GoalTag],
        sessions: [GoalSession]
    ) -> [ContentView.Filter] {
        var filters: [ContentView.Filter] = [.activeToday]
        
        // Only add completed filter if there are completed sessions
        let completedCount = count(sessions, for: .completedToday)
        if completedCount > 0 {
            filters.append(.completedToday)
        }
        
        // Only add skipped filter if there are skipped sessions
        let skippedCount = count(sessions, for: .skippedSessions)
        if skippedCount > 0 {
            filters.append(.skippedSessions)
        }
        
        // Only add inactive filter if there are inactive sessions
        let inactiveCount = count(sessions, for: .inactive)
        if inactiveCount > 0 {
            filters.append(.inactive)
        }
        
        // Add theme filters for unique themes
        var uniqueThemes: [GoalTag] = []
        var seenIDs: Set<String> = []
        
        for tag in tags {
            let themeID = tag.themeID
            if !seenIDs.contains(themeID) {
                uniqueThemes.append(tag)
                seenIDs.insert(themeID)
            }
        }
        
        let themeFilters = uniqueThemes.map { ContentView.Filter.theme($0) }
        filters.append(contentsOf: themeFilters)
        
        return filters
    }
    
    // MARK: - Weather Filtering
    
    /// Check if a goal's weather requirements are met
    /// - Parameters:
    ///   - goal: The goal to check
    ///   - weatherManager: Weather manager with current conditions
    /// - Returns: True if weather requirements are met or not enabled
    static func meetsWeatherRequirements(_ goal: Goal, weatherManager: WeatherManager) -> Bool {
        // If weather triggers aren't enabled, always show the goal
        guard goal.weatherEnabled || goal.primaryTag?.isSmart == true else {
            return true
        }
        
        // Check weather conditions
        if let conditions = goal.effectiveWeatherConditions, !conditions.isEmpty {
            guard weatherManager.matchesAnyCondition(conditions) else {
                return false
            }
        }
        
        // Check minimum temperature
        if let minTemp = goal.effectiveMinTemperature {
            guard weatherManager.temperatureAbove(minTemp) else {
                return false
            }
        }
        
        // Check maximum temperature
        if let maxTemp = goal.effectiveMaxTemperature {
            guard weatherManager.temperatureBelow(maxTemp) else {
                return false
            }
        }
        
        return true
    }
}
