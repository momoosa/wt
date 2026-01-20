//
//  GoalSessionPlanner.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 17/01/2026.
//

import Foundation
import FoundationModels
import SwiftData
import WeektimeKit
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
    
    public init(sessions: [PlannedSession], overallStrategy: String? = nil) {
        self.sessions = sessions
        self.overallStrategy = overallStrategy
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
                    let stream = session.streamResponse(generating: DailyPlan.self) {
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
                                    overallStrategy: partialResponse.content.overallStrategy ?? nil
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
            - Theme: \(goal.primaryTheme.title)
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
        You are an AI planner helping a user optimize their daily schedule for personal goals.
        
        Today is \(dayName), and the current time is \(currentTime).
        
        VALID GOAL IDS (use ONLY these exact IDs in your PlannedSession objects):
        \(validGoalIDs.joined(separator: "\n"))
        
        USER PREFERENCES:
        - Planning Horizon: \(preferences.planningHorizon.description)
        - Prefer Morning Sessions: \(preferences.preferMorningSessions ? "Yes" : "No")
        - Avoid Evening Sessions: \(preferences.avoidEveningSessions ? "Yes" : "No")
        - Maximum Sessions Per Day: \(preferences.maxSessionsPerDay)
        - Minimum Break Between Sessions: \(preferences.minimumBreakMinutes) minutes
        - Focus Mode: \(preferences.focusMode.description)
        
        ACTIVE GOALS:
        \(goalContexts.joined(separator: "\n\n"))
        
        PLANNING GUIDELINES:
        1. Prioritize goals based on:
           - Remaining daily target (goals further from target get higher priority)
           - Weekly progress (goals behind schedule get higher priority)
           - Time of day preferences (if specified)
           - Goal theme (wellness goals in morning, creative in afternoon, etc.)
        
        2. Time allocation strategy:
           - If a goal has already met its daily target, you can suggest skipping it or doing a short bonus session
           - Distribute remaining time across goals that need it most
           - Consider natural energy levels (high-energy activities in morning/afternoon)
        
        3. Scheduling rules:
           - Respect minimum break times between sessions
           - Don't schedule sessions in the past
           - Consider typical work hours (9 AM - 5 PM on weekdays)
           - Balance variety with focus time
        
        4. Priority scoring (1-5):
           - 1 = Critical (far behind on target, high importance)
           - 2 = High (behind on target)
           - 3 = Medium (on track)
           - 4 = Low (ahead of target)
           - 5 = Optional (target already met, bonus session)
        
        5. Duration recommendations:
           - Suggest realistic durations based on remaining time
           - Break large sessions into smaller chunks if beneficial
           - Consider the goal type (meditation: 10-20min, reading: 30-60min, exercise: 20-45min)
        
        6. Focus mode considerations:
           - Deep Work: Fewer, longer sessions with more breaks
           - Balanced: Mix of session lengths
           - Flexible: Shorter, more frequent sessions
        
        CRITICAL INSTRUCTIONS FOR THE "id" FIELD:
        - Each PlannedSession's "id" field MUST be one of the VALID GOAL IDS listed at the top
        - Look at the "VALID GOAL IDS" list and choose the ID that matches the goal you're planning
        - Match the goal by looking at its title in the "ACTIVE GOALS" section, then use its corresponding ID
        - The "id" field must be an EXACT copy of one of the UUIDs from the VALID GOAL IDS list
        - Do NOT create new IDs, do NOT simplify them, do NOT use "goal1" or "goal_001"
        
        TASK:
        Create an optimized daily plan with recommended start times, durations, and priorities for each goal.
        Provide clear reasoning for each scheduling decision.
        Include an overall strategy summary explaining your approach for the day.
        
        For each PlannedSession:
        1. Choose a goal from the ACTIVE GOALS section
        2. Find that goal's ID in the VALID GOAL IDS list at the top
        3. Copy that exact UUID string into the PlannedSession's "id" field
        4. Set "goalTitle" to match the goal's title
        5. Choose appropriate start time, duration, priority, and reasoning
        
        Format times as 24-hour HH:mm (e.g., "09:30", "14:00", "19:45").
        Order sessions chronologically by recommended start time.
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
