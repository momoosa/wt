//
//  DayTransitionTests.swift
//  WeektimeTests
//
//  Created by Claude on 23/03/2026.
//

import Testing
import Foundation
import SwiftData
@testable import MomentumKit

@Suite("Day Transition Tests")
struct DayTransitionTests {
    
    // MARK: - Helper Methods
    
    /// Creates an in-memory model container for testing
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([Day.self, GoalSession.self, HistoricalSession.self, Goal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    /// Creates sessions for all active goals for a given day
    private func createSessionsForDay(_ day: Day, context: ModelContext) throws {
        // Fetch all goals and filter for active ones (status is computed property)
        let goalDescriptor = FetchDescriptor<Goal>()
        let allGoals = try context.fetch(goalDescriptor)
        let activeGoals = allGoals.filter { $0.status == .active }
        
        // Fetch existing sessions for this day
        let dayID = day.id
        let sessionDescriptor = FetchDescriptor<GoalSession>(
            predicate: #Predicate { session in
                session.day?.id == dayID
            }
        )
        let existingSessions = try context.fetch(sessionDescriptor)
        
        // Create sessions for goals that don't have them yet
        for goal in activeGoals {
            if !existingSessions.contains(where: { $0.goal?.id == goal.id }) {
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                context.insert(session)
            }
        }
        
        // Save if we made changes
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Tests
    
    @Test("Sessions are created for new day")
    func testSessionsCreatedForNewDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let weekStore = WeekStore(modelContext: context)
        
        // Create some active goals
        let goal1 = Goal(title: "Exercise", weeklyTarget: 3600)
        let goal2 = Goal(title: "Reading", weeklyTarget: 3600)
        let goal3 = Goal(title: "Coding", weeklyTarget: 7200)
        
        context.insert(goal1)
        context.insert(goal2)
        context.insert(goal3)
        try context.save()
        
        // Fetch current day
        let day = try weekStore.fetchCurrentDay()
        
        // Create sessions for the day
        try createSessionsForDay(day, context: context)
        
        // Verify sessions were created
        let dayID = day.id
        let sessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayID }
        )
        let sessions = try context.fetch(sessionRequest)
        
        #expect(sessions.count == 3)
        #expect(sessions.contains(where: { $0.title == "Exercise" }))
        #expect(sessions.contains(where: { $0.title == "Reading" }))
        #expect(sessions.contains(where: { $0.title == "Coding" }))
    }
    
    @Test("Sessions not created for archived goals")
    func testSessionsNotCreatedForArchivedGoals() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let weekStore = WeekStore(modelContext: context)
        
        // Create active and archived goals
        let activeGoal = Goal(title: "Active Goal", weeklyTarget: 3600)
        let archivedGoal = Goal(title: "Archived Goal", weeklyTarget: 3600)
        archivedGoal.status = .archived
        
        context.insert(activeGoal)
        context.insert(archivedGoal)
        try context.save()
        
        // Fetch current day and create sessions
        let day = try weekStore.fetchCurrentDay()
        try createSessionsForDay(day, context: context)
        
        // Verify only active goal has a session
        let dayID = day.id
        let sessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayID }
        )
        let sessions = try context.fetch(sessionRequest)
        
        #expect(sessions.count == 1)
        #expect(sessions.first?.title == "Active Goal")
    }
    
    @Test("Duplicate session creation is prevented")
    func testDuplicateSessionCreationPrevented() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let weekStore = WeekStore(modelContext: context)
        
        // Create a goal
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        context.insert(goal)
        try context.save()
        
        // Fetch current day
        let day = try weekStore.fetchCurrentDay()
        
        // Create sessions twice
        try createSessionsForDay(day, context: context)
        try createSessionsForDay(day, context: context)
        
        // Verify only one session was created
        let dayID = day.id
        let sessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayID }
        )
        let sessions = try context.fetch(sessionRequest)
        
        #expect(sessions.count == 1)
    }
    
    @Test("Day transition creates new sessions for next day")
    func testDayTransitionCreatesNewSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        // Create goals
        let goal = Goal(title: "Daily Goal", weeklyTarget: 3600)
        context.insert(goal)
        try context.save()
        
        // Create day for "today"
        let calendar = Calendar.current
        let today = Date.now
        let todayStart = calendar.startOfDay(for: today)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let todayDay = Day(start: todayStart, end: todayEnd, calendar: calendar)
        context.insert(todayDay)
        try context.save()
        
        // Create sessions for today
        try createSessionsForDay(todayDay, context: context)
        
        // Verify today's sessions
        let todayID = todayDay.id
        let todaySessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == todayID }
        )
        let todaySessions = try context.fetch(todaySessionRequest)
        #expect(todaySessions.count == 1)
        
        // Simulate day transition: create tomorrow's day
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowStart = calendar.startOfDay(for: tomorrow)
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart)!
        
        let tomorrowDay = Day(start: tomorrowStart, end: tomorrowEnd, calendar: calendar)
        context.insert(tomorrowDay)
        try context.save()
        
        // Create sessions for tomorrow
        try createSessionsForDay(tomorrowDay, context: context)
        
        // Verify tomorrow's sessions
        let tomorrowID = tomorrowDay.id
        let tomorrowSessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == tomorrowID }
        )
        let tomorrowSessions = try context.fetch(tomorrowSessionRequest)
        
        #expect(tomorrowSessions.count == 1)
        #expect(tomorrowSessions.first?.title == "Daily Goal")
        
        // Verify both days have separate sessions
        let allSessionsRequest = FetchDescriptor<GoalSession>()
        let allSessions = try context.fetch(allSessionsRequest)
        #expect(allSessions.count == 2)
    }
    
    @Test("Sessions reference correct day after transition")
    func testSessionsReferenceCorrectDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        context.insert(goal)
        
        // Create two days
        let calendar = Calendar.current
        let today = Date.now
        let todayStart = calendar.startOfDay(for: today)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let dayOne = Day(start: todayStart, end: todayEnd, calendar: calendar)
        context.insert(dayOne)
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowStart = calendar.startOfDay(for: tomorrow)
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart)!
        
        let dayTwo = Day(start: tomorrowStart, end: tomorrowEnd, calendar: calendar)
        context.insert(dayTwo)
        
        try context.save()
        
        // Create sessions for both days
        try createSessionsForDay(dayOne, context: context)
        try createSessionsForDay(dayTwo, context: context)
        
        // Fetch sessions for day one
        let dayOneID = dayOne.id
        let dayOneSessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayOneID }
        )
        let dayOneSessions = try context.fetch(dayOneSessionRequest)
        
        // Fetch sessions for day two
        let dayTwoID = dayTwo.id
        let dayTwoSessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayTwoID }
        )
        let dayTwoSessions = try context.fetch(dayTwoSessionRequest)
        
        // Verify correct associations
        #expect(dayOneSessions.count == 1)
        #expect(dayTwoSessions.count == 1)
        #expect(dayOneSessions.first?.day?.id == dayOne.id)
        #expect(dayTwoSessions.first?.day?.id == dayTwo.id)
        #expect(dayOneSessions.first?.id != dayTwoSessions.first?.id)
    }
    
    @Test("Empty day with no goals creates no sessions")
    func testEmptyDayWithNoGoals() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let weekStore = WeekStore(modelContext: context)
        
        // Fetch current day without creating any goals
        let day = try weekStore.fetchCurrentDay()
        
        // Attempt to create sessions
        try createSessionsForDay(day, context: context)
        
        // Verify no sessions were created
        let dayID = day.id
        let sessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayID }
        )
        let sessions = try context.fetch(sessionRequest)
        
        #expect(sessions.isEmpty)
    }
    
    @Test("Multiple goals create multiple sessions")
    func testMultipleGoalsCreateMultipleSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let weekStore = WeekStore(modelContext: context)
        
        // Create 5 goals
        for i in 1...5 {
            let goal = Goal(title: "Goal \(i)", weeklyTarget: TimeInterval(i * 3600))
            context.insert(goal)
        }
        try context.save()
        
        // Fetch current day and create sessions
        let day = try weekStore.fetchCurrentDay()
        try createSessionsForDay(day, context: context)
        
        // Verify 5 sessions were created
        let dayID = day.id
        let sessionRequest = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.day?.id == dayID }
        )
        let sessions = try context.fetch(sessionRequest)
        
        #expect(sessions.count == 5)
        
        // Verify each session has correct title
        let titles = sessions.map { $0.title }.sorted()
        #expect(titles == ["Goal 1", "Goal 2", "Goal 3", "Goal 4", "Goal 5"])
    }
}
