//
//  DailyProgressViewModel.swift
//  Momentum
//
//  Created by Assistant on 14/03/2026.
//

import SwiftUI
import MomentumKit

/// Single source of truth for daily progress calculations across the app
@Observable
final class DailyProgressViewModel {
    private let sessions: [GoalSession]
    
    init(sessions: [GoalSession]) {
        self.sessions = sessions
    }
    
    // MARK: - Public Computed Properties
    
    /// Overall daily progress as a percentage (0.0 to 1.0)
    /// Caps each session's contribution at its daily target to prevent
    /// overachieving on one goal from inflating overall progress
    var dailyProgress: Double {
        guard totalDailyTarget > 0 else { return 0 }
        return Double(totalDailyMinutes) / Double(totalDailyTarget)
    }
    
    /// Total minutes tracked today (capped at each session's daily target)
    var totalDailyMinutes: Int {
        Int(activeSessions.reduce(0.0) { sum, session in
            // Cap each session's contribution at its daily target
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
    }
    
    /// Total daily target minutes across all active sessions
    var totalDailyTarget: Int {
        activeSessions.reduce(0) { total, session in
            total + Int(session.dailyTarget / 60)
        }
    }
    
    /// Number of goals that have met their daily target
    var completedGoalsCount: Int {
        activeSessions.filter { $0.hasMetDailyTarget }.count
    }
    
    /// Total number of active goals for today
    var totalActiveGoals: Int {
        activeSessions.count
    }
    
    // MARK: - Private Helpers
    
    /// Filters sessions to only include active, non-archived goals
    private var activeSessions: [GoalSession] {
        sessions.filter { session in
            guard session.status != .skipped else { return false }
            guard session.goal?.status != .archived else { return false }
            return true
        }
    }
}
