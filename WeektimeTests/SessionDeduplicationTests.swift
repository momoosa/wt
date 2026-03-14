//
//  SessionDeduplicationTests.swift
//  MomentumTests
//
//  Created by Assistant on 14/03/2026.
//

import Testing
import SwiftData
@testable import Momentum
@testable import MomentumKit

@Suite("Session Time Deduplication")
struct SessionDeduplicationTests {
    
    // MARK: - Test Helpers
    
    private func createGoal(title: String) -> Goal {
        Goal(title: title, days: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
    }
    
    private func createHistoricalSession(
        start: Date,
        duration: TimeInterval,
        healthKitType: String? = nil
    ) -> HistoricalSession {
        let end = start.addingTimeInterval(duration)
        return HistoricalSession(
            title: "Session",
            start: start,
            end: end,
            healthKitType: healthKitType,
            needsHealthKitRecord: healthKitType != nil
        )
    }
    
    // MARK: - No Overlap Tests
    
    @Test("Non-overlapping sessions sum correctly")
    func nonOverlappingSessionsSumCorrectly() throws {
        let goal = createGoal(title: "Meditation")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        // Create three 10-minute sessions with no overlap
        let baseDate = Date()
        let session1 = createHistoricalSession(start: baseDate, duration: 10 * 60)
        let session2 = createHistoricalSession(start: baseDate.addingTimeInterval(15 * 60), duration: 10 * 60)
        let session3 = createHistoricalSession(start: baseDate.addingTimeInterval(30 * 60), duration: 10 * 60)
        
        session1.goalIDs = [goal.id.uuidString]
        session2.goalIDs = [goal.id.uuidString]
        session3.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [session1, session2, session3]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should sum to 30 minutes
        #expect(session.elapsedTime == 30 * 60)
    }
    
    // MARK: - Complete Overlap Tests
    
    @Test("Completely overlapping sessions don't double count")
    func completelyOverlappingSessionsDontDoubleCount() throws {
        let goal = createGoal(title: "Meditation")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        let baseDate = Date()
        
        // Manual session: 10:00 - 10:15 (15 minutes)
        let manualSession = createHistoricalSession(start: baseDate, duration: 15 * 60)
        
        // HealthKit session: 10:00 - 10:15 (15 minutes, exact same time)
        let healthKitSession = createHistoricalSession(
            start: baseDate,
            duration: 15 * 60,
            healthKitType: "HKCategoryTypeIdentifierMindfulSession"
        )
        
        manualSession.goalIDs = [goal.id.uuidString]
        healthKitSession.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [manualSession, healthKitSession]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should only count 15 minutes, not 30
        #expect(session.elapsedTime == 15 * 60)
    }
    
    @Test("Smaller session contained within larger session")
    func smallerSessionContainedWithinLarger() throws {
        let goal = createGoal(title: "Exercise")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        let baseDate = Date()
        
        // Manual session: 10:00 - 10:30 (30 minutes)
        let manualSession = createHistoricalSession(start: baseDate, duration: 30 * 60)
        
        // HealthKit session: 10:05 - 10:15 (10 minutes, contained within manual)
        let healthKitSession = createHistoricalSession(
            start: baseDate.addingTimeInterval(5 * 60),
            duration: 10 * 60,
            healthKitType: "HKWorkoutTypeIdentifier"
        )
        
        manualSession.goalIDs = [goal.id.uuidString]
        healthKitSession.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [manualSession, healthKitSession]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should only count 30 minutes (the larger session)
        #expect(session.elapsedTime == 30 * 60)
    }
    
    // MARK: - Partial Overlap Tests
    
    @Test("Partially overlapping sessions merge correctly")
    func partiallyOverlappingSessionsMerge() throws {
        let goal = createGoal(title: "Meditation")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        let baseDate = Date()
        
        // Manual session: 10:00 - 10:15 (15 minutes)
        let manualSession = createHistoricalSession(start: baseDate, duration: 15 * 60)
        
        // HealthKit session: 10:10 - 10:25 (15 minutes, overlaps last 5 min of manual)
        let healthKitSession = createHistoricalSession(
            start: baseDate.addingTimeInterval(10 * 60),
            duration: 15 * 60,
            healthKitType: "HKCategoryTypeIdentifierMindfulSession"
        )
        
        manualSession.goalIDs = [goal.id.uuidString]
        healthKitSession.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [manualSession, healthKitSession]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should count 25 minutes total (10:00 - 10:25)
        // Not 30 minutes (15 + 15 with double counting)
        #expect(session.elapsedTime == 25 * 60)
    }
    
    @Test("Multiple overlapping sessions merge into one interval")
    func multipleOverlappingSessionsMerge() throws {
        let goal = createGoal(title: "Exercise")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 60 * 60)
        
        let baseDate = Date()
        
        // Session 1: 10:00 - 10:20 (20 minutes)
        let session1 = createHistoricalSession(start: baseDate, duration: 20 * 60)
        
        // Session 2: 10:15 - 10:35 (20 minutes, overlaps with session 1)
        let session2 = createHistoricalSession(
            start: baseDate.addingTimeInterval(15 * 60),
            duration: 20 * 60,
            healthKitType: "HKWorkoutTypeIdentifier"
        )
        
        // Session 3: 10:30 - 10:50 (20 minutes, overlaps with session 2)
        let session3 = createHistoricalSession(
            start: baseDate.addingTimeInterval(30 * 60),
            duration: 20 * 60
        )
        
        session1.goalIDs = [goal.id.uuidString]
        session2.goalIDs = [goal.id.uuidString]
        session3.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [session1, session2, session3]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should count 50 minutes total (10:00 - 10:50)
        // Not 60 minutes (20 + 20 + 20 with double counting)
        #expect(session.elapsedTime == 50 * 60)
    }
    
    // MARK: - Mixed Overlap Tests
    
    @Test("Mix of overlapping and non-overlapping sessions")
    func mixOfOverlappingAndNonOverlapping() throws {
        let goal = createGoal(title: "Focus Work")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 90 * 60)
        
        let baseDate = Date()
        
        // Morning: Two overlapping 15-minute sessions (10:00-10:15, 10:10-10:25)
        let morning1 = createHistoricalSession(start: baseDate, duration: 15 * 60)
        let morning2 = createHistoricalSession(
            start: baseDate.addingTimeInterval(10 * 60),
            duration: 15 * 60,
            healthKitType: "HKCategoryTypeIdentifierMindfulSession"
        )
        
        // Afternoon: Non-overlapping 20-minute session (14:00-14:20)
        let afternoon = createHistoricalSession(
            start: baseDate.addingTimeInterval(4 * 60 * 60),
            duration: 20 * 60
        )
        
        morning1.goalIDs = [goal.id.uuidString]
        morning2.goalIDs = [goal.id.uuidString]
        afternoon.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [morning1, morning2, afternoon]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Morning: 25 minutes (10:00-10:25 merged)
        // Afternoon: 20 minutes
        // Total: 45 minutes
        #expect(session.elapsedTime == 45 * 60)
    }
    
    // MARK: - Edge Cases
    
    @Test("Sessions with same start time but different end times")
    func sameStartDifferentEnd() throws {
        let goal = createGoal(title: "Meditation")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        let baseDate = Date()
        
        // Both start at 10:00, one ends at 10:10, other at 10:20
        let session1 = createHistoricalSession(start: baseDate, duration: 10 * 60)
        let session2 = createHistoricalSession(
            start: baseDate,
            duration: 20 * 60,
            healthKitType: "HKCategoryTypeIdentifierMindfulSession"
        )
        
        session1.goalIDs = [goal.id.uuidString]
        session2.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [session1, session2]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should count 20 minutes (the longer session)
        #expect(session.elapsedTime == 20 * 60)
    }
    
    @Test("Adjacent sessions touching but not overlapping")
    func adjacentSessionsTouchingButNotOverlapping() throws {
        let goal = createGoal(title: "Reading")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        let baseDate = Date()
        
        // Session 1: 10:00 - 10:15
        let session1 = createHistoricalSession(start: baseDate, duration: 15 * 60)
        
        // Session 2: 10:15 - 10:30 (starts exactly when session1 ends)
        let session2 = createHistoricalSession(
            start: baseDate.addingTimeInterval(15 * 60),
            duration: 15 * 60
        )
        
        session1.goalIDs = [goal.id.uuidString]
        session2.goalIDs = [goal.id.uuidString]
        
        day.historicalSessions = [session1, session2]
        session.day = day
        session.goalID = goal.id.uuidString
        
        // Should count as one merged 30-minute interval (touching counts as overlapping)
        #expect(session.elapsedTime == 30 * 60)
    }
    
    @Test("Empty sessions list returns zero")
    func emptySessionsReturnsZero() throws {
        let goal = createGoal(title: "Exercise")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        day.historicalSessions = []
        session.day = day
        session.goalID = goal.id.uuidString
        
        #expect(session.elapsedTime == 0)
    }
    
    @Test("Single session returns its duration")
    func singleSessionReturnsItsDuration() throws {
        let goal = createGoal(title: "Meditation")
        let day = Day(date: Date())
        let session = GoalSession(goal: goal, day: day, dailyTarget: 30 * 60)
        
        let baseDate = Date()
        let historicalSession = createHistoricalSession(start: baseDate, duration: 15 * 60)
        
        historicalSession.goalIDs = [goal.id.uuidString]
        day.historicalSessions = [historicalSession]
        session.day = day
        session.goalID = goal.id.uuidString
        
        #expect(session.elapsedTime == 15 * 60)
    }
}
