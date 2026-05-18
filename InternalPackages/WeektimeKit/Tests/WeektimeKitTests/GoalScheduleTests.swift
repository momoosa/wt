//
//  GoalScheduleTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Scheduling Logic")
struct GoalScheduleTests {
    
    // MARK: - Unified Daily Target Tests
    
    @Test("Unified daily target can be set and read back")
    func unifiedDailyTargetRoundTrips() {
        let goal = Goal(title: "Test")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800 // 30 minutes
        
        #expect(goal.unifiedDailyTarget == 1800)
    }
    
    @Test("Unified target returns daily target for scheduled days")
    func unifiedTargetReturnsDefaultForScheduledDays() {
        let goal = Goal(title: "Test")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 3600 // 1 hour per day
        // Schedule for Monday and Wednesday
        goal.setTimes([.morning], forWeekday: 2) // Monday
        goal.setTimes([.evening], forWeekday: 4) // Wednesday
        
        #expect(goal.unifiedTarget(for: 2) == 3600)
        #expect(goal.unifiedTarget(for: 4) == 3600)
    }
    
    @Test("Unified target returns daily target when no schedule is set")
    func unifiedTargetReturnsDefaultWithNoSchedule() {
        let goal = Goal(title: "Test")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1000
        
        // All weekdays should return the same unified daily target
        for weekday in 1...7 {
            #expect(goal.unifiedTarget(for: weekday) == 1000)
        }
    }
    
    @Test("Unified daily target defaults to zero")
    func unifiedDailyTargetDefaultsToZero() {
        let goal = Goal(title: "Test")
        
        #expect(goal.unifiedDailyTarget == 0)
    }
    
    @Test("Per-day target overrides unified daily target for specific weekday")
    func perDayTargetOverridesDefault() {
        let goal = Goal(title: "Test")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800 // 30 minutes default
        goal.perDayTargets["2"] = 3600 // Monday override: 1 hour
        
        #expect(goal.unifiedTarget(for: 2) == 3600) // Monday uses override
        #expect(goal.unifiedTarget(for: 3) == 1800) // Tuesday uses default
    }
    
    // MARK: - isScheduled Tests
    
    @Test("isScheduled returns true for scheduled day and time")
    func isScheduledReturnsTrueForScheduledTime() {
        let goal = Goal(title: "Test")
        goal.setTimes([.morning, .afternoon], forWeekday: 2) // Monday morning/afternoon
        
        #expect(goal.isScheduled(weekday: 2, time: .morning))
        #expect(goal.isScheduled(weekday: 2, time: .afternoon))
    }
    
    @Test("isScheduled returns false for unscheduled day")
    func isScheduledReturnsFalseForUnscheduledDay() {
        let goal = Goal(title: "Test")
        goal.setTimes([.morning], forWeekday: 2) // Only Monday
        
        #expect(!goal.isScheduled(weekday: 3, time: .morning)) // Tuesday
    }
    
    @Test("isScheduled returns false for unscheduled time")
    func isScheduledReturnsFalseForUnscheduledTime() {
        let goal = Goal(title: "Test")
        goal.setTimes([.morning], forWeekday: 2) // Only morning
        
        #expect(!goal.isScheduled(weekday: 2, time: .evening))
    }
}
