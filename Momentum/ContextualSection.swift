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
            case .later:
                return nil
            }
        }
        
        var shouldShowExplanation: Bool {
            switch self {
            case .recommendedNow, .weatherWindow, .timeWindow, .energyWindow:
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
        currentDate: Date = Date()
    ) -> [ContextualSection] {
        var sections: [ContextualSection] = []
        let recommendedIDs = Set(recommendedSessions.map { $0.id })
        
        // 1. Recommended Now section (top 3 with reasons)
        if !recommendedSessions.isEmpty {
            let topRecommended = Array(recommendedSessions.prefix(3))
            let explanation = generateRecommendedExplanation(for: topRecommended)
            
            sections.append(ContextualSection(
                type: .recommendedNow,
                sessions: topRecommended,
                explanation: explanation
            ))
        }
        
        // Get remaining sessions (not in recommended)
        let remainingSessions = sessions.filter { !recommendedIDs.contains($0.id) }
        
        // 2. Group remaining sessions by timing constraints
        let groupedByConstraints = groupByConstraints(remainingSessions, currentDate: currentDate)
        sections.append(contentsOf: groupedByConstraints)
        
        // 3. Later section (everything else)
        let constraintSectionIDs = Set(groupedByConstraints.flatMap { $0.sessions.map { $0.id } })
        let laterSessions = remainingSessions.filter { !constraintSectionIDs.contains($0.id) }
        
        if !laterSessions.isEmpty {
            sections.append(ContextualSection(
                type: .later,
                sessions: laterSessions,
                explanation: nil
            ))
        }
        
        return sections
    }
    
    private static func generateRecommendedExplanation(for sessions: [GoalSession]) -> String {
        // Collect all unique recommendation reasons
        let allReasons = Set(sessions.flatMap { $0.recommendationReasons })
        
        // Prioritize reasons
        let priorityReasons: [RecommendationReason] = [
            .constrained, .weather, .quickFinish, .preferredTime, 
            .energyLevel, .weeklyProgress, .usualTime
        ]
        
        // Find the most important reason present
        if let topReason = priorityReasons.first(where: { allReasons.contains($0) }) {
            switch topReason {
            case .constrained:
                return "Time-sensitive tasks available only during this window"
            case .weather:
                return "Perfect conditions for outdoor activities"
            case .quickFinish:
                return "Quick wins - almost done with these"
            case .preferredTime:
                return "Your preferred time slots for focused work"
            case .energyLevel:
                return "Peak energy time for high-focus tasks"
            case .weeklyProgress:
                return "Catch up on weekly targets"
            case .usualTime:
                return "Tasks you typically do around this time"
            default:
                break
            }
        }
        
        // Default explanation
        return "Best tasks to tackle right now"
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
}
