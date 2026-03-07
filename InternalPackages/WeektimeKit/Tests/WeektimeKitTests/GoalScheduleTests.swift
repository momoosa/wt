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
    
    // MARK: - dailyTargetFromSchedule Tests
    
    @Test("Daily target uses dailyMinimum when set")
    func dailyTargetUsesDailyMinimum() {
        let goal = Goal(title: "Test", weeklyTarget: 3600) // 1 hour weekly
        goal.dailyMinimum = 1800 // 30 minutes daily minimum
        
        #expect(goal.dailyTargetFromSchedule() == 1800)
    }
    
    @Test("Daily target divides by scheduled days when schedule exists")
    func dailyTargetDividesByScheduledDays() {
        let goal = Goal(title: "Test", weeklyTarget: 7200) // 2 hours weekly
        // Schedule for Monday and Wednesday (2 days)
        goal.setTimes([.morning], forWeekday: 2) // Monday
        goal.setTimes([.evening], forWeekday: 4) // Wednesday
        
        let expected = 7200.0 / 2.0 // 1 hour per scheduled day
        #expect(goal.dailyTargetFromSchedule() == expected)
    }
    
    @Test("Daily target divides by 7 when no schedule")
    func dailyTargetDefaultsToSevenDays() {
        let goal = Goal(title: "Test", weeklyTarget: 7000)
        
        let expected = 7000.0 / 7.0
        #expect(goal.dailyTargetFromSchedule() == expected)
    }
    
    @Test("Daily target handles zero weekly target")
    func dailyTargetHandlesZeroWeekly() {
        let goal = Goal(title: "Test", weeklyTarget: 0)
        
        #expect(goal.dailyTargetFromSchedule() == 0)
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
