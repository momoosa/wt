//
//  SessionRepository.swift
//  Momentum
//
//  Repository pattern for session data operations
//

import Foundation
import SwiftData
import MomentumKit

/// Protocol for session data persistence
protocol SessionRepositoryProtocol {
    func save() -> Result<Void, SessionError>
    func updateSession(_ session: GoalSession, status: GoalSession.Status) -> Result<Void, SessionError>
    func updateGoal(_ goal: Goal, weeklyTarget: TimeInterval) -> Result<Void, SessionError>
}

/// Repository for managing session data operations
class SessionRepository: SessionRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save() -> Result<Void, SessionError> {
        guard modelContext.safeSave() else {
            return .failure(.saveFailed)
        }
        return .success(())
    }
    
    func updateSession(_ session: GoalSession, status: GoalSession.Status) -> Result<Void, SessionError> {
        session.status = status
        return save()
    }
    
    func updateGoal(_ goal: Goal, weeklyTarget: TimeInterval) -> Result<Void, SessionError> {
        goal.weeklyTarget = weeklyTarget
        return save()
    }
}
