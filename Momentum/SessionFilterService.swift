//
//  SessionFilterService.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import Foundation
import MomentumKit
import SwiftData

    /// Describes why a session was downranked (not suitable right now but still visible)
    enum DownrankReason: Equatable {
        /// Weather triggers are not met (e.g., "Sunny expected, currently Rainy")
        case weatherMismatch
        /// Goal is not scheduled for today (e.g., "Scheduled Mon, Wed, Fri")
        case notScheduledToday
    }
    
    /// A session that was downranked along with its reason
    struct DownrankedSession {
        let session: GoalSession
        let reason: DownrankReason
    }
    
    /// Result of filtering that separates active from downranked sessions
    struct FilterResult {
        let active: [GoalSession]
        let downranked: [DownrankedSession]
    }

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
        filterActiveSessionsWithDownranked(sessions, validationCheck: validationCheck, weatherManager: weatherManager).active
    }
    
    /// Filter sessions and separate downranked ones (weather mismatch, not scheduled today)
    /// instead of silently dropping them.
    static func filterActiveSessionsWithDownranked(
        _ sessions: [GoalSession],
        validationCheck: (GoalSession) -> Bool,
        weatherManager: (any WeatherProviding)? = nil
    ) -> FilterResult {
        var active: [GoalSession] = []
        var downranked: [DownrankedSession] = []
        
        for session in sessions {
            // Check if not deleted first, before accessing any properties
            guard (try? session.persistentModelID) != nil else { continue }
            
            // Filter out sessions with deleted goals
            guard validationCheck(session) else { continue }
            
            // Safely access status properties
            let isArchived = session.goal?.status == .archived
            let isSkipped = session.status == .skipped
            guard !isArchived && !isSkipped else { continue }
            
            // Must have a daily target or be an active goal
            guard session.unifiedTargetValue > 0 || session.isActiveGoal else { continue }
            
            // Day availability check (relevance rule)
            if let goal = session.goal, goal.hasRelevanceRule {
                let calendar = Calendar.current
                let todayWeekday = calendar.component(.weekday, from: Date())
                let availability = goal.dayAvailability(for: todayWeekday)
                
                if availability == .never {
                    // Hard block — skip entirely
                    continue
                }
                
                if availability == .open {
                    // Open days: only surface if a signal matches
                    let hasMatchingSignal = hasAnyMatchingSignal(goal, weatherManager: weatherManager)
                    if !hasMatchingSignal {
                        downranked.append(DownrankedSession(session: session, reason: .notScheduledToday))
                        continue
                    }
                }
            }
            
            // Weather check: respect signal strength
            if let weatherManager = weatherManager, let goal = session.goal, goal.hasWeatherTriggers {
                let weatherStrength = goal.signalStrength(for: .weather)
                let weatherMatches = meetsWeatherRequirements(goal, weatherManager: weatherManager)
                
                if weatherStrength == .avoid && weatherMatches {
                    // Avoid: downrank when weather *does* match
                    downranked.append(DownrankedSession(session: session, reason: .weatherMismatch))
                    continue
                } else if !weatherMatches && weatherStrength == .require {
                    // Require: downrank when weather does *not* match
                    downranked.append(DownrankedSession(session: session, reason: .weatherMismatch))
                    continue
                }
                // .boost: don't filter — just let the score be lower
            }
            
            active.append(session)
        }
        
        // Sort active by planned start time, then title
        active.sort { s1, s2 in
            let has1 = s1.plannedStartTime != nil
            let has2 = s2.plannedStartTime != nil
            
            if has1 && has2 {
                return s1.plannedStartTime! < s2.plannedStartTime!
            } else if has1 {
                return true
            } else if has2 {
                return false
            } else {
                return (s1.goal?.title ?? "") < (s2.goal?.title ?? "")
            }
        }
        
        return FilterResult(active: active, downranked: downranked)
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
            .filter { $0.plannedStartTime != nil && !$0.safeRecommendationReasons.isEmpty }
            .sorted { ($0.plannedStartTime ?? Date.distantFuture) < ($1.plannedStartTime ?? Date.distantFuture) }
        
        if !plannedSessions.isEmpty {
            return Array(plannedSessions.prefix(3))
        }
        
        // Fallback: try to get AI-generated recommendations from the daily plan
        if let aiRecommendations = planner.getRecommendedSessionsFromPlan(allSessions: incomplete),
           !aiRecommendations.isEmpty {
            // Use AI recommendations - filter to only show ones with recommendation reasons
            let recommendationsWithReasons = aiRecommendations.filter { !$0.safeRecommendationReasons.isEmpty }
            
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
        
        for session in top where session.safeRecommendationReasons.isEmpty {
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
    /// Check if any configured signal currently matches for an open day.
    static func hasAnyMatchingSignal(_ goal: Goal, weatherManager: (any WeatherProviding)? = nil) -> Bool {
        // Time of day check
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let currentTimeOfDay = TimeOfDay.from(hour: hour)
        let todayWeekday = calendar.component(.weekday, from: Date())
        let scheduledTimes = goal.timesForWeekday(todayWeekday)
        if !scheduledTimes.isEmpty && scheduledTimes.contains(currentTimeOfDay) {
            return true
        }
        
        // Weather check
        if let weatherManager = weatherManager, goal.hasWeatherTriggers {
            if meetsWeatherRequirements(goal, weatherManager: weatherManager) {
                return true
            }
        }
        
        // Tag context check
        if let tag = goal.primaryTag, tag.isSmart {
            let score = tag.contextMatchScore(
                weather: nil,
                temperature: nil,
                timeOfDay: currentTimeOfDay,
                location: nil
            )
            if score >= 0.8 {
                return true
            }
        }
        
        return false
    }
    
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
