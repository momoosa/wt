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
    
    /// Result of filtering that separates active, downranked, and skipped sessions
    struct FilterResult {
        let active: [GoalSession]
        let downranked: [DownrankedSession]
        let skipped: [GoalSession]
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
        var skipped: [GoalSession] = []
        
        for session in sessions {
            // Check if not deleted first, before accessing any properties
            guard (try? session.persistentModelID) != nil else { continue }
            
            // Filter out sessions with deleted goals
            guard validationCheck(session) else { continue }
            
            // Safely access status properties
            let isArchived = session.goal?.status == .archived
            guard !isArchived else { continue }
            
            if session.status == .skipped {
                skipped.append(session)
                continue
            }
            
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
                    // Open days: only surface if signals match (respecting match mode)
                    let signalsMatch = checkSignals(goal, weatherManager: weatherManager)
                    if !signalsMatch {
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
        
        return FilterResult(active: active, downranked: downranked, skipped: skipped)
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
        
        // Defer the mutation to avoid writing SwiftData properties during
        // a SwiftUI view update (causes AttributeGraph precondition failure).
        let sessionsNeedingReasons = top.compactMap { session -> (GoalSession, Goal)? in
            guard session.safeRecommendationReasons.isEmpty, let goal = session.goal else { return nil }
            return (session, goal)
        }
        if !sessionsNeedingReasons.isEmpty {
            let weatherMgr = weatherManager
            DispatchQueue.main.async {
                for (session, goal) in sessionsNeedingReasons {
                    session.recommendationReasons = Self.basicReasons(for: session, goal: goal, at: now, weatherManager: weatherMgr)
                }
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
        
        return reasons
    }
    
    // MARK: - Weather Filtering
    
    /// Check if signals match for an open day, respecting the goal's match mode.
    /// - Match ANY: at least one configured signal must match (default).
    /// - Match ALL: every configured signal must match.
    static func checkSignals(_ goal: Goal, weatherManager: (any WeatherProviding)? = nil) -> Bool {
        if goal.conditionMatchMode == .all {
            return hasAllMatchingSignals(goal, weatherManager: weatherManager)
        }
        return hasAnyMatchingSignal(goal, weatherManager: weatherManager)
    }
    
    /// Check that every configured signal currently matches.
    static func hasAllMatchingSignals(_ goal: Goal, weatherManager: (any WeatherProviding)? = nil) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let currentTimeOfDay = TimeOfDay.from(hour: hour)
        let todayWeekday = calendar.component(.weekday, from: Date())
        
        var configuredCount = 0
        
        // Time of day check
        let scheduledTimes = goal.timesForWeekday(todayWeekday)
        if !scheduledTimes.isEmpty {
            configuredCount += 1
            if !scheduledTimes.contains(currentTimeOfDay) { return false }
        }
        
        // Weather check
        if goal.hasWeatherTriggers, let weatherManager {
            configuredCount += 1
            if !meetsWeatherRequirements(goal, weatherManager: weatherManager) { return false }
        }
        
        // Tag context check
        if let tag = goal.primaryTag, tag.isSmart {
            configuredCount += 1
            let score = tag.contextMatchScore(weather: nil, temperature: nil, timeOfDay: currentTimeOfDay, location: nil)
            if score < 0.8 { return false }
        }
        
        // Must have at least one configured signal to pass
        return configuredCount > 0
    }
    
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
        
        // Check maximum wind speed
        if let maxWind = goal.effectiveMaxWindSpeed {
            guard weatherManager.windSpeedBelow(maxWind) else {
                return false
            }
        }
        
        return true
    }
}
