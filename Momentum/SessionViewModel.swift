//
//  SessionViewModel.swift
//  Momentum
//
//  ViewModel for session-specific operations (timer, actions)
//

import Foundation
import SwiftUI
import MomentumKit

/// ViewModel handling session-specific operations
@Observable
class SessionViewModel {
    // MARK: - Dependencies
    
    var timerManager: SessionTimerManager?
    private let repository: SessionRepositoryProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(repository: SessionRepositoryProtocol, logger: LoggerProtocol) {
        self.repository = repository
        self.logger = logger
    }
    
    // MARK: - Session Actions
    
    /// Toggle timer for a session
    @discardableResult
    func toggleTimer(for session: GoalSession, in day: Day) -> Result<Void, SessionError> {
        guard let timerManager else {
            logger.error("Timer manager not available for session toggle")
            return .failure(.timerNotAvailable)
        }
        
        logger.info("Toggling timer for session: \(session.goal?.title ?? "Unknown")")
        timerManager.toggleTimer(for: session, in: day)
        
        return .success(())
    }
    
    /// Adjust daily target for a session
    @discardableResult
    func adjustDailyTarget(
        for session: GoalSession,
        by adjustment: TimeInterval
    ) -> Result<TimeInterval, SessionError> {
        let newTarget = max(0, session.dailyTarget + adjustment)
        
        logger.info("Adjusting daily target for session by \(adjustment) seconds")
        
        // Update goal if needed
        if let goal = session.goal {
            let updateResult = repository.updateGoal(goal, weeklyTarget: newTarget * 7)
            if case .failure(let error) = updateResult {
                logger.error("Failed to update goal weekly target: \(error)")
                return .failure(error)
            }
        }
        
        // Update session
        session.dailyTarget = newTarget
        
        // Update timerManager if this is the active session
        if let timerManager,
           let activeSession = timerManager.activeSession,
           activeSession.id == session.id {
            activeSession.dailyTarget = newTarget
        }
        
        // Save changes
        let saveResult = repository.save()
        if case .failure(let error) = saveResult {
            logger.error("Failed to save daily target adjustment: \(error)")
            return .failure(error)
        }
        
        logger.info("Successfully adjusted daily target to \(newTarget) seconds")
        return .success(newTarget)
    }
    
    /// Skip a session
    @discardableResult
    func skip(_ session: GoalSession) -> Result<Void, SessionError> {
        logger.info("Skipping session: \(session.goal?.title ?? "Unknown")")
        
        let result = repository.updateSession(session, status: .skipped)
        
        if case .success = result {
            logger.info("Session skipped successfully")
        } else if case .failure(let error) = result {
            logger.error("Failed to skip session: \(error)")
        }
        
        return result
    }
    
    /// Resume a skipped session
    @discardableResult
    func resumeSession(_ session: GoalSession) -> Result<Void, SessionError> {
        logger.info("Resuming session: \(session.goal?.title ?? "Unknown")")
        
        let result = repository.updateSession(session, status: .active)
        
        if case .success = result {
            logger.info("Session resumed successfully")
        } else if case .failure(let error) = result {
            logger.error("Failed to resume session: \(error)")
        }
        
        return result
    }
}
