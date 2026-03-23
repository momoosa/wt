//
//  GoalSessionPlanner.swift
//  MomentumKit
//
//  Created by Mo Moosa on 17/01/2026.
//

import Foundation
import FoundationModels
import SwiftData
import MomentumKit
import Combine

// MARK: - Planned Session Model

/// Represents an AI-generated plan for a goal session
@Generable
public struct PlannedSession: Codable, Identifiable {
    public var id: String // Goal ID
    public var goalTitle: String
    public var recommendedStartTime: String // ISO 8601 time component (HH:mm)
    public var suggestedDuration: Int // in minutes
    public var priority: Int // 1 (highest) to 5 (lowest)
    public var reasoning: String // Why this session is scheduled at this time
    
    public init(id: String, goalTitle: String, recommendedStartTime: String, suggestedDuration: Int, priority: Int, reasoning: String) {
        self.id = id
        self.goalTitle = goalTitle
        self.recommendedStartTime = recommendedStartTime
        self.suggestedDuration = suggestedDuration
        self.priority = priority
        self.reasoning = reasoning
    }
}

/// Container for the daily plan
@Generable
public struct DailyPlan: Codable {
    public var sessions: [PlannedSession]
    public var overallStrategy: String? // High-level planning insight
    public var topThreeRecommendations: [String]? // Top 3 goal IDs to do right now
    public var recommendationReasoning: String? // Why these 3 are recommended now
    
    public init(sessions: [PlannedSession], overallStrategy: String? = nil, topThreeRecommendations: [String]? = nil, recommendationReasoning: String? = nil) {
        self.sessions = sessions
        self.overallStrategy = overallStrategy
        self.topThreeRecommendations = topThreeRecommendations
        self.recommendationReasoning = recommendationReasoning
    }
}

// MARK: - Goal Session Planner

/// AI-powered planner that creates optimized daily schedules for goal sessions
@MainActor
public class GoalSessionPlanner: ObservableObject {
    @Published public var currentPlan: DailyPlan?
    @Published public var isGenerating: Bool = false
    @Published public var lastError: Error?
    
    private let session = LanguageModelSession()
    
    // Cache to avoid regenerating same plan repeatedly
    private var cachedPlanDate: Date? // The date for which the plan was generated
    private var cachedPlanTimestamp: Date? // When the plan was cached
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // Deterministic recommender for fast recommendations
    private let recommender = DeterministicRecommender()
    
    // Calendar availability calculator (set externally if needed)
    public var availabilityCalculator: (() async -> [Int: TimeInterval])?
    
    public init() {}
    
    /// Prewarm the language model to reduce initial latency
    public func prewarm() async {
        try? await session.prewarm()
    }
    
    /// Get fast recommendations using deterministic scoring with automatic calendar availability
    /// Returns immediately with top 3 recommended goals based on context
    /// - Parameters:
    ///   - includeCalendarAvailability: If true, fetches calendar events to calculate availability
    public func getQuickRecommendationsWithCalendar(
        for goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date = Date(),
        weather: WeatherCondition? = nil,
        temperature: Double? = nil,
        includeCalendarAvailability: Bool = true
    ) async -> (goalIDs: [String], reasons: [String]) {
        var weekdayAvailability: [Int: TimeInterval]? = nil
        
        if includeCalendarAvailability, let calculator = availabilityCalculator {
            weekdayAvailability = await calculator()
        }
        
        return getQuickRecommendations(
            for: goals,
            goalSessions: goalSessions,
            currentDate: currentDate,
            weather: weather,
            temperature: temperature,
            weekdayAvailability: weekdayAvailability
        )
    }
    
    /// Get fast recommendations using deterministic scoring (no AI required)
    /// Returns immediately with top 3 recommended goals based on context
    /// - Parameters:
    ///   - weekdayAvailability: Optional map of weekday (1-7) to available seconds
    ///     Use this to factor in calendar conflicts and schedule flexibility
    public func getQuickRecommendations(
        for goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date = Date(),
        weather: WeatherCondition? = nil,
        temperature: Double? = nil,
        weekdayAvailability: [Int: TimeInterval]? = nil
    ) -> (goalIDs: [String], reasons: [String]) {
        // Determine time of day
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentDate)
        let timeOfDay = TimeOfDay.from(hour: hour)
        
        // Create context for recommendations
        let context = DeterministicRecommender.Context(
            currentDate: currentDate,
            weather: weather,
            temperature: temperature,
            timeOfDay: timeOfDay,
            location: nil,
            weekdayAvailability: weekdayAvailability
        )
        
        // Get recommendations
        let recommendations = recommender.recommend(
            goals: goals,
            sessions: goalSessions,
            context: context,
            limit: 3
        )
        
        // Extract goal IDs and reasons
        let goalIDs = recommendations.map { $0.goal.id.uuidString }
        let reasons = recommendations.map { rec in
            var reasonParts: [String] = []
            if rec.reasons.contains(.weather) {
                reasonParts.append("weather-optimal")
            }
            if rec.reasons.contains(.preferredTime) {
                reasonParts.append("preferred time")
            }
            if rec.reasons.contains(.weeklyProgress) {
                reasonParts.append("behind schedule")
            }
            if rec.reasons.contains(.constrained) {
                // Check if this is due to schedule flexibility
                let goal = rec.goal
                if goal.hasSchedule {
                    let scheduledDays = goal.scheduledWeekdays
                    let currentWeekday = calendar.component(.weekday, from: currentDate)
                    if !scheduledDays.contains(currentWeekday) {
                        reasonParts.append("scheduled days are busy")
                    } else {
                        reasonParts.append("limited availability")
                    }
                } else {
                    reasonParts.append("limited availability")
                }
            }
            
            return reasonParts.isEmpty ? "Good time to work on this" : reasonParts.joined(separator: ", ")
        }
        
        return (goalIDs, reasons)
    }
    
    /// Generate a daily plan for the given goals and context
    public func generateDailyPlan(
        for goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date = Date(),
        userPreferences: PlannerPreferences = .default
    ) async throws -> DailyPlan {
        // Check cache first - avoid regenerating if plan is still fresh and for the same date
        if let cachedTimestamp = cachedPlanTimestamp,
           let cachedDate = cachedPlanDate,
           let currentPlan = currentPlan,
           Calendar.current.isDate(cachedDate, inSameDayAs: currentDate),
           Date.now.timeIntervalSince(cachedTimestamp) < cacheValidityDuration {
            print("⚡ Using cached plan (age: \(Int(Date.now.timeIntervalSince(cachedTimestamp)))s)")
            return currentPlan
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        // Pre-filter goals to reduce Foundation Model workload
        let eligibleGoals = preFilterGoalsForPlanning(
            goals: goals,
            goalSessions: goalSessions,
            currentDate: currentDate
        )
        
        // Early bailout: If no eligible goals, return empty plan immediately
        if eligibleGoals.isEmpty {
            let emptyPlan = DailyPlan(
                sessions: [],
                overallStrategy: "No goals are eligible for planning at this time.",
                topThreeRecommendations: [],
                recommendationReasoning: "All goals are either completed, archived, or not scheduled for the current time."
            )
            currentPlan = emptyPlan
            cachedPlanDate = currentDate
            cachedPlanTimestamp = Date.now
            return emptyPlan
        }
        
        // Early bailout: If only 1-2 goals, skip AI and create simple plan
        if eligibleGoals.count <= 2 {
            // Get calendar availability if available
            var weekdayAvailability: [Int: TimeInterval]? = nil
            if let calculator = availabilityCalculator {
                weekdayAvailability = await calculator()
            }
            
            return createSimplePlanWithoutAI(
                goals: eligibleGoals,
                goalSessions: goalSessions,
                currentDate: currentDate,
                weekdayAvailability: weekdayAvailability
            )
        }
        
        // Get calendar availability if available
        var weekdayAvailability: [Int: TimeInterval]? = nil
        if let calculator = availabilityCalculator {
            weekdayAvailability = await calculator()
        }
        
        // Get quick deterministic recommendations (fast path)
        let quickRecs = getQuickRecommendations(
            for: eligibleGoals,
            goalSessions: goalSessions,
            currentDate: currentDate,
            weather: userPreferences.currentWeather,
            temperature: userPreferences.currentTemperature,
            weekdayAvailability: weekdayAvailability
        )
        
        let prompt = buildPrompt(
             goals: eligibleGoals,
            goalSessions: goalSessions,
            currentDate: currentDate,
            preferences: userPreferences
        )
        
        do {
            let response = try await session.respond(
                to: Prompt(prompt),
                generating: DailyPlan.self,
                options: GenerationOptions(temperature: 0.4)
            )
            
            var plan = response.content
            
            // Override with deterministic recommendations if FM didn't provide them
            // or merge them intelligently
            if plan.topThreeRecommendations == nil || plan.topThreeRecommendations?.isEmpty == true {
                plan.topThreeRecommendations = quickRecs.goalIDs
                plan.recommendationReasoning = "Recommended based on: " + quickRecs.reasons.enumerated().map { idx, reason in
                    let goalTitle = eligibleGoals.first(where: { $0.id.uuidString == quickRecs.goalIDs[idx] })?.title ?? "Goal \(idx + 1)"
                    return "\(goalTitle) (\(reason))"
                }.joined(separator: "; ")
            }
            
            currentPlan = plan
            cachedPlanDate = currentDate // Store the date this plan is for
            cachedPlanTimestamp = Date.now // Update cache timestamp to actual current time
            return plan
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Generate a streaming daily plan with real-time updates
    public func streamDailyPlan(
        for goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date = Date(),
        userPreferences: PlannerPreferences = .default
    ) -> AsyncThrowingStream<DailyPlan.PartiallyGenerated, Error> {
        isGenerating = true
        
        // Clear current plan when starting a new planning session
        currentPlan = nil
        
        // Pre-filter goals to reduce Foundation Model workload
        let eligibleGoals = preFilterGoalsForPlanning(
            goals: goals,
            goalSessions: goalSessions,
            currentDate: currentDate
        )
        
        let prompt = buildPrompt(
            goals: eligibleGoals,
            goalSessions: goalSessions,
            currentDate: currentDate,
            preferences: userPreferences
        )
        
        return AsyncThrowingStream { continuation in
            Task {
                defer { 
                    isGenerating = false
                    continuation.finish()
                }
                
                do {
                    // Use higher temperature for faster generation
                    let stream = session.streamResponse(
                        generating: DailyPlan.self,
                        options: GenerationOptions(temperature: 1.0) // Maximum temp for fastest generation
                    ) {
                        prompt
                    }
                    
                    for try await partialResponse in stream {
                        continuation.yield(partialResponse.content)
                        
                        // Update published property with latest partial plan if fully generated
                        // Check if all required properties are present
                        if let sessions = partialResponse.content.sessions {
                            // Convert PartiallyGenerated sessions to fully generated ones
                            let fullyGeneratedSessions = sessions.compactMap { partialSession -> PlannedSession? in
                                guard let id = partialSession.id,
                                      let goalTitle = partialSession.goalTitle,
                                      let recommendedStartTime = partialSession.recommendedStartTime,
                                      let suggestedDuration = partialSession.suggestedDuration,
                                      let priority = partialSession.priority,
                                      let reasoning = partialSession.reasoning else {
                                    return nil
                                }
                                
                                return PlannedSession(
                                    id: id,
                                    goalTitle: goalTitle,
                                    recommendedStartTime: recommendedStartTime,
                                    suggestedDuration: suggestedDuration,
                                    priority: priority,
                                    reasoning: reasoning
                                )
                            }
                            
                            // Only update if we have at least one fully generated session
                            if !fullyGeneratedSessions.isEmpty {
                                currentPlan = DailyPlan(
                                    sessions: fullyGeneratedSessions,
                                    overallStrategy: partialResponse.content.overallStrategy ?? nil,
                                    topThreeRecommendations: partialResponse.content.topThreeRecommendations ?? nil,
                                    recommendationReasoning: partialResponse.content.recommendationReasoning ?? nil
                                )
                            }
                        }
                    }
                } catch {
                    lastError = error
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Session Scoring
    
    /// Get the top 3 recommended sessions from the current plan
    /// Returns nil if no plan exists or plan doesn't have recommendations
    public func getRecommendedSessionsFromPlan(allSessions: [GoalSession]) -> [GoalSession]? {
        guard let plan = currentPlan,
              let topThreeIDs = plan.topThreeRecommendations,
              !topThreeIDs.isEmpty else {
            return nil
        }
        
        // Map IDs to sessions
        let recommended = topThreeIDs.compactMap { goalIDString -> GoalSession? in
            return allSessions.first { $0.goalID == goalIDString }
        }
        
        return recommended.isEmpty ? nil : recommended
    }
    
    /// Get the PlannedSession for a given GoalSession
    /// Returns nil if no plan exists or session is not in the plan
    public func getPlannedSession(for session: GoalSession) -> PlannedSession? {
        guard let plan = currentPlan else { return nil }
        return plan.sessions.first { $0.id == session.goalID }
    }
    
    /// Score a single session for how recommended it is at a given time
    /// Higher scores mean more recommended
    public func scoreSession(
        for goal: Goal,
        session: GoalSession? = nil,
        sessions: [GoalSession] = [],
        at time: Date = Date(),
        preferences: PlannerPreferences = .default
    ) -> Double {
        var score = 0.0
        
        // 1. Progress-based scoring (0-40 points)
        // Goals that are furthest behind get higher scores
        let dailyTarget = goal.weeklyTarget / 7
        let weeklyProgress = calculateWeeklyProgress(for: goal, sessions: sessions, currentDate: time)
        
        // Inverse progress: the lower the progress, the higher the score
        let progressScore = max(0, 40 * (1 - weeklyProgress / 100))
        score += progressScore
        
        // 2. Time of day matching (0-30 points)
        let currentHour = Calendar.current.component(.hour, from: time)
        let currentWeekday = Calendar.current.component(.weekday, from: time)
        
        // Check if current time matches preferred times
        let preferredTimes = goal.timesForWeekday(currentWeekday)
        if !preferredTimes.isEmpty {
            let matchesPreferredTime = preferredTimes.contains { timeOfDay in
                switch timeOfDay {
                case .morning: return currentHour >= 6 && currentHour < 10
                case .midday: return currentHour >= 10 && currentHour < 14
                case .afternoon: return currentHour >= 14 && currentHour < 17
                case .evening: return currentHour >= 17 && currentHour < 21
                case .night: return currentHour >= 21 || currentHour < 6
                }
            }
            score += matchesPreferredTime ? 30 : 0
        } else {
            // No preference set, give moderate score
            score += 15
        }
        
        // 3. Focus mode adjustment (0-20 points)
        switch preferences.focusMode {
        case .deepWork:
            // Favor goals with higher weekly targets (longer sessions)
            let targetMinutes = goal.weeklyTarget / 60
            score += min(20, targetMinutes / 50)
        case .balanced:
            score += 10 // Neutral bonus
        case .flexible:
            // Favor goals with lower targets (shorter sessions)
            let targetMinutes = goal.weeklyTarget / 60
            score += max(0, 20 - (targetMinutes / 50))
        }
        
        // 4. Planned time bonus (0-25 points)
        // Give significant bonus if this session is planned for around now
        if let session = session, let plannedStartTime = session.plannedStartTime {
            let timeDifference = abs(plannedStartTime.timeIntervalSince(time))
            let minutesDifference = timeDifference / 60
            
            if minutesDifference <= 15 {
                // Within 15 minutes of planned time - highest bonus
                score += 25
            } else if minutesDifference <= 30 {
                // Within 30 minutes - good bonus
                score += 20
            } else if minutesDifference <= 60 {
                // Within 1 hour - moderate bonus
                score += 10
            } else if minutesDifference <= 120 {
                // Within 2 hours - small bonus
                score += 5
            }
        }
        
        // 5. Notification preference bonus (0-10 points)
        if goal.notificationsEnabled {
            score += 10
        }
        
        return score
    }
    
    // MARK: - Prompt Building
    
    /// Create a simple plan without AI for 1-2 goals (much faster)
    private func createSimplePlanWithoutAI(
        goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date,
        weekdayAvailability: [Int: TimeInterval]? = nil
    ) -> DailyPlan {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        
        var sessions: [PlannedSession] = []
        var currentTime = currentDate
        
        for goal in goals {
            guard let session = goalSessions.first(where: { $0.goalID == goal.id.uuidString }) else {
                continue
            }
            
            let dailyTarget = goal.weeklyTarget / 7
            let remainingTime = max(0, dailyTarget - session.elapsedTime)
            let suggestedMinutes = Int(remainingTime / 60)
            
            // Schedule 30 minutes from now (or immediately if < 30 min left in day)
            currentTime = calendar.date(byAdding: .minute, value: 30, to: currentTime) ?? currentTime
            
            let timeString = currentTime.formatted(date: .omitted, time: .shortened)
            let components = calendar.dateComponents([.hour, .minute], from: currentTime)
            let formattedTime = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
            
            let plannedSession = PlannedSession(
                id: goal.id.uuidString,
                goalTitle: goal.title,
                recommendedStartTime: formattedTime,
                suggestedDuration: max(suggestedMinutes, 5),
                priority: 1,
                reasoning: remainingTime > 0 ? "Complete remaining \(Duration.seconds(remainingTime).formatted(.time(pattern: .minuteSecond))) to reach daily target" : "Maintain momentum with this goal"
            )
            sessions.append(plannedSession)
        }
        
        // Use deterministic recommender for ranking
        let quickRecs = getQuickRecommendations(
            for: goals,
            goalSessions: goalSessions,
            currentDate: currentDate,
            weekdayAvailability: weekdayAvailability
        )
        
        let plan = DailyPlan(
            sessions: sessions,
            overallStrategy: "Simple schedule for your \(goals.count) active goal\(goals.count == 1 ? "" : "s")",
            topThreeRecommendations: quickRecs.goalIDs,
            recommendationReasoning: "Recommended: " + quickRecs.reasons.enumerated().map { idx, reason in
                let goalTitle = goals.first(where: { $0.id.uuidString == quickRecs.goalIDs[idx] })?.title ?? "Goal \(idx + 1)"
                return "\(goalTitle) (\(reason))"
            }.joined(separator: "; ")
        )
        
        currentPlan = plan
        cachedPlanDate = currentDate
        cachedPlanTimestamp = Date.now
        return plan
    }
    
    /// Pre-filter goals to only include those eligible for planning
    /// This significantly speeds up planning by reducing the data sent to the Foundation Model
    private func preFilterGoalsForPlanning(
        goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date
    ) -> [Goal] {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        
        // Calculate remaining minutes in the day
        let remainingMinutesInDay = (24 - currentHour) * 60 - currentMinute
        
        // Determine current time of day
        let currentTimeOfDay: TimeOfDay = {
            switch currentHour {
            case 6..<11: return .morning
            case 11..<14: return .midday
            case 14..<17: return .afternoon
            default: return .evening
            }
        }()
        
        var eligibleGoals: [(goal: Goal, priority: Double)] = []
        
        for goal in goals {
            // Filter 1: Must have a valid session with dailyTarget > 0
            guard let session = goalSessions.first(where: { $0.goalID == goal.id.uuidString }),
                  session.dailyTarget > 0 else {
                continue
            }
            
            // Filter 2: Skip if already completed today
            let dailyTarget = goal.weeklyTarget / 7
            if session.elapsedTime >= dailyTarget && dailyTarget > 0 {
                continue
            }
            
            // Filter 3: Calculate remaining time needed
            let remainingTime = max(0, dailyTarget - session.elapsedTime)
            let remainingMinutes = Int(remainingTime / 60)
            
            // Skip if remaining time is tiny (< 1 minute) - not worth planning
            if remainingMinutes < 1 {
                continue
            }
            
            // Filter 4: Skip if remaining time exceeds available time in day
            // (But allow some overflow for flexibility - maybe 2x the remaining time)
            if remainingMinutes > remainingMinutesInDay * 2 {
                continue
            }
            
            // Filter 5: Must have a schedule that matches current day/time OR no schedule (flexible)
            let hasSchedule = goal.hasSchedule
            if hasSchedule {
                // Only include if scheduled for current day and time
                let isScheduledNow = goal.isScheduled(weekday: currentWeekday, time: currentTimeOfDay)
                if !isScheduledNow {
                    continue
                }
            }
            
            // Filter 6: Goal must not be archived
            guard goal.status != .archived else {
                continue
            }
            
            // Calculate priority score for pre-sorting (higher = more urgent)
            var priorityScore: Double = 0
            
            // Factor 1: Progress deficit (further behind = higher priority)
            let progressPercent = dailyTarget > 0 ? (session.elapsedTime / dailyTarget) : 0
            let deficit = max(0, 1.0 - progressPercent)
            priorityScore += deficit * 100 // 0-100 points
            
            // Factor 2: Weekly target urgency
            let weeklyTarget = goal.weeklyTarget
            if weeklyTarget > 0 {
                // Higher weekly targets = more important
                let weeklyHours = weeklyTarget / 3600
                priorityScore += min(weeklyHours * 5, 50) // Up to 50 points
            }
            
            // Factor 3: Time sensitivity - if we're late in the day, prioritize more
            let dayProgress = Double(currentHour) / 24.0
            priorityScore += dayProgress * 30 // Up to 30 points for urgency
            
            // Factor 4: Scheduled vs flexible (scheduled = higher priority)
            if hasSchedule {
                priorityScore += 20 // Bonus for respecting schedule
            }
            
            eligibleGoals.append((goal: goal, priority: priorityScore))
        }
        
        // Sort by priority and take top candidates
        // This pre-sorts goals so Foundation Model focuses on most relevant ones
        let sortedGoals = eligibleGoals
            .sorted { $0.priority > $1.priority }
            .map { $0.goal }
        
        // Limit to reasonable number (e.g., top 10) to keep prompt concise
        // Most users won't want to plan more than 10 sessions in one day anyway
        let maxGoalsToConsider = 10
        return Array(sortedGoals.prefix(maxGoalsToConsider))
    }
    
    private func buildPrompt(
        goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date,
        preferences: PlannerPreferences
    ) -> String {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: currentDate)
        let dayName = calendar.weekdaySymbols[dayOfWeek - 1]
        let currentTime = currentDate.formatted(date: .omitted, time: .shortened)
        
        // Build goal context
        var goalContexts: [String] = []
        
        // Build a list of valid goal IDs
        let validGoalIDs = goals.map { $0.id.uuidString }
        
        for goal in goals {
            guard let session = goalSessions.first(where: { $0.goalID == goal.id.uuidString }) else { continue }
            
            let dailyTarget = goal.weeklyTarget / 7
            let remainingTime = max(0, dailyTarget - session.elapsedTime)
            let remainingMinutes = Int(remainingTime / 60)
            let progress = dailyTarget > 0 ? Int((session.elapsedTime / dailyTarget) * 100) : 0
            
            // Simplified, concise context (50% less text)
            var context = """
            \(goal.title) [\(goal.id.uuidString)]
            Need: \(remainingMinutes)min | Done: \(progress)%
            """
            
            // Only add preferences if they exist (reduces clutter)
            if !goal.preferredTimesOfDay.isEmpty {
                context += " | Times: \(goal.preferredTimesOfDay.joined(separator: ","))"
            }
            
            goalContexts.append(context)
        }
        
        let prompt = """
        Schedule for \(dayName) \(currentTime). Max \(preferences.maxSessionsPerDay) sessions, \(preferences.minimumBreakMinutes)min breaks.
        
        IDs (copy exact): \(validGoalIDs.joined(separator: ", "))
        
        GOALS:
        \(goalContexts.joined(separator: "\n"))
        
        Return: sessions (HH:mm times, chronological), topThreeRecommendations (3 IDs for NOW), reasoning (1 sentence why).
        Prioritize goals furthest behind target.
        """
        
        return prompt
    }
    
    // MARK: - Helper Methods
    
    /// Calculate weekly progress for a goal based on sessions in the current week
    private func calculateWeeklyProgress(for goal: Goal, sessions: [GoalSession], currentDate: Date) -> Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start else {
            return 0.0
        }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? currentDate
        
        // Calculate actual progress from sessions in the current week
        let actualProgress = sessions
            .filter { session in
                session.goalID == goal.id.uuidString &&
                session.day?.startDate ?? .distantPast >= weekStart &&
                session.day?.startDate ?? .distantPast < weekEnd
            }
            .reduce(0.0) { $0 + $1.elapsedTime }
        
        // Return progress as a percentage of weekly target
        guard goal.weeklyTarget > 0 else { return 0.0 }
        return (actualProgress / goal.weeklyTarget) * 100.0
    }
}

// MARK: - Planner Preferences

/// User preferences for how the AI should plan sessions
public struct PlannerPreferences {
    public var planningHorizon: PlanningHorizon = .remainingDay
    public var preferMorningSessions: Bool = false
    public var avoidEveningSessions: Bool = false
    public var maxSessionsPerDay: Int = 5
    public var minimumBreakMinutes: Int = 15
    public var focusMode: FocusMode = .balanced
    public var currentWeather: WeatherCondition? = nil
    public var currentTemperature: Double? = nil
    
    public static let `default` = PlannerPreferences()
    
    public init(
        planningHorizon: PlanningHorizon = .remainingDay,
        preferMorningSessions: Bool = false,
        avoidEveningSessions: Bool = false,
        maxSessionsPerDay: Int = 5,
        minimumBreakMinutes: Int = 15,
        focusMode: FocusMode = .balanced,
        currentWeather: WeatherCondition? = nil,
        currentTemperature: Double? = nil
    ) {
        self.planningHorizon = planningHorizon
        self.preferMorningSessions = preferMorningSessions
        self.avoidEveningSessions = avoidEveningSessions
        self.maxSessionsPerDay = maxSessionsPerDay
        self.minimumBreakMinutes = minimumBreakMinutes
        self.focusMode = focusMode
        self.currentWeather = currentWeather
        self.currentTemperature = currentTemperature
    }
}

public enum PlanningHorizon {
    case remainingDay // Only plan for rest of today
    case fullDay // Plan entire day (including past times as reference)
    case nextDay // Plan for tomorrow
    
    var description: String {
        switch self {
        case .remainingDay: return "Rest of today"
        case .fullDay: return "Full day"
        case .nextDay: return "Tomorrow"
        }
    }
}

public enum FocusMode {
    case deepWork // Fewer, longer sessions
    case balanced // Mix of session lengths
    case flexible // More, shorter sessions
    
    var description: String {
        switch self {
        case .deepWork: return "Deep Work (longer, focused sessions)"
        case .balanced: return "Balanced (mixed session lengths)"
        case .flexible: return "Flexible (shorter, frequent sessions)"
        }
    }
}
