//
//  DeterministicRecommender.swift
//  MomentumKit
//
//  Created by Assistant on 19/03/2026.
//

import Foundation

/// Fast, deterministic goal recommendation engine using rule-based scoring
/// Provides instant recommendations without requiring Foundation Models
public struct DeterministicRecommender {
    
    // MARK: - Context
    
    /// Current context for making recommendations
    public struct Context {
        public let currentDate: Date
        public let weather: WeatherCondition?
        public let temperature: Double?
        public let windSpeed: Double? // km/h
        public let timeOfDay: TimeOfDay?
        public let location: LocationType?
        public let weekdayAvailability: [Int: TimeInterval]? // Weekday (1-7) -> available time in seconds
        
        public init(
            currentDate: Date = Date(),
            weather: WeatherCondition? = nil,
            temperature: Double? = nil,
            windSpeed: Double? = nil,
            timeOfDay: TimeOfDay? = nil,
            location: LocationType? = nil,
            weekdayAvailability: [Int: TimeInterval]? = nil
        ) {
            self.currentDate = currentDate
            self.weather = weather
            self.temperature = temperature
            self.windSpeed = windSpeed
            self.timeOfDay = timeOfDay
            self.location = location
            self.weekdayAvailability = weekdayAvailability
        }
    }
    
    // MARK: - Recommendation Result
    
    /// Result of deterministic recommendation
    public struct Recommendation {
        public let goal: Goal
        public let score: Double
        public let reasons: [RecommendationReason]
        
        public init(goal: Goal, score: Double, reasons: [RecommendationReason]) {
            self.goal = goal
            self.score = score
            self.reasons = reasons
        }
    }
    
    // MARK: - Scoring Weights
    
    /// Configurable weights for different scoring factors
    public struct ScoringWeights: Sendable {
        public let weatherContext: Double
        public let weeklyProgress: Double
        public let timeOfDay: Double
        public let deadline: Double
        public let historicalPattern: Double
        public let scheduleFlexibility: Double
        public let goalSequence: Double
        
        public static let `default` = ScoringWeights(
            weatherContext: 25.0,  // 0-25 points for weather match
            weeklyProgress: 30.0,   // 0-30 points for being behind schedule
            timeOfDay: 20.0,        // 0-20 points for time matching
            deadline: 15.0,         // 0-15 points for approaching deadline
            historicalPattern: 10.0, // 0-10 points for historical usage
            scheduleFlexibility: 25.0, // 0-25 points for schedule conflict urgency
            goalSequence: 20.0      // 0-20 points for goal sequence match
        )
        
        public init(
            weatherContext: Double,
            weeklyProgress: Double,
            timeOfDay: Double,
            deadline: Double,
            historicalPattern: Double,
            scheduleFlexibility: Double,
            goalSequence: Double = 20.0
        ) {
            self.weatherContext = weatherContext
            self.weeklyProgress = weeklyProgress
            self.timeOfDay = timeOfDay
            self.deadline = deadline
            self.historicalPattern = historicalPattern
            self.scheduleFlexibility = scheduleFlexibility
            self.goalSequence = goalSequence
        }
    }
    
    // MARK: - Properties
    
    public let weights: ScoringWeights
    
    public init(weights: ScoringWeights = .default) {
        self.weights = weights
    }
    
    // MARK: - Public API
    
    /// Get top N recommended goals for the current context
    public func recommend(
        goals: [Goal],
        sessions: [GoalSession],
        context: Context,
        limit: Int = 3
    ) -> [Recommendation] {
        // Filter to active goals only
        let activeGoals = goals.filter { $0.status == .active }
        
        // Score each goal
        let scored = activeGoals.map { goal in
            let (score, reasons) = scoreGoal(goal, sessions: sessions, context: context)
            return Recommendation(goal: goal, score: score, reasons: reasons)
        }
        
        // Sort by score descending and take top N
        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Scoring Logic
    
    /// Score a single goal based on current context
    /// Returns (total score, reasons for the score)
    private func scoreGoal(
        _ goal: Goal,
        sessions: [GoalSession],
        context: Context
    ) -> (score: Double, reasons: [RecommendationReason]) {
        var totalScore = 0.0
        var reasons: [RecommendationReason] = []
        
        // --- Signal-based scores (user-configured conditions) ---
        
        // Collect results for each configured signal so we can apply match mode
        var signalResults: [(score: Double, maxScore: Double, reason: RecommendationReason?)] = []
        
        // 1. Weather Context Scoring (0-25 points)
        if goal.hasSignal(.weather) {
            let (s, r) = scoreWeatherContext(goal, context: context)
            signalResults.append((s, weights.weatherContext, r))
        }
        
        // 2. Time of Day Scoring (0-20 points)
        if goal.hasSignal(.timeOfDay) {
            let (s, r) = scoreTimeOfDay(goal, context: context)
            signalResults.append((s, weights.timeOfDay, r))
        }
        
        // 3. Goal Sequence Scoring (0-20 points)
        if goal.sequenceEnabled {
            let (s, r) = scoreGoalSequence(goal, sessions: sessions, context: context)
            signalResults.append((s, weights.goalSequence, r))
        }
        
        // Apply match mode to signal scores
        if goal.conditionMatchMode == .all && !signalResults.isEmpty {
            // Match ALL: all configured signals must contribute positively.
            // If any signal scored near zero, heavily penalize the combined signal score.
            let allMatched = signalResults.allSatisfy { $0.score > $0.maxScore * 0.1 }
            if allMatched {
                // All matched — add full scores and a bonus for complete match
                for result in signalResults {
                    totalScore += result.score
                    if let reason = result.reason { reasons.append(reason) }
                }
                totalScore += 5.0 // bonus for all conditions matching
            } else {
                // At least one signal didn't match — minimal score from signals
                for result in signalResults {
                    totalScore += result.score * 0.1
                }
            }
        } else {
            // Match ANY (default): each signal independently adds its score
            for result in signalResults {
                totalScore += result.score
                if let reason = result.reason { reasons.append(reason) }
            }
        }
        
        // Also score weather for goals without explicit weather signals (tag-based)
        if !goal.hasSignal(.weather) {
            let (weatherScore, weatherReason) = scoreWeatherContext(goal, context: context)
            totalScore += weatherScore
            if let reason = weatherReason { reasons.append(reason) }
        }
        
        // Also score time for goals without explicit time signals
        if !goal.hasSignal(.timeOfDay) {
            let (timeScore, timeReason) = scoreTimeOfDay(goal, context: context)
            totalScore += timeScore
            if let reason = timeReason { reasons.append(reason) }
        }
        
        // --- Always-additive scores (not user-configured conditions) ---
        
        // 4. Weekly Progress Scoring (0-30 points)
        let (progressScore, progressReason) = scoreWeeklyProgress(goal, sessions: sessions, context: context)
        totalScore += progressScore
        if let reason = progressReason {
            reasons.append(reason)
        }
        
        // 5. Deadline/Urgency Scoring (0-15 points)
        let (deadlineScore, deadlineReason) = scoreDeadline(goal, context: context)
        totalScore += deadlineScore
        if let reason = deadlineReason {
            reasons.append(reason)
        }
        
        // 6. Schedule Flexibility Scoring (0-25 points)
        let (flexibilityScore, flexibilityReason) = scoreScheduleFlexibility(goal, context: context)
        totalScore += flexibilityScore
        if let reason = flexibilityReason {
            reasons.append(reason)
        }
        
        return (totalScore, reasons)
    }
    
    // MARK: - Individual Scoring Components
    
    /// Score based on weather context matching
    private func scoreWeatherContext(
        _ goal: Goal,
        context: Context
    ) -> (score: Double, reason: RecommendationReason?) {
        // Use goal-level weather configuration when available (from relevance rules)
        if goal.weatherEnabled, let conditions = goal.weatherConditions, !conditions.isEmpty {
            guard let currentWeather = context.weather else {
                // No weather data available — neutral score
                return (weights.weatherContext * 0.5, nil)
            }
            
            let conditionMatches = conditions.contains(currentWeather.rawValue)
            
            // Check temperature bounds if configured
            var tempMatches = true
            if let minTemp = goal.minTemperature, let temp = context.temperature {
                tempMatches = tempMatches && temp >= minTemp
            }
            if let maxTemp = goal.maxTemperature, let temp = context.temperature {
                tempMatches = tempMatches && temp <= maxTemp
            }
            
            // Check wind speed if configured
            var windMatches = true
            if let maxWind = goal.maxWindSpeed, let wind = context.windSpeed {
                windMatches = wind <= maxWind
            }
            
            if conditionMatches && tempMatches && windMatches {
                return (weights.weatherContext, .weather)
            } else {
                return (0.0, nil)
            }
        }
        
        // Fall back to tag-based weather matching
        guard let tag = goal.primaryTag else {
            // No tag means no weather preference - neutral score
            return (weights.weatherContext * 0.5, nil)
        }
        
        let contextScore = tag.contextMatchScore(
            weather: context.weather,
            temperature: context.temperature,
            windSpeed: context.windSpeed,
            timeOfDay: context.timeOfDay,
            location: context.location
        )
        
        let score = contextScore * weights.weatherContext
        
        // Only add reason if weather significantly contributes
        if contextScore >= 1.0 {
            return (score, .weather)
        } else if contextScore == 0.0 {
            // Penalize goals that don't match context
            return (0.0, nil)
        } else {
            // Neutral context (no requirements)
            return (score, nil)
        }
    }
    
    /// Score based on weekly progress (behind schedule = higher score)
    private func scoreWeeklyProgress(
        _ goal: Goal,
        sessions: [GoalSession],
        context: Context
    ) -> (score: Double, reason: RecommendationReason?) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: context.currentDate)?.start ?? context.currentDate
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? context.currentDate
        
        // Calculate elapsed time in week
        let elapsedTime = context.currentDate.timeIntervalSince(weekStart)
        let weekDuration: TimeInterval = 7 * 24 * 60 * 60
        let weekProgress = elapsedTime / weekDuration
        
        // Expected progress at this point
        let expectedProgress = goal.unifiedWeeklyTarget * weekProgress
        
        // Calculate actual progress from sessions in the current week
        let actualProgress = sessions
            .filter { session in
                session.goalID == goal.id.uuidString &&
                session.day?.startDate ?? .distantPast >= weekStart &&
                session.day?.startDate ?? .distantPast < weekEnd
            }
            .reduce(0.0) { $0 + $1.currentValue }
        
        let deficit = expectedProgress - actualProgress
        
        if deficit > 0 {
            // Behind schedule - scale score based on deficit
            let deficitPercentage = min(1.0, deficit / goal.unifiedWeeklyTarget)
            let score = deficitPercentage * weights.weeklyProgress
            
            if deficitPercentage > 0.3 {
                return (score, .weeklyProgress)
            }
            return (score, nil)
        }
        
        // Ahead or on schedule - lower priority
        return (weights.weeklyProgress * 0.2, nil)
    }
    
    /// Score based on time of day preferences
    private func scoreTimeOfDay(
        _ goal: Goal,
        context: Context
    ) -> (score: Double, reason: RecommendationReason?) {
        guard let timeOfDay = context.timeOfDay else {
            return (weights.timeOfDay * 0.5, nil)
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: context.currentDate)
        let preferredTimes = goal.timesForWeekday(weekday)
        
        if preferredTimes.isEmpty {
            // No preference - neutral score
            return (weights.timeOfDay * 0.5, nil)
        }
        
        let matches = preferredTimes.contains(timeOfDay)
        if matches {
            return (weights.timeOfDay, .preferredTime)
        } else {
            // Wrong time of day - low score
            return (weights.timeOfDay * 0.1, nil)
        }
    }
    
    /// Score based on approaching deadlines or constraints
    private func scoreDeadline(
        _ goal: Goal,
        context: Context
    ) -> (score: Double, reason: RecommendationReason?) {
        // Check if goal is only available during certain times
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: context.currentDate)
        let preferredTimes = goal.timesForWeekday(weekday)
        
        // If goal has time constraints and we're in one of them, boost priority
        if !preferredTimes.isEmpty, let timeOfDay = context.timeOfDay {
            if preferredTimes.contains(timeOfDay) {
                // Check if this is the last available time slot today
                let currentHour = calendar.component(.hour, from: context.currentDate)
                let isLateInTimeSlot = isLateInTimeSlot(currentHour, for: timeOfDay)
                
                if isLateInTimeSlot {
                    return (weights.deadline, .constrained)
                }
            }
        }
        
        // Check for weekly target approaching end of week
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: context.currentDate)?.start ?? context.currentDate
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? context.currentDate
        let remainingTime = weekEnd.timeIntervalSince(context.currentDate)
        let weekDuration: TimeInterval = 7 * 24 * 60 * 60
        
        if remainingTime < weekDuration * 0.2 { // Less than 20% of week remains
            return (weights.deadline * 0.7, nil)
        }
        
        return (0.0, nil)
    }
    
    /// Check if we're late in a time slot (last 30 minutes)
    private func isLateInTimeSlot(_ currentHour: Int, for timeOfDay: TimeOfDay) -> Bool {
        switch timeOfDay {
        case .morning: return currentHour >= 9    // 6-10, late at 9+
        case .midday: return currentHour >= 13    // 10-14, late at 13+
        case .afternoon: return currentHour >= 16 // 14-17, late at 16+
        case .evening: return currentHour >= 20   // 17-21, late at 20+
        case .night: return currentHour >= 23     // 21-6, late at 23+
        }
    }
    
    /// Score based on schedule conflicts and flexibility needs
    /// When scheduled days are unavailable, boost score on alternative days
    private func scoreScheduleFlexibility(
        _ goal: Goal,
        context: Context
    ) -> (score: Double, reason: RecommendationReason?) {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: context.currentDate)
        
        // New relevance rule system: factor in DayAvailability
        if goal.hasRelevanceRule {
            let availability = goal.dayAvailability(for: currentWeekday)
            switch availability {
            case .preferred:
                // Full schedule score — proceed with existing logic below
                break
            case .open:
                // Reduced score for open days — surfaceable but not prioritized
                return (weights.scheduleFlexibility * 0.4, nil)
            case .never:
                // Should have been filtered already, but ensure 0
                return (0.0, nil)
            }
        }
        
        // Only relevant if we have availability data and goal has a schedule
        guard let availability = context.weekdayAvailability,
              goal.hasSchedule else {
            return (0.0, nil)
        }
        
        let scheduledWeekdays = goal.scheduledWeekdays
        
        // Check if today is a scheduled day
        let isTodayScheduled = scheduledWeekdays.contains(currentWeekday)
        
        if isTodayScheduled {
            // Today is a scheduled day - check if we have time
            let todayAvailability = availability[currentWeekday] ?? 0
            
            if todayAvailability < 1800 { // Less than 30 minutes available
                // Scheduled day but no time - penalize slightly
                return (weights.scheduleFlexibility * 0.3, nil)
            }
            
            // Scheduled day with time available - neutral
            return (0.0, nil)
        }
        
        // Today is NOT a scheduled day - check if scheduled days are unavailable
        let scheduledDaysAvailability = scheduledWeekdays.compactMap { availability[$0] }
        
        if scheduledDaysAvailability.isEmpty {
            // No availability data for scheduled days - neutral
            return (0.0, nil)
        }
        
        // Calculate average availability on scheduled days
        let avgScheduledAvailability = scheduledDaysAvailability.reduce(0.0, +) / Double(scheduledDaysAvailability.count)
        let todayAvailability = availability[currentWeekday] ?? 0
        
        // If scheduled days have low availability (<30 min) and today has good availability (>1 hour)
        if avgScheduledAvailability < 1800 && todayAvailability > 3600 {
            // High urgency - scheduled days are blocked but need to make progress
            return (weights.scheduleFlexibility, .constrained)
        }
        
        // If scheduled days have limited availability (<2 hours) and today has decent time (>30 min)
        if avgScheduledAvailability < 7200 && todayAvailability > 1800 {
            // Moderate urgency - suggest doing some work today since scheduled days are busy
            return (weights.scheduleFlexibility * 0.6, .constrained)
        }
        
        // Scheduled days have adequate time - don't recommend on off days
        if todayAvailability < 1800 {
            // Today is not scheduled and has little time - penalize
            return (weights.scheduleFlexibility * 0.1, nil)
        }
        
        return (0.0, nil)
    }
    
    /// Score based on goal sequence link (before/after another goal)
    private func scoreGoalSequence(
        _ goal: Goal,
        sessions: [GoalSession],
        context: Context
    ) -> (score: Double, reason: RecommendationReason?) {
        guard goal.sequenceEnabled,
              let linkedGoalID = goal.sequenceGoalID,
              let direction = goal.sequenceDirection else {
            return (0.0, nil)
        }
        
        // Find today's session for the linked goal
        let linkedSession = sessions.first { $0.goalID == linkedGoalID }
        
        switch direction {
        case "after":
            // Boost if the linked goal has been completed today
            if let session = linkedSession, session.hasMetDailyTarget {
                return (weights.goalSequence, .goalSequence)
            }
            // Slight boost if the linked goal is in progress (partially done)
            if let session = linkedSession, session.currentValue > 0 {
                return (weights.goalSequence * 0.3, nil)
            }
            return (0.0, nil)
            
        case "before":
            // Boost if the linked goal has NOT started yet today
            if let session = linkedSession, session.currentValue == 0 && !session.hasMetDailyTarget {
                return (weights.goalSequence, .goalSequence)
            }
            // No linked session today means it hasn't been done — boost
            if linkedSession == nil {
                return (weights.goalSequence * 0.8, .goalSequence)
            }
            return (0.0, nil)
            
        default:
            return (0.0, nil)
        }
    }
}
