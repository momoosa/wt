//
//  ContextualSection.swift
//  Momentum
//
//  Created by Assistant on 05/03/2026.
//

import Foundation
import SwiftUI
import SwiftData
import MomentumKit

/// Represents a contextual grouping of sessions with timing and constraint information
struct ContextualSection: Identifiable {
    /// Stable identity derived from section type so SwiftUI can diff sections across body evaluations
    var id: String {
        switch type {
        case .recommendedNow: return "recommendedNow"
        case .weatherMatch(let condition): return "weather_\(condition)"
        case .later: return "later"
        case .completed: return "completed"
        case .skipped: return "skipped"
        }
    }
    let type: SectionType
    let sessions: [GoalSession]
    let explanation: String?
    
    enum SectionType: Equatable, Hashable {
        case recommendedNow
        case weatherMatch(condition: String)
        case later
        case completed
        case skipped
        
        var title: String {
            switch self {
            case .recommendedNow:
                return "This Moment"
            case .weatherMatch(let condition):
                return "Good for \(condition)"
            case .later:
                return "Later"
            case .completed:
                return "Completed Today"
            case .skipped:
                return "Skipped"
            }
        }
        
        var icon: String? {
            switch self {
            case .recommendedNow:
                return "star.fill"
            case .weatherMatch:
                return "sun.max.fill"
            case .later:
                return nil
            case .completed:
                return "checkmark.circle.fill"
            case .skipped:
                return "xmark.circle.fill"
            }
        }
        
        var shouldShowExplanation: Bool {
            switch self {
            case .recommendedNow, .weatherMatch:
                return true
            case .later, .completed, .skipped:
                return false
            }
        }
        
        var iconColor: Color {
            switch self {
            case .recommendedNow: return .yellow
            case .weatherMatch: return .blue
            case .completed: return .green
            case .skipped: return .orange
            case .later: return .gray
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
        downrankedSessions: [DownrankedSession] = [],
        skippedSessions: [GoalSession] = [],
        currentDate: Date = Date()
    ) -> [ContextualSection] {
        var sections: [ContextualSection] = []
        let recommendedIDs = Set(recommendedSessions.map { $0.id })
        
        // 1. This Moment — top recommended picks
        if !recommendedSessions.isEmpty {
            let topRecommended = Array(recommendedSessions.prefix(3))
            sections.append(ContextualSection(
                type: .recommendedNow,
                sessions: topRecommended,
                explanation: nil
            ))
        }
        
        // Collect all non-recommended, non-completed sessions
        let remainingSessions = sessions.filter { !recommendedIDs.contains($0.id) }
        
        // 2. Weather/location match — sessions that match current weather conditions
        let weatherSessions = remainingSessions.filter { session in
            session.safeRecommendationReasons.contains(.weather) && !session.hasMetDailyTarget
        }
        
        if !weatherSessions.isEmpty {
            sections.append(ContextualSection(
                type: .weatherMatch(condition: "this weather"),
                sessions: weatherSessions,
                explanation: "Conditions match for outdoor activities"
            ))
        }
        
        let weatherIDs = Set(weatherSessions.map { $0.id })
        
        // 3. Later — everything else not completed
        var laterSessions = remainingSessions.filter {
            !weatherIDs.contains($0.id) && !$0.hasMetDailyTarget
        }
        
        // Include downranked sessions (weather mismatch, not scheduled today) in Later
        let scheduledIDs = Set(sessions.map { $0.id })
        let downrankedToInclude = downrankedSessions.filter { !scheduledIDs.contains($0.session.id) }
        laterSessions.append(contentsOf: downrankedToInclude.map(\.session))
        
        if !laterSessions.isEmpty {
            sections.append(ContextualSection(
                type: .later,
                sessions: laterSessions,
                explanation: nil
            ))
        }
        
        // 4. Skipped
        if !skippedSessions.isEmpty {
            sections.append(ContextualSection(
                type: .skipped,
                sessions: skippedSessions,
                explanation: nil
            ))
        }
        
        // 5. Completed Today
        if let allGoals = allGoals {
            let completedGoals = allGoals.filter { goal in
                goal.hasMetDailyTarget && (goal.unifiedTargetValue > 0 || goal.isActiveGoal)
            }
            
            if !completedGoals.isEmpty {
                sections.append(ContextualSection(
                    type: .completed,
                    sessions: completedGoals,
                    explanation: nil
                ))
            }
        }
        
        return sections
    }
}
