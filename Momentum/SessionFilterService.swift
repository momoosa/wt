//
//  SessionFilterService.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import Foundation
import MomentumKit
import SwiftData

/// Service for filtering and scoring goal sessions
struct SessionFilterService {
    
    /// Filter sessions for active-today display and sort appropriately
    /// - Parameters:
    ///   - sessions: All sessions to filter
    ///   - validationCheck: Closure to check if a session's goal is still valid
    ///   - weatherManager: Optional weather manager for weather-based filtering
    /// - Returns: Filtered and sorted sessions
    static func filterActiveSessions(
        _ sessions: [GoalSession],
        validationCheck: (GoalSession) -> Bool,
        weatherManager: (any WeatherProviding)? = nil
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
            
            // Active today: not archived, not skipped, has a daily target or is an active goal
            return !isArchived && !isSkipped && (session.unifiedTargetValue > 0 || session.isActiveGoal)
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
    ///   - planner: Goal session planner for scoring
    ///   - preferences: Planner preferences
    ///   - validationCheck: Closure to check if a session's goal is still valid
    /// - Returns: Up to 3 recommended sessions
    static func getRecommendedSessions(
        from sessions: [GoalSession],
        planner: GoalSessionPlanner,
        preferences: PlannerPreferences,
        validationCheck: (GoalSession) -> Bool,
        weatherManager: (any WeatherProviding)? = nil
    ) -> [GoalSession] {
        let filtered = filterActiveSessions(sessions, validationCheck: validationCheck, weatherManager: weatherManager)
        
        // Exclude sessions that have significantly exceeded their daily target (>= 100% complete)
        // These shouldn't be recommended — the user has already done enough for today
        let incomplete = filtered.filter { !$0.hasMetDailyTarget }
        
        // During planning or if we have planned sessions, show top 3 with planning details as recommended
        let plannedSessions = incomplete
            .filter { $0.plannedStartTime != nil && !$0.recommendationReasons.isEmpty }
            .sorted { ($0.plannedStartTime ?? Date.distantFuture) < ($1.plannedStartTime ?? Date.distantFuture) }
        
        if !plannedSessions.isEmpty {
            return Array(plannedSessions.prefix(3))
        }
        
        // Fallback: try to get AI-generated recommendations from the daily plan
        if let aiRecommendations = planner.getRecommendedSessionsFromPlan(allSessions: incomplete),
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
        let now = Date()
        let scored = incomplete.compactMap { session -> (GoalSession, Double)? in
            guard validationCheck(session), let goal = session.goal else { return nil }
            
            let score = planner.scoreSession(
                for: goal,
                session: session,
                at: now,
                preferences: preferences
            )
            return (session, score)
        }
        
        // Sort by score and take top 3, then populate missing reasons
        let top = scored
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }
        
        for session in top where session.recommendationReasons.isEmpty {
            if let goal = session.goal {
                session.recommendationReasons = Self.basicReasons(for: session, goal: goal, at: now, weatherManager: weatherManager)
            }
        }
        
        return top
    }
    
    // MARK: - Basic Recommendation Reasons
    
    /// Generate basic recommendation reasons for fallback-scored sessions
    static func basicReasons(
        for session: GoalSession,
        goal: Goal,
        at date: Date = Date(),
        weatherManager: (any WeatherProviding)? = nil
    ) -> [RecommendationReason] {
        var reasons: [RecommendationReason] = []
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentWeekday = calendar.component(.weekday, from: date)
        
        // Quick Finish — less than 25% remaining
        let target = session.unifiedTargetValue
        let current = session.currentValue
        let remaining = target - current
        if remaining > 0 && remaining < target * 0.25 {
            reasons.append(.quickFinish)
        }
        
        // Weekly Progress — behind and past midweek
        if current < target * 0.5 && currentWeekday >= 4 {
            reasons.append(.weeklyProgress)
        }
        
        // Preferred Time — matches goal's time-of-day preference
        let preferredTimes = goal.timesForWeekday(currentWeekday)
        if !preferredTimes.isEmpty {
            let matches = preferredTimes.contains { tod in
                switch tod {
                case .morning: return currentHour >= 6 && currentHour < 10
                case .midday: return currentHour >= 10 && currentHour < 14
                case .afternoon: return currentHour >= 14 && currentHour < 18
                case .evening: return currentHour >= 18 && currentHour < 22
                case .night: return currentHour >= 22 || currentHour < 6
                }
            }
            if matches { reasons.append(.preferredTime) }
        }
        
        // Weather — goal has weather conditions and they match
        if let wm = weatherManager,
           let conditions = goal.effectiveWeatherConditions,
           !conditions.isEmpty,
           wm.matchesAnyCondition(conditions) {
            reasons.append(.weather)
        }
        
        // Energy Level — morning or early afternoon
        if (6...9).contains(currentHour) || (13...15).contains(currentHour) {
            reasons.append(.energyLevel)
        }
        
        return reasons
    }
    
    // MARK: - Weather Filtering
    
    /// Check if a goal's weather requirements are met
    /// - Parameters:
    ///   - goal: The goal to check
    ///   - weatherManager: Weather manager with current conditions
    /// - Returns: True if weather requirements are met or not enabled
    static func meetsWeatherRequirements(_ goal: Goal, weatherManager: any WeatherProviding) -> Bool {
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
