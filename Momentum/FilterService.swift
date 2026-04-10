//
//  FilterService.swift
//  Momentum
//
//  Service for session filtering operations
//

import Foundation
import MomentumKit

/// Service responsible for filtering sessions
class FilterService {
    // MARK: - Focus Filter
    
    /// Get sessions filtered by focus filter
    static func focusFilteredSessions(
        from sessions: [GoalSession],
        focusFilterStore: FocusFilterStore
    ) -> [GoalSession] {
        guard focusFilterStore.isFocusFilterActive else {
            return sessions
        }

        return sessions.filter { session in
            guard let goal = session.goal else { return false }

            // Include if goal matches any active focus tag
            if let primaryTag = goal.primaryTag,
               focusFilterStore.activeFocusTagTitles.contains(primaryTag.title) {
                return true
            }

            return false
        }
    }
    
    // MARK: - Status Filter
    
    /// Get all active sessions (non-skipped)
    static func allActiveSessions(from sessions: [GoalSession]) -> [GoalSession] {
        sessions.filter { $0.status != .skipped }
    }
    
    /// Get completed sessions
    static func completedSessions(from sessions: [GoalSession]) -> [GoalSession] {
        sessions.filter { $0.hasMetDailyTarget }
    }
    
    /// Get skipped sessions
    static func skippedSessions(from sessions: [GoalSession]) -> [GoalSession] {
        sessions.filter { $0.status == .skipped }
    }
    
    /// Get incomplete sessions
    static func incompleteSessions(from sessions: [GoalSession]) -> [GoalSession] {
        sessions.filter { !$0.hasMetDailyTarget && $0.status != .skipped }
    }
}
