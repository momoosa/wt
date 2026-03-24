//
//  ContextualSection.swift
//  Momentum
//
//  Created by Assistant on 05/03/2026.
//

import Foundation
import MomentumKit

/// Represents a contextual grouping of sessions with timing and constraint information
struct ContextualSection: Identifiable {
    let id = UUID()
    let type: SectionType
    let sessions: [GoalSession]
    let explanation: String?
    
    enum SectionType: Equatable {
        case recommendedNow
        case weatherWindow(time: String, condition: String, icon: String)
        case timeWindow(time: String, reason: String, icon: String)
        case energyWindow(time: String, energyLevel: String)
        case workingOffSchedule
        case available
        case later
        
        var title: String {
            switch self {
            case .recommendedNow:
                return "Recommended Now"
            case .weatherWindow(let time, let condition, _):
                return "\(time) when it's \(condition)"
            case .timeWindow(let time, let reason, _):
                return "\(time) - \(reason)"
            case .energyWindow(let time, let energyLevel):
                return "\(time) (\(energyLevel) energy)"
            case .workingOffSchedule:
                return "Working Off-Schedule"
            case .available:
                return "Available Goals"
            case .later:
                return "Later"
            }
        }
        
        var icon: String? {
            switch self {
            case .recommendedNow:
                return "star.fill"
            case .weatherWindow(_, _, let icon):
                return icon
            case .timeWindow(_, _, let icon):
                return icon
            case .energyWindow:
                return "bolt.fill"
            case .workingOffSchedule:
                return "calendar.badge.clock"
            case .available:
                return "lightbulb.fill"
            case .later:
                return nil
            }
        }
        
        var shouldShowExplanation: Bool {
            switch self {
            case .recommendedNow, .weatherWindow, .timeWindow, .energyWindow, .workingOffSchedule, .available:
                return true
            case .later:
                return false
            }
        }
    }
}

extension ContextualSection {
    /// Group sessions into contextual sections based on timing and constraints
    static func groupSessions(
        _ sessions: [GoalSession],
        recommendedSessions: [GoalSession],
        allGoals: [GoalSession]? = nil,
        currentDate: Date = Date()
    ) -> [ContextualSection] {
        var sections: [ContextualSection] = []
        let recommendedIDs = Set(recommendedSessions.map { $0.id })
        
        // 1. Recommended Now section (top 3 with reasons)
        if !recommendedSessions.isEmpty {
            let topRecommended = Array(recommendedSessions.prefix(3))
            
            sections.append(ContextualSection(
                type: .recommendedNow,
                sessions: topRecommended,
                explanation: "" // TODO: Remove?
            ))
        }
        
        // Get remaining sessions (not in recommended)
        let remainingSessions = sessions.filter { !recommendedIDs.contains($0.id) }
        
        // 2. Working Off-Schedule section (goals not scheduled today but with recent activity)
        let offScheduleSessions = identifyOffScheduleSessions(remainingSessions, currentDate: currentDate)
        if !offScheduleSessions.isEmpty {
            let explanation = generateOffScheduleExplanation(for: offScheduleSessions)
            sections.append(ContextualSection(
                type: .workingOffSchedule,
                sessions: offScheduleSessions,
                explanation: explanation
            ))
        }
        
        // Filter out off-schedule sessions from remaining
        let offScheduleIDs = Set(offScheduleSessions.map { $0.id })
        let regularSessions = remainingSessions.filter { !offScheduleIDs.contains($0.id) }
        
        // 3. Group remaining sessions by timing constraints
        let groupedByConstraints = groupByConstraints(regularSessions, currentDate: currentDate)
        sections.append(contentsOf: groupedByConstraints)
        
        // 4. Later section (everything else)
        let constraintSectionIDs = Set(groupedByConstraints.flatMap { $0.sessions.map { $0.id } })
        let laterSessions = regularSessions.filter { !constraintSectionIDs.contains($0.id) }
        
        if !laterSessions.isEmpty {
            sections.append(ContextualSection(
                type: .later,
                sessions: laterSessions,
                explanation: nil
            ))
        }
        
        // 5. Available Goals section (goals not scheduled for today but could be worked on)
        if let allGoals = allGoals {
            let scheduledIDs = Set(sessions.map { $0.id })
            let availableGoals = allGoals.filter { goal in
                // Not already scheduled for today (dailyTarget == 0 means not scheduled today)
                !scheduledIDs.contains(goal.id) &&
                goal.dailyTarget == 0 &&
                // Goal is active (not skipped or archived)
                goal.status != .skipped &&
                goal.goal?.status != .archived &&
                // Goal has a schedule and weekly target (is a real goal, not just inactive)
                goal.isActiveGoal &&
                // Not yet completed
                !goal.hasMetDailyTarget
            }
            
            if !availableGoals.isEmpty {
                let explanation = generateAvailableGoalsExplanation(
                    availableGoals: availableGoals,
                    scheduledSessions: sessions,
                    currentDate: currentDate
                )
                
                // Limit to top 3-5 most relevant
                let topAvailable = selectTopAvailableGoals(availableGoals, currentDate: currentDate)
                
                sections.append(ContextualSection(
                    type: .available,
                    sessions: topAvailable,
                    explanation: explanation
                ))
            }
        }
        
        return sections
    }
    
    /// Identify sessions that are "working off-schedule" - not scheduled for today but with recent activity
    private static func identifyOffScheduleSessions(
        _ sessions: [GoalSession],
        currentDate: Date
    ) -> [GoalSession] {
        let calendar = Calendar.current
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        
        return sessions.filter { session in
            guard let goal = session.goal else { return false }
            
            // Check if goal has a schedule
            guard goal.hasSchedule else { return false }
            
            // Check if NOT scheduled for today using dailyTarget (most reliable indicator)
            // dailyTarget == 0 means not scheduled for today
            guard session.dailyTarget == 0 else { 
                return false 
            }
            
            // Now check if it meets any of the "working off-schedule" criteria:
            
            // 1. Created within last 24 hours
            if let createdDate = session.day?.startDate,
               createdDate >= oneDayAgo {
                return true
            }
            
            // 2. Has logged time today (elapsedTime > 0)
            if session.elapsedTime > 0 {
                return true
            }
            
            return false
        }
    }
    
    /// Generate explanation for off-schedule sessions
    private static func generateOffScheduleExplanation(for sessions: [GoalSession]) -> String {
        // Check reasons
        let hasNewGoals = sessions.contains { session in
            guard let createdDate = session.day?.startDate else { return false }
            let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            return createdDate >= oneDayAgo
        }
        
        let hasActiveWork = sessions.contains { $0.elapsedTime > 0 }
        
        if hasNewGoals && hasActiveWork {
            return "Recently added goals with progress today"
        } else if hasNewGoals {
            return "Recently added goals you can start now"
        } else if hasActiveWork {
            return "Goals you're working on outside their schedule"
        }
        
        return "Goals with activity outside their scheduled days"
    }
    
    private static func groupByConstraints(
        _ sessions: [GoalSession],
        currentDate: Date
    ) -> [ContextualSection] {
        var sections: [ContextualSection] = []
        var processedSessionIDs = Set<UUID>()
        
        let calendar = Calendar.current
        _ = calendar.component(.hour, from: currentDate)
        
        // Group by weather constraints
        let weatherSessions = sessions.filter { session in
            !processedSessionIDs.contains(session.id) &&
            session.recommendationReasons.contains(.weather)
        }
        
        if !weatherSessions.isEmpty {
            // Find the time window for weather
            if let firstSession = weatherSessions.first,
               let plannedTime = firstSession.plannedStartTime {
                let timeStr = formatTimeWindow(plannedTime)
                
                sections.append(ContextualSection(
                    type: .weatherWindow(
                        time: timeStr,
                        condition: "☀️",
                        icon: "sun.max.fill"
                    ),
                    sessions: weatherSessions,
                    explanation: "Ideal weather conditions for outdoor activities"
                ))
                
                processedSessionIDs.formUnion(weatherSessions.map { $0.id })
            }
        }
        
        // Group by constrained time windows
        let constrainedSessions = sessions.filter { session in
            !processedSessionIDs.contains(session.id) &&
            session.recommendationReasons.contains(.constrained)
        }
        
        if !constrainedSessions.isEmpty {
            // Group by similar time windows
            let timeGroups = Dictionary(grouping: constrainedSessions) { session -> String in
                guard let plannedTime = session.plannedStartTime else { return "later" }
                let hour = calendar.component(.hour, from: plannedTime)
                
                // Group into time blocks
                switch hour {
                case 0..<12: return "morning"
                case 12..<17: return "afternoon"
                case 17..<21: return "evening"
                default: return "night"
                }
            }
            
            for (_, groupSessions) in timeGroups.sorted(by: { $0.key < $1.key }) {
                if let firstSession = groupSessions.first,
                   let plannedTime = firstSession.plannedStartTime {
                    let timeStr = formatTimeWindow(plannedTime)
                    
                    sections.append(ContextualSection(
                        type: .timeWindow(
                            time: timeStr,
                            reason: "Time-limited",
                            icon: "hourglass"
                        ),
                        sessions: groupSessions,
                        explanation: "Only available during this time window"
                    ))
                    
                    processedSessionIDs.formUnion(groupSessions.map { $0.id })
                }
            }
        }
        
        // Group by energy level windows
        let energySessions = sessions.filter { session in
            !processedSessionIDs.contains(session.id) &&
            session.recommendationReasons.contains(.energyLevel)
        }
        
        if !energySessions.isEmpty {
            if let firstSession = energySessions.first,
               let plannedTime = firstSession.plannedStartTime {
                let timeStr = formatTimeWindow(plannedTime)
                
                sections.append(ContextualSection(
                    type: .energyWindow(
                        time: timeStr,
                        energyLevel: "Peak"
                    ),
                    sessions: energySessions,
                    explanation: "Best time for deep focus work"
                ))
                
                processedSessionIDs.formUnion(energySessions.map { $0.id })
            }
        }
        
        return sections
    }
    
    private static func formatTimeWindow(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Generate contextual explanation for available goals section
    private static func generateAvailableGoalsExplanation(
        availableGoals: [GoalSession],
        scheduledSessions: [GoalSession],
        currentDate: Date
    ) -> String {
        let scheduledCompleted = scheduledSessions.filter { $0.hasMetDailyTarget }.count
        let totalScheduled = scheduledSessions.count
        
        // Case 1: All scheduled goals completed
        if totalScheduled > 0 && scheduledCompleted == totalScheduled {
            return "All scheduled tasks done! Consider working on these"
        }
        
        // Case 2: No goals scheduled for today
        if totalScheduled == 0 {
            return "Nothing scheduled today • You could work on these"
        }
        
        // Case 3: Some scheduled goals completed, extra time available
        if scheduledCompleted > 0 {
            return "Ahead of schedule • Extra goals you could tackle"
        }
        
        // Default
        return "Goals you could work on when you have time"
    }
    
    /// Select the most relevant available goals to show
    private static func selectTopAvailableGoals(
        _ availableGoals: [GoalSession],
        currentDate: Date
    ) -> [GoalSession] {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        
        // Score each goal based on relevance
        let scored = availableGoals.map { goal -> (session: GoalSession, score: Double) in
            var score: Double = 0
            
            // 1. Behind on weekly progress (high priority)
            if let weeklyTarget = goal.goal?.weeklyTarget, weeklyTarget > 0 {
                let progress = goal.elapsedTime / weeklyTarget
                if progress < 0.5 {
                    score += 10 // Behind schedule
                } else if progress < 0.7 {
                    score += 5 // Could use more work
                }
            }
            
            // 2. Usually done at this time of day (on other days)
            let currentTimeOfDay: TimeOfDay? = {
                switch currentHour {
                case 6..<11: return .morning
                case 11..<14: return .midday
                case 14..<17: return .afternoon
                case 17..<22: return .evening
                default: return nil
                }
            }()
            
            if let timeOfDay = currentTimeOfDay {
                // Check if this goal is scheduled for this time on other days
                for weekday in 1...7 where weekday != currentWeekday {
                    let times = goal.goal?.timesForWeekday(weekday) ?? []
                    if times.contains(timeOfDay) {
                        score += 3 // Sometimes done at this time
                    }
                }
            }
            
            // 3. Recent activity (worked on in past week)
            if goal.elapsedTime > 0 {
                score += 2
            }
            
            // 4. Quick wins (can be completed soon)
            if goal.progress > 0.7 {
                score += 4
            }
            
            return (goal, score)
        }
        
        // Sort by score and take top 5
        let sorted = scored.sorted { $0.score > $1.score }
        return Array(sorted.prefix(5).map { $0.session })
    }
}
