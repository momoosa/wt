//
//  WeekStoreTests.swift
//  WeektimeTests
//
//  Created by Mo Moosa on 21/03/2026.
//

import Testing
import Foundation
import SwiftData
@testable import MomentumKit

@Suite("WeekStore Tests")
struct WeekStoreTests {
    
    // MARK: - Helper Methods
    
    /// Creates an in-memory model container for testing
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([Day.self, GoalSession.self, HistoricalSession.self, Goal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    // MARK: - fetchCurrentDay Tests
    
    @Test("fetchCurrentDay creates new day when none exists")
    func testFetchCurrentDayCreatesNewDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let day = try store.fetchCurrentDay()
        
        #expect(day.id == Date.now.yearMonthDayID(with: .current))
        #expect(day.sessions?.isEmpty ?? true)
    }
    
    @Test("fetchCurrentDay returns existing day when available")
    func testFetchCurrentDayReturnsExistingDay() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        // Create a day first
        let firstDay = try store.fetchCurrentDay()
        let firstDayID = firstDay.id
        
        // Fetch again
        let secondDay = try store.fetchCurrentDay()
        
        #expect(firstDay.id == secondDay.id)
        #expect(firstDayID == secondDay.id)
    }
    
    @Test("fetchCurrentDay handles duplicate days from sync conflicts")
    func testFetchCurrentDayHandlesDuplicates() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let startDate = Date.now.startOfDay() ?? .now
        let endDate = Date.now.endOfDay() ?? .now
        
        // Manually create duplicate days (simulating CloudKit sync conflict)
        let day1 = Day(start: startDate, end: endDate)
        let day2 = Day(start: startDate, end: endDate)
        let day3 = Day(start: startDate, end: endDate)
        
        context.insert(day1)
        context.insert(day2)
        context.insert(day3)
        try context.save()
        
        // Fetch should merge duplicates
        let mergedDay = try store.fetchCurrentDay()
        
        // Verify only one day remains
        let expectedID = mergedDay.id
        let fetchRequest = FetchDescriptor<Day>(
            predicate: #Predicate { $0.id == expectedID }
        )
        let remainingDays = try context.fetch(fetchRequest)
        
        #expect(remainingDays.count == 1)
        #expect(remainingDays.first?.id == mergedDay.id)
    }
    
    @Test("fetchCurrentDay merges sessions from duplicate days")
    func testFetchCurrentDayMergesSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let startDate = Date.now.startOfDay() ?? .now
        let endDate = Date.now.endOfDay() ?? .now
        
        // Create duplicate days with different sessions
        let day1 = Day(start: startDate, end: endDate)
        let day2 = Day(start: startDate, end: endDate)
        
        // Create a goal for the sessions
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        context.insert(goal)
        
        let session1 = GoalSession(title: "Session 1", goal: goal, day: day1)
        let session2 = GoalSession(title: "Session 2", goal: goal, day: day2)
        
        context.insert(day1)
        context.insert(day2)
        context.insert(session1)
        context.insert(session2)
        
        try context.save()
        
        // Fetch should merge both sessions into one day
        let mergedDay = try store.fetchCurrentDay()
        
        #expect(mergedDay.sessions?.count == 2)
        #expect(mergedDay.sessions?.contains(where: { $0.title == "Session 1" }) == true)
        #expect(mergedDay.sessions?.contains(where: { $0.title == "Session 2" }) == true)
    }
    
    // MARK: - cleanupDuplicateDays Tests
    
    @Test("cleanupDuplicateDays removes all duplicates")
    func testCleanupDuplicateDays() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let calendar = Calendar.current
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create duplicates for today
        let todayStart = today.startOfDay() ?? today
        let todayEnd = today.endOfDay() ?? today
        let day1 = Day(start: todayStart, end: todayEnd)
        let day2 = Day(start: todayStart, end: todayEnd)
        
        // Create duplicates for yesterday
        let yesterdayStart = yesterday.startOfDay() ?? yesterday
        let yesterdayEnd = yesterday.endOfDay() ?? yesterday
        let day3 = Day(start: yesterdayStart, end: yesterdayEnd)
        let day4 = Day(start: yesterdayStart, end: yesterdayEnd)
        let day5 = Day(start: yesterdayStart, end: yesterdayEnd)
        
        context.insert(day1)
        context.insert(day2)
        context.insert(day3)
        context.insert(day4)
        context.insert(day5)
        try context.save()
        
        // Cleanup
        try store.cleanupDuplicateDays()
        
        // Verify only 2 days remain (one for today, one for yesterday)
        let allDaysRequest = FetchDescriptor<Day>()
        let remainingDays = try context.fetch(allDaysRequest)
        
        #expect(remainingDays.count == 2)
        
        // Verify correct days remain
        let todayID = today.yearMonthDayID(with: calendar)
        let yesterdayID = yesterday.yearMonthDayID(with: calendar)
        
        let remainingIDs = Set(remainingDays.map { $0.id })
        #expect(remainingIDs.contains(todayID))
        #expect(remainingIDs.contains(yesterdayID))
    }
    
    @Test("cleanupDuplicateDays preserves all sessions")
    func testCleanupDuplicateDaysPreservesSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let startDate = Date.now.startOfDay() ?? .now
        let endDate = Date.now.endOfDay() ?? .now
        
        // Create duplicate days with unique sessions
        let day1 = Day(start: startDate, end: endDate)
        let day2 = Day(start: startDate, end: endDate)
        let day3 = Day(start: startDate, end: endDate)
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        context.insert(goal)
        
        let session1 = GoalSession(title: "Session 1", goal: goal, day: day1)
        let session2 = GoalSession(title: "Session 2", goal: goal, day: day2)
        let session3 = GoalSession(title: "Session 3", goal: goal, day: day3)
        
        context.insert(day1)
        context.insert(day2)
        context.insert(day3)
        context.insert(session1)
        context.insert(session2)
        context.insert(session3)
        
        try context.save()
        
        // Cleanup
        try store.cleanupDuplicateDays()
        
        // Verify all sessions are preserved in the merged day
        let expectedDayID = Date.now.yearMonthDayID(with: .current)
        let fetchRequest = FetchDescriptor<Day>(
            predicate: #Predicate { $0.id == expectedDayID }
        )
        let mergedDay = try context.fetch(fetchRequest).first
        
        #expect(mergedDay != nil)
        #expect(mergedDay?.sessions?.count == 3)
    }
    
    @Test("cleanupDuplicateDays handles no duplicates gracefully")
    func testCleanupDuplicateDaysNoDuplicates() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let calendar = Calendar.current
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create unique days only
        let day1 = Day(start: today.startOfDay() ?? today, end: today.endOfDay() ?? today)
        let day2 = Day(start: yesterday.startOfDay() ?? yesterday, end: yesterday.endOfDay() ?? yesterday)
        
        context.insert(day1)
        context.insert(day2)
        try context.save()
        
        // Cleanup should do nothing
        try store.cleanupDuplicateDays()
        
        // Verify both days still exist
        let allDaysRequest = FetchDescriptor<Day>()
        let remainingDays = try context.fetch(allDaysRequest)
        
        #expect(remainingDays.count == 2)
    }
    
    @Test("cleanupDuplicateDays avoids duplicate sessions in merged day")
    func testCleanupDuplicateDaysAvoidsDuplicateSessions() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = WeekStore(modelContext: context)
        
        let startDate = Date.now.startOfDay() ?? .now
        let endDate = Date.now.endOfDay() ?? .now
        
        // Create duplicate days
        let day1 = Day(start: startDate, end: endDate)
        let day2 = Day(start: startDate, end: endDate)
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        context.insert(goal)
        
        // Create one session that appears in both days (simulating a conflict)
        // Note: In reality, a session can only belong to one day, but we're testing conflict resolution
        let sharedSession = GoalSession(title: "Shared Session", goal: goal, day: day1)
        
        context.insert(day1)
        context.insert(day2)
        context.insert(sharedSession)
        
        day1.sessions = [sharedSession]
        day2.sessions = [sharedSession]
        
        try context.save()
        
        // Cleanup
        try store.cleanupDuplicateDays()
        
        // Verify the shared session appears only once
        let expectedDayID = Date.now.yearMonthDayID(with: .current)
        let fetchRequest = FetchDescriptor<Day>(
            predicate: #Predicate { $0.id == expectedDayID }
        )
        let mergedDay = try context.fetch(fetchRequest).first
        
        #expect(mergedDay?.sessions?.count == 1)
        #expect(mergedDay?.sessions?.first?.id == sharedSession.id)
    }
}
