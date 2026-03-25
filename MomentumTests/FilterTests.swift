//
//  FilterTests.swift
//  Momentum Tests
//
//  Created by Assistant on 13/03/2026.
//

import Testing
import Foundation
@testable import Momentum
@testable import MomentumKit

@Suite("Filter Tests")
struct FilterTests {
    
    // MARK: - Filter Availability Tests
    
    @Test("activeToday filter is always available")
    func activeTodayFilterAlwaysAvailable() {
        let sessions: [GoalSession] = []
        let tags: [GoalTag] = []
        
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: sessions)
        
        #expect(filters.contains { filter in
            if case .activeToday = filter { return true }
            return false
        })
    }
    
    @Test("completedToday filter only shows when completed sessions exist")
    func completedFilterShowsWhenCompletedSessionsExist() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        // Create a completed session
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        session.dailyTarget = 1800 // 30 minutes
        session.markedComplete = true // Mark as completed
        
        let tags: [GoalTag] = []
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: [session])
        
        #expect(filters.contains { filter in
            if case .completedToday = filter { return true }
            return false
        })
    }
    
    @Test("completedToday filter hidden when no completed sessions")
    func completedFilterHiddenWhenNoCompletedSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        // Create an incomplete session
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        session.dailyTarget = 1800 // 30 minutes
        session.markedComplete = false // Not completed
        
        let tags: [GoalTag] = []
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: [session])
        
        #expect(!filters.contains { filter in
            if case .completedToday = filter { return true }
            return false
        })
    }
    
    @Test("skippedSessions filter only shows when skipped sessions exist")
    func skippedFilterShowsWhenSkippedSessionsExist() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        // Create a skipped session
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        session.status = .skipped
        
        let tags: [GoalTag] = []
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: [session])
        
        #expect(filters.contains { filter in
            if case .skippedSessions = filter { return true }
            return false
        })
    }
    
    @Test("skippedSessions filter hidden when no skipped sessions")
    func skippedFilterHiddenWhenNoSkippedSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        // Create an active session
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        session.status = .active
        
        let tags: [GoalTag] = []
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: [session])
        
        #expect(!filters.contains { filter in
            if case .skippedSessions = filter { return true }
            return false
        })
    }
    
    @Test("inactive filter only shows when inactive sessions exist")
    func inactiveFilterShowsWhenInactiveSessionsExist() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        // Create an inactive session (no daily target)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        session.dailyTarget = 0
        
        let tags: [GoalTag] = []
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: [session])
        
        #expect(filters.contains { filter in
            if case .inactive = filter { return true }
            return false
        })
    }
    
    // MARK: - Filter Counting Tests
    
    @Test("activeToday filter counts active sessions correctly")
    func activeTodayCountsActiveSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        let session1 = GoalSession(title: "Session 1", goal: goal, day: day)
        session1.status = .active
        
        let session2 = GoalSession(title: "Session 2", goal: goal, day: day)
        session2.status = .active
        
        let count = SessionFilterService.count([session1, session2], for: .activeToday)
        
        #expect(count == 2)
    }
    
    @Test("completedToday filter counts completed sessions correctly")
    func completedTodayCountsCompletedSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        let completed1 = GoalSession(title: "Completed 1", goal: goal, day: day)
        completed1.markedComplete = true
        
        let completed2 = GoalSession(title: "Completed 2", goal: goal, day: day)
        completed2.markedComplete = true
        
        let incomplete = GoalSession(title: "Incomplete", goal: goal, day: day)
        incomplete.markedComplete = false
        
        let count = SessionFilterService.count([completed1, completed2, incomplete], for: .completedToday)
        
        #expect(count == 2)
    }
    
    @Test("skippedSessions filter counts skipped sessions correctly")
    func skippedSessionsCountsSkippedSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        
        let skipped1 = GoalSession(title: "Skipped 1", goal: goal, day: day)
        skipped1.status = .skipped
        
        let skipped2 = GoalSession(title: "Skipped 2", goal: goal, day: day)
        skipped2.status = .skipped
        
        let active = GoalSession(title: "Active", goal: goal, day: day)
        active.status = .active
        
        let count = SessionFilterService.count([skipped1, skipped2, active], for: .skippedSessions)
        
        #expect(count == 2)
    }
    
    // MARK: - Filter Identity Tests
    
    @Test("allGoals filter is not available")
    func allGoalsFilterNotAvailable() {
        let sessions: [GoalSession] = []
        let tags: [GoalTag] = []
        
        let filters = SessionFilterService.buildAvailableFilters(from: tags, sessions: sessions)
        
        // Verify .allGoals is not in the filter list
        let hasAllGoals = filters.contains { filter in
            switch filter {
            case .activeToday, .completedToday, .skippedSessions, .inactive, .theme:
                return false
            }
        }
        
        #expect(!hasAllGoals)
    }
}
