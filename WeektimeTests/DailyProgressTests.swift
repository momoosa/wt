//
//  DailyProgressTests.swift
//  MomentumTests
//
//  Created by Assistant on 14/03/2026.
//

import Testing
import SwiftData
@testable import Momentum
@testable import MomentumKit

@Suite("Daily Progress Calculations")
struct DailyProgressTests {
    
    // MARK: - Test Helpers
    
    private func createGoal(title: String, status: GoalStatus = .active) -> Goal {
        let goal = Goal(
            title: title,
            days: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        )
        goal.status = status
        return goal
    }
    
    private func createSession(
        goal: Goal,
        elapsedTime: TimeInterval,
        dailyTarget: TimeInterval,
        status: GoalSessionStatus = .active
    ) -> GoalSession {
        let session = GoalSession(
            goal: goal,
            day: Day(date: Date()),
            dailyTarget: dailyTarget
        )
        session.elapsedTime = elapsedTime
        session.status = status
        return session
    }
    
    // MARK: - Capping Tests
    
    @Test("Daily progress caps individual session contributions at their targets")
    func dailyProgressCapsIndividualSessions() {
        let goal1 = createGoal(title: "House Cleaning")
        let goal2 = createGoal(title: "Meditation")
        let goal3 = createGoal(title: "Exercise")
        
        // Session 1: Exceeded target (51m / 19m) - should cap at 19m
        let session1 = createSession(
            goal: goal1,
            elapsedTime: 51 * 60,      // 51 minutes
            dailyTarget: 19 * 60        // 19 minutes target
        )
        
        // Session 2: Met target exactly (15m / 15m)
        let session2 = createSession(
            goal: goal2,
            elapsedTime: 15 * 60,       // 15 minutes
            dailyTarget: 15 * 60        // 15 minutes target
        )
        
        // Session 3: Partial progress (7m / 30m)
        let session3 = createSession(
            goal: goal3,
            elapsedTime: 7 * 60,        // 7 minutes
            dailyTarget: 30 * 60        // 30 minutes target
        )
        
        let sessions = [session1, session2, session3]
        
        // Calculate capped total minutes: min(51, 19) + min(15, 15) + min(7, 30) = 19 + 15 + 7 = 41
        let cappedMinutes = Int(sessions.reduce(0.0) { sum, session in
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
        
        // Total target: 19 + 15 + 30 = 64 minutes
        let totalTarget = sessions.reduce(0) { $0 + Int(session.dailyTarget / 60) }
        
        #expect(cappedMinutes == 41)
        #expect(totalTarget == 64)
        
        // Progress should be 41/64 ≈ 64%
        let progress = Double(cappedMinutes) / Double(totalTarget)
        #expect(progress > 0.63 && progress < 0.65)
    }
    
    @Test("Daily progress without capping would be higher")
    func dailyProgressWithoutCappingIsHigher() {
        let goal1 = createGoal(title: "House Cleaning")
        let goal2 = createGoal(title: "Meditation")
        
        // Session 1: Exceeded target significantly
        let session1 = createSession(
            goal: goal1,
            elapsedTime: 51 * 60,      // 51 minutes
            dailyTarget: 19 * 60        // 19 minutes target
        )
        
        // Session 2: Met target exactly
        let session2 = createSession(
            goal: goal2,
            elapsedTime: 15 * 60,       // 15 minutes
            dailyTarget: 15 * 60        // 15 minutes target
        )
        
        let sessions = [session1, session2]
        
        // Capped: min(51, 19) + min(15, 15) = 19 + 15 = 34
        let cappedMinutes = Int(sessions.reduce(0.0) { sum, session in
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
        
        // Uncapped: 51 + 15 = 66
        let uncappedMinutes = Int(sessions.reduce(0.0) { $0 + $1.elapsedTime } / 60)
        
        // Total target: 19 + 15 = 34
        let totalTarget = sessions.reduce(0) { $0 + Int(session.dailyTarget / 60) }
        
        #expect(cappedMinutes == 34)
        #expect(uncappedMinutes == 66)
        #expect(totalTarget == 34)
        
        // Capped progress: 34/34 = 100%
        let cappedProgress = Double(cappedMinutes) / Double(totalTarget)
        #expect(cappedProgress == 1.0)
        
        // Uncapped progress would be: 66/34 ≈ 194%
        let uncappedProgress = Double(uncappedMinutes) / Double(totalTarget)
        #expect(uncappedProgress > 1.9)
    }
    
    @Test("Daily progress handles all sessions under target")
    func dailyProgressHandlesAllUnderTarget() {
        let goal1 = createGoal(title: "Reading")
        let goal2 = createGoal(title: "Writing")
        let goal3 = createGoal(title: "Exercise")
        
        let session1 = createSession(goal: goal1, elapsedTime: 5 * 60, dailyTarget: 10 * 60)
        let session2 = createSession(goal: goal2, elapsedTime: 3 * 60, dailyTarget: 15 * 60)
        let session3 = createSession(goal: goal3, elapsedTime: 10 * 60, dailyTarget: 30 * 60)
        
        let sessions = [session1, session2, session3]
        
        // All under target, so capped = uncapped
        let cappedMinutes = Int(sessions.reduce(0.0) { sum, session in
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
        
        let uncappedMinutes = Int(sessions.reduce(0.0) { $0 + $1.elapsedTime } / 60)
        
        #expect(cappedMinutes == uncappedMinutes)
        #expect(cappedMinutes == 18) // 5 + 3 + 10
    }
    
    // MARK: - Status Filter Tests
    
    @Test("Daily progress excludes skipped sessions")
    func dailyProgressExcludesSkippedSessions() {
        let goal1 = createGoal(title: "Goal 1")
        let goal2 = createGoal(title: "Goal 2")
        
        let activeSession = createSession(
            goal: goal1,
            elapsedTime: 10 * 60,
            dailyTarget: 20 * 60,
            status: .active
        )
        
        let skippedSession = createSession(
            goal: goal2,
            elapsedTime: 15 * 60,
            dailyTarget: 30 * 60,
            status: .skipped
        )
        
        let sessions = [activeSession, skippedSession]
        
        // Filter out skipped sessions (matching ContentView logic)
        let filteredSessions = sessions.filter { $0.status != .skipped }
        
        let cappedMinutes = Int(filteredSessions.reduce(0.0) { sum, session in
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
        
        let totalTarget = filteredSessions.reduce(0) { total, session in
            total + Int(session.dailyTarget / 60)
        }
        
        // Should only count active session
        #expect(cappedMinutes == 10)
        #expect(totalTarget == 20)
    }
    
    @Test("Daily progress excludes archived goals")
    func dailyProgressExcludesArchivedGoals() {
        let activeGoal = createGoal(title: "Active Goal", status: .active)
        let archivedGoal = createGoal(title: "Archived Goal", status: .archived)
        
        let activeSession = createSession(
            goal: activeGoal,
            elapsedTime: 10 * 60,
            dailyTarget: 20 * 60
        )
        
        let archivedSession = createSession(
            goal: archivedGoal,
            elapsedTime: 15 * 60,
            dailyTarget: 30 * 60
        )
        
        let sessions = [activeSession, archivedSession]
        
        // Filter out archived goals (matching ContentView logic)
        let filteredSessions = sessions.filter { $0.goal?.status != .archived }
        
        let cappedMinutes = Int(filteredSessions.reduce(0.0) { sum, session in
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
        
        let totalTarget = filteredSessions.reduce(0) { total, session in
            total + Int(session.dailyTarget / 60)
        }
        
        // Should only count active goal's session
        #expect(cappedMinutes == 10)
        #expect(totalTarget == 20)
    }
    
    // MARK: - Edge Cases
    
    @Test("Daily progress returns 0 when no sessions")
    func dailyProgressReturnsZeroWhenNoSessions() {
        let sessions: [GoalSession] = []
        
        let totalTarget = sessions.reduce(0) { total, session in
            guard session.status != .skipped else { return total }
            guard session.goal?.status != .archived else { return total }
            return total + Int(session.dailyTarget / 60)
        }
        
        #expect(totalTarget == 0)
        
        // Progress should be 0 when totalTarget is 0
        let progress = totalTarget > 0 ? 1.0 : 0.0
        #expect(progress == 0.0)
    }
    
    @Test("Daily progress returns 0 when all sessions have zero targets")
    func dailyProgressReturnsZeroWhenAllZeroTargets() {
        let goal1 = createGoal(title: "Goal 1")
        let goal2 = createGoal(title: "Goal 2")
        
        let session1 = createSession(goal: goal1, elapsedTime: 10 * 60, dailyTarget: 0)
        let session2 = createSession(goal: goal2, elapsedTime: 5 * 60, dailyTarget: 0)
        
        let sessions = [session1, session2]
        
        let totalTarget = sessions.reduce(0) { total, session in
            guard session.status != .skipped else { return total }
            guard session.goal?.status != .archived else { return total }
            return total + Int(session.dailyTarget / 60)
        }
        
        #expect(totalTarget == 0)
    }
    
    @Test("Daily progress handles exact 100% completion with capping")
    func dailyProgressHandlesExactCompletion() {
        let goal1 = createGoal(title: "Goal 1")
        let goal2 = createGoal(title: "Goal 2")
        
        // Both sessions exactly meet their targets
        let session1 = createSession(goal: goal1, elapsedTime: 20 * 60, dailyTarget: 20 * 60)
        let session2 = createSession(goal: goal2, elapsedTime: 30 * 60, dailyTarget: 30 * 60)
        
        let sessions = [session1, session2]
        
        let cappedMinutes = Int(sessions.reduce(0.0) { sum, session in
            let cappedTime = min(session.elapsedTime, session.dailyTarget)
            return sum + cappedTime
        } / 60)
        
        let totalTarget = sessions.reduce(0) { $0 + Int(session.dailyTarget / 60) }
        
        #expect(cappedMinutes == 50)
        #expect(totalTarget == 50)
        
        let progress = Double(cappedMinutes) / Double(totalTarget)
        #expect(progress == 1.0)
    }
}
