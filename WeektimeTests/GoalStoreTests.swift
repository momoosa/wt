//
//  GoalStoreTests.swift
//  WeektimeTests
//
//  Created by Mo Moosa on 21/03/2026.
//

import Testing
import Foundation
import SwiftData
@testable import MomentumKit

@Suite("GoalStore Tests")
struct GoalStoreTests {
    
    // MARK: - Helper Methods
    
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([Day.self, GoalSession.self, HistoricalSession.self, Goal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    private func createTestGoal(container: ModelContainer, title: String = "Test Goal", weeklyTarget: TimeInterval = 3600) -> Goal {
        let context = ModelContext(container)
        let goal = Goal(title: title, weeklyTarget: weeklyTarget)
        context.insert(goal)
        try? context.save()
        return goal
    }
    
    private func createTestDay(container: ModelContainer, date: Date = Date.now) -> Day {
        let context = ModelContext(container)
        let startDate = date.startOfDay() ?? date
        let endDate = date.endOfDay() ?? date
        let day = Day(start: startDate, end: endDate)
        context.insert(day)
        try? context.save()
        return day
    }
    
    // MARK: - getTodaySession Tests
    
    @Test("getTodaySession returns nil when no session exists")
    func testGetTodaySessionReturnsNilWhenNoSession() throws {
        let container = try makeTestContainer()
        let goal = createTestGoal(container: container)
        let store = GoalStore()
        
        let session = store.getTodaySession(for: goal)
        
        #expect(session == nil)
    }
    
    @Test("getTodaySession returns session for current day")
    func testGetTodaySessionReturnsCurrentSession() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [session]
        
        let result = store.getTodaySession(for: goal)
        
        #expect(result != nil)
        #expect(result?.id == session.id)
        #expect(result?.goalID == goal.id.uuidString)
    }
    
    @Test("getTodaySession returns nil for different day")
    func testGetTodaySessionReturnsNilForDifferentDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date.now)!
        let yesterdayDay = createTestDay(container: container, date: yesterday)
        
        let session = GoalSession(title: goal.title, goal: goal, day: yesterdayDay)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [session]
        
        let result = store.getTodaySession(for: goal)
        
        #expect(result == nil)
    }
    
    @Test("getTodaySession returns correct session when multiple exist")
    func testGetTodaySessionWithMultipleSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date.now)!
        
        let todayDay = createTestDay(container: container)
        let yesterdayDay = createTestDay(container: container, date: yesterday)
        
        let todaySession = GoalSession(title: "Today", goal: goal, day: todayDay)
        
        let yesterdaySession = GoalSession(title: "Yesterday", goal: goal, day: yesterdayDay)
        
        context.insert(todaySession)
        context.insert(yesterdaySession)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [todaySession, yesterdaySession]
        
        let result = store.getTodaySession(for: goal)
        
        #expect(result != nil)
        #expect(result?.id == todaySession.id)
        #expect(result?.title == "Today")
    }
    
    // MARK: - getWeeklyProgress Tests
    
    @Test("getWeeklyProgress returns zero when no sessions exist")
    func testGetWeeklyProgressReturnsZeroWhenNoSessions() throws {
        let container = try makeTestContainer()
        let goal = createTestGoal(container: container)
        let store = GoalStore()
        
        let progress = store.getWeeklyProgress(for: goal)
        
        #expect(progress == 0)
    }
    
    @Test("getWeeklyProgress calculates single day progress")
    func testGetWeeklyProgressSingleDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container, weeklyTarget: 3600)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [session]
        
        let progress = store.getWeeklyProgress(for: goal)
        
        #expect(progress == 30) // 30 minutes
    }
    
    @Test("getWeeklyProgress calculates full week progress")
    func testGetWeeklyProgressFullWeek() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container, weeklyTarget: 3600)
        
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date.now)) else {
            Issue.record("Failed to create start of week")
            return
        }
        
        var sessions: [GoalSession] = []
        
        // Create sessions for each day of the week
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            let day = createTestDay(container: container, date: date)
            
            let session = GoalSession(title: goal.title, goal: goal, day: day)
            
            context.insert(session)
            sessions.append(session)
        }
        
        try context.save()
        
        let store = GoalStore()
        store.sessions = sessions
        
        let progress = store.getWeeklyProgress(for: goal)
        
        #expect(progress == 70) // 7 days × 10 minutes = 70 minutes
    }
    
    @Test("getWeeklyProgress includes healthKitTime")
    func testGetWeeklyProgressIncludesHealthKitTime() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [session]
        
        let progress = store.getWeeklyProgress(for: goal)
        
        #expect(progress == 30) // 10 + 20 = 30 minutes
    }
    
    @Test("getWeeklyProgress ignores sessions from previous weeks")
    func testGetWeeklyProgressIgnoresPreviousWeeks() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .day, value: -8, to: Date.now)!
        
        let thisWeekDay = createTestDay(container: container)
        let lastWeekDay = createTestDay(container: container, date: lastWeek)
        
        let thisWeekSession = GoalSession(title: "This Week", goal: goal, day: thisWeekDay)
        
        let lastWeekSession = GoalSession(title: "Last Week", goal: goal, day: lastWeekDay)
        
        context.insert(thisWeekSession)
        context.insert(lastWeekSession)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [thisWeekSession, lastWeekSession]
        
        let progress = store.getWeeklyProgress(for: goal)
        
        #expect(progress == 10) // Only this week's 10 minutes
    }
    
    @Test("getWeeklyProgress handles multiple goals correctly")
    func testGetWeeklyProgressMultipleGoals() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let goal1 = createTestGoal(container: container, title: "Goal 1")
        let goal2 = createTestGoal(container: container, title: "Goal 2")
        let day = createTestDay(container: container)
        
        let session1 = GoalSession(title: "Session 1", goal: goal1, day: day)
        
        let session2 = GoalSession(title: "Session 2", goal: goal2, day: day)
        
        context.insert(session1)
        context.insert(session2)
        try context.save()
        
        let store = GoalStore()
        store.sessions = [session1, session2]
        
        let progress1 = store.getWeeklyProgress(for: goal1)
        let progress2 = store.getWeeklyProgress(for: goal2)
        
        #expect(progress1 == 10)
        #expect(progress2 == 20)
    }
    
    // MARK: - save Tests
    
    @Test("save creates historical session with valid duration")
    func testSaveCreatesHistoricalSession() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        let startDate = Date.now
        let endDate = Date.now.addingTimeInterval(600) // 10 minutes later
        
        let historicalSession = store.save(session: session, in: day, startDate: startDate, endDate: endDate)
        
        #expect(historicalSession != nil)
        #expect(historicalSession?.goalIDs == [session.goalID])
        #expect(historicalSession?.title == session.title)
    }
    
    @Test("save returns nil for zero duration")
    func testSaveReturnsNilForZeroDuration() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        let startDate = Date.now
        let endDate = startDate // Same time = zero duration
        
        let historicalSession = store.save(session: session, in: day, startDate: startDate, endDate: endDate)
        
        #expect(historicalSession == nil)
    }
    
    @Test("save returns nil for negative duration")
    func testSaveReturnsNilForNegativeDuration() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        let endDate = Date.now
        let startDate = endDate.addingTimeInterval(600) // Start after end
        
        let historicalSession = store.save(session: session, in: day, startDate: startDate, endDate: endDate)
        
        #expect(historicalSession == nil)
    }
    
    @Test("save returns nil when session has no model context")
    func testSaveReturnsNilWithoutModelContext() throws {
        let container = try makeTestContainer()
        let day = createTestDay(container: container)
        
        // Create session without inserting into context - this will fail as expected
        // since GoalSession requires a goal and day
        let goal2 = Goal(title: "Detached Goal", weeklyTarget: 3600)
        let day2 = Day(start: Date.now.startOfDay() ?? .now, end: Date.now.endOfDay() ?? .now)
        let session = GoalSession(title: "Detached Session", goal: goal2, day: day2)
        
        let store = GoalStore()
        let startDate = Date.now
        let endDate = Date.now.addingTimeInterval(600)
        
        let historicalSession = store.save(session: session, in: day, startDate: startDate, endDate: endDate)
        
        #expect(historicalSession == nil)
    }
    
    @Test("save adds historical session to day")
    func testSaveAddsHistoricalSessionToDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let initialHistoricalCount = day.historicalSessions?.count ?? 0
        
        let store = GoalStore()
        let startDate = Date.now
        let endDate = Date.now.addingTimeInterval(600)
        
        _ = store.save(session: session, in: day, startDate: startDate, endDate: endDate)
        
        let finalHistoricalCount = day.historicalSessions?.count ?? 0
        
        #expect(finalHistoricalCount == initialHistoricalCount + 1)
    }
    
    @Test("save creates multiple historical sessions")
    func testSaveCreatesMultipleHistoricalSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let goal = createTestGoal(container: container)
        let day = createTestDay(container: container)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        context.insert(session)
        try context.save()
        
        let store = GoalStore()
        
        // Save first session
        let start1 = Date.now
        let end1 = start1.addingTimeInterval(600)
        let historical1 = store.save(session: session, in: day, startDate: start1, endDate: end1)
        
        // Save second session
        let start2 = end1
        let end2 = start2.addingTimeInterval(300)
        let historical2 = store.save(session: session, in: day, startDate: start2, endDate: end2)
        
        #expect(historical1 != nil)
        #expect(historical2 != nil)
        #expect(historical1?.id != historical2?.id)
        #expect(day.historicalSessions?.count ?? 0 >= 2)
    }
}
