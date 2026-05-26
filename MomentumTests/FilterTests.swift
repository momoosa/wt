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

@Suite("Session Filter Tests")
struct FilterTests {
    
    // MARK: - Active Session Filtering Tests
    
    @Test("filterActiveSessions excludes skipped sessions")
    func filterActiveSessionsExcludesSkipped() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 3600 / 7.0
        let day = Day(start: date, end: date, calendar: calendar)
        
        let active = GoalSession(title: "Active", goal: goal, day: day)
        active.status = .active
        active.unifiedTargetValue = 1800
        
        let skipped = GoalSession(title: "Skipped", goal: goal, day: day)
        skipped.status = .skipped
        skipped.unifiedTargetValue = 1800
        
        let result = SessionFilterService.filterActiveSessions(
            [active, skipped],
            validationCheck: { _ in true }
        )
        
        #expect(result.count == 1)
        #expect(result.first?.title == "Active")
    }
    
    @Test("filterActiveSessions includes sessions with daily targets")
    func filterActiveSessionsIncludesWithTargets() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 3600 / 7.0
        let day = Day(start: date, end: date, calendar: calendar)
        
        let session = GoalSession(title: "Session", goal: goal, day: day)
        session.status = .active
        session.unifiedTargetValue = 1800
        
        let result = SessionFilterService.filterActiveSessions(
            [session],
            validationCheck: { _ in true }
        )
        
        #expect(result.count == 1)
    }
    
    @Test("filterActiveSessions excludes inactive sessions with no target")
    func filterActiveSessionsExcludesInactive() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 0
        let day = Day(start: date, end: date, calendar: calendar)
        
        let session = GoalSession(title: "Session", goal: goal, day: day)
        session.status = .active
        session.unifiedTargetValue = 0
        
        let result = SessionFilterService.filterActiveSessions(
            [session],
            validationCheck: { _ in true }
        )
        
        // Session with no target and not an active goal should be excluded
        #expect(result.isEmpty)
    }
}
