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
    
    public init() {}
    
    /// Generate a daily plan for the given goals and context
    public func generateDailyPlan(
        for goals: [Goal],
        goalSessions: [GoalSession],
        currentDate: Date = Date(),
        userPreferences: PlannerPreferences = .default
    ) async throws -> DailyPlan {
        isGenerating = true
        defer { isGenerating = false }
        
        let prompt = buildPrompt(
            goals: goals,
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
            
            let plan = response.content
            currentPlan = plan
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
        
        let prompt = buildPrompt(
            goals: goals,
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
                        options: GenerationOptions(temperature: 0.7) // Increased from 0.4
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
            guard let goalID = UUID(uuidString: goalIDString) else { return nil }
            return allSessions.first { $0.goal.id == goalID }
        }
        
        return recommended.isEmpty ? nil : recommended
    }
    
    /// Score a single session for how recommended it is at a given time
    /// Higher scores mean more recommended
    public func scoreSession(
        for goal: Goal,
        session: GoalSession? = nil,
        at time: Date = Date(),
        preferences: PlannerPreferences = .default
    ) -> Double {
        var score = 0.0
        
        // 1. Progress-based scoring (0-40 points)
        // Goals that are furthest behind get higher scores
        let dailyTarget = goal.weeklyTarget / 7
        let weeklyProgress = calculateWeeklyProgress(for: goal, currentDate: time)
        
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
            guard let session = goalSessions.first(where: { $0.goal.id == goal.id }) else { continue }
            
            let dailyTarget = goal.weeklyTarget / 7
            let elapsedTime = session.elapsedTime
            let remainingTime = max(0, dailyTarget - elapsedTime)
            let progress = dailyTarget > 0 ? (elapsedTime / dailyTarget) * 100 : 0
            
            // Calculate weekly progress
            let weeklyProgress = calculateWeeklyProgress(for: goal, currentDate: currentDate)
            
            var context = """
            Goal: "\(goal.title)"
            - ID: \(goal.id.uuidString)
            - Daily Target: \(formatDuration(dailyTarget))
            - Time Completed Today: \(formatDuration(elapsedTime))
            - Remaining Time: \(formatDuration(remainingTime))
            - Daily Progress: \(String(format: "%.0f", progress))%
            - Weekly Progress: \(String(format: "%.0f", weeklyProgress))%
            - Theme: \(goal.primaryTag.title)
            - Notifications Enabled: \(goal.notificationsEnabled ? "Yes" : "No")
            """
            
            // Add HealthKit context if available
            if let metric = goal.healthKitMetric, goal.healthKitSyncEnabled {
                context += "\n- HealthKit Metric: \(metric.rawValue)"
            }
            
            // Add time of day preferences
            if !goal.preferredTimesOfDay.isEmpty {
                let timesString = goal.preferredTimesOfDay.joined(separator: ", ")
                context += "\n- Preferred Times of Day: \(timesString)"
            } else {
                context += "\n- Preferred Times of Day: Not specified (any time)"
            }
            
            goalContexts.append(context)
        }
        
        let prompt = """
        Create a daily schedule for these goals. Today is \(dayName), \(currentTime).
        
        VALID IDS (copy exactly for each session):
        \(validGoalIDs.joined(separator: "\n"))
        
        GOALS:
        \(goalContexts.joined(separator: "\n\n"))
        
        RULES:
        - Max \(preferences.maxSessionsPerDay) sessions
        - \(preferences.minimumBreakMinutes)min breaks between sessions
        - Don't schedule in the past
        - Use exact UUID from VALID IDS for each PlannedSession "id" field
        - Times as HH:mm (24hr), chronological order
        
        Focus on goals furthest from their daily target. Include brief reasoning for each session.
        
        IMPORTANT: Also provide "topThreeRecommendations" - an array of exactly 3 goal IDs that should be worked on RIGHT NOW (at \(currentTime)).
        Consider:
        - Which goals are most behind their targets
        - Which goals match the current time of day
        - Urgency and priority
        - Current energy levels typical for \(currentTime)
        
        Also provide "recommendationReasoning" - a brief explanation of why these 3 goals are recommended right now.
        """
        
        return prompt
    }
    
    // MARK: - Helper Methods
    
    /// Calculate weekly progress for a goal (mock implementation - should query actual data)
    private func calculateWeeklyProgress(for goal: Goal, currentDate: Date) -> Double {
        // TODO: Implement actual weekly progress calculation
        // This would query all sessions for the current week
        return 0.0
    }
    
    /// Format time interval as human-readable duration
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
    
    public static let `default` = PlannerPreferences()
    
    public init(
        planningHorizon: PlanningHorizon = .remainingDay,
        preferMorningSessions: Bool = false,
        avoidEveningSessions: Bool = false,
        maxSessionsPerDay: Int = 5,
        minimumBreakMinutes: Int = 15,
        focusMode: FocusMode = .balanced
    ) {
        self.planningHorizon = planningHorizon
        self.preferMorningSessions = preferMorningSessions
        self.avoidEveningSessions = avoidEveningSessions
        self.maxSessionsPerDay = maxSessionsPerDay
        self.minimumBreakMinutes = minimumBreakMinutes
        self.focusMode = focusMode
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
