//
//  GoalSessionTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Session Tests")
struct GoalSessionTests {

    // MARK: - Initialization Tests

    @Test("GoalSession initializes with title, goal, and day")
    func goalSessionInitializesWithTitleGoalAndDay() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.title == "Test Session")
        #expect(session.goal?.id == goal.id)
        #expect(session.day?.id == day.id)
    }

    @Test("GoalSession generates unique ID")
    func goalSessionGeneratesUniqueID() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session1 = GoalSession(title: "Session 1", goal: goal, day: day)
        let session2 = GoalSession(title: "Session 2", goal: goal, day: day)

        #expect(session1.id != session2.id)
    }

    @Test("GoalSession caches goal ID at creation")
    func goalSessionCachesGoalIDAtCreation() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.goalID == goal.id.uuidString)
    }

    @Test("GoalSession caches daily target at creation")
    func goalSessionCachesDailyTargetAtCreation() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.dailyTarget == 3600) // 7 hours / 7 days = 1 hour
    }

    @Test("GoalSession initializes with active status")
    func goalSessionInitializesWithActiveStatus() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.status == .active)
    }

    // MARK: - Status Tests

    @Test("GoalSession status can be changed")
    func goalSessionStatusCanBeChanged() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        session.status = .suggestion
        #expect(session.status == .suggestion)

        session.status = .skipped
        #expect(session.status == .skipped)

        session.status = .active
        #expect(session.status == .active)
    }

    @Test("GoalSession status enum has correct cases")
    func goalSessionStatusEnumHasCorrectCases() {
        let suggestion = GoalSession.Status.suggestion
        let active = GoalSession.Status.active
        let skipped = GoalSession.Status.skipped

        #expect(suggestion.rawValue == "suggestion")
        #expect(active.rawValue == "active")
        #expect(skipped.rawValue == "skipped")
    }

    // MARK: - Progress Tracking Tests

    @Test("GoalSession elapsedTime is zero with no historical sessions")
    func goalSessionElapsedTimeIsZeroWithNoHistoricalSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.elapsedTime == 0)
    }

    @Test("GoalSession elapsedTime calculates from historical sessions")
    func goalSessionElapsedTimeCalculatesFromHistoricalSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        // Add historical sessions to the day
        let historicalSession1 = HistoricalSession(
            title: "Session 1",
            start: date,
            end: date.addingTimeInterval(1800),
            needsHealthKitRecord: false
        )
        historicalSession1.goalIDs = [session.goalID]

        let historicalSession2 = HistoricalSession(
            title: "Session 2",
            start: date.addingTimeInterval(1800),
            end: date.addingTimeInterval(3600),
            needsHealthKitRecord: false
        )
        historicalSession2.goalIDs = [session.goalID]

        day.add(historicalSession: historicalSession1)
        day.add(historicalSession: historicalSession2)

        // Total should be 3600 seconds (1 hour)
        #expect(session.elapsedTime == 3600)
    }

    @Test("GoalSession hasMetDailyTarget is false when target not met")
    func goalSessionHasMetDailyTargetIsFalseWhenTargetNotMet() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.hasMetDailyTarget == false)
    }

    @Test("GoalSession hasMetDailyTarget is true when elapsed time meets target")
    func goalSessionHasMetDailyTargetIsTrueWhenElapsedTimeMeetsTarget() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        // Add historical session that meets the target
        let historicalSession = HistoricalSession(
            title: "Long Session",
            start: date,
            end: date.addingTimeInterval(3600), // 1 hour
            needsHealthKitRecord: false
        )
        historicalSession.goalIDs = [session.goalID]
        day.add(historicalSession: historicalSession)

        #expect(session.hasMetDailyTarget == true)
    }

    @Test("GoalSession hasMetDailyTarget is true when manually marked complete")
    func goalSessionHasMetDailyTargetIsTrueWhenManuallyMarkedComplete() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        session.markedComplete = true

        #expect(session.hasMetDailyTarget == true)
    }

    @Test("GoalSession formattedTime shows elapsed and target")
    func goalSessionFormattedTimeShowsElapsedAndTarget() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        let formatted = session.formattedTime
        #expect(formatted.contains("/"))
    }

    // MARK: - HealthKit Integration Tests

    @Test("GoalSession healthKitTime is zero by default")
    func goalSessionHealthKitTimeIsZeroByDefault() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.healthKitTime == 0)
    }

    @Test("GoalSession can update HealthKit time")
    func goalSessionCanUpdateHealthKitTime() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        session.updateHealthKitTime(1800)

        #expect(session.healthKitTime == 1800)
    }

    // MARK: - Planning Details Tests

    @Test("GoalSession planning details are nil by default")
    func goalSessionPlanningDetailsAreNilByDefault() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.plannedStartTime == nil)
        #expect(session.plannedDuration == nil)
        #expect(session.plannedPriority == nil)
        #expect(session.plannedReasoning == nil)
        #expect(session.recommendationReasons.isEmpty)
    }

    @Test("GoalSession can update planning details")
    func goalSessionCanUpdatePlanningDetails() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        let startTime = Date()
        session.updatePlanningDetails(
            startTime: startTime,
            duration: 60,
            priority: 1,
            reasoning: "High priority task",
            reasons: [.userPriority, .weeklyProgress]
        )

        #expect(session.plannedStartTime == startTime)
        #expect(session.plannedDuration == 60)
        #expect(session.plannedPriority == 1)
        #expect(session.plannedReasoning == "High priority task")
        #expect(session.recommendationReasons.count == 2)
        #expect(session.recommendationReasons.contains(.userPriority))
        #expect(session.recommendationReasons.contains(.weeklyProgress))
    }

    @Test("GoalSession can clear planning details")
    func goalSessionCanClearPlanningDetails() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        // Set planning details
        session.updatePlanningDetails(
            startTime: Date(),
            duration: 60,
            priority: 1,
            reasoning: "Test",
            reasons: [.userPriority]
        )

        // Clear them
        session.clearPlanningDetails()

        #expect(session.plannedStartTime == nil)
        #expect(session.plannedDuration == nil)
        #expect(session.plannedPriority == nil)
        #expect(session.plannedReasoning == nil)
        #expect(session.recommendationReasons.isEmpty)
    }

    @Test("GoalSession formattedPlannedStartTime returns nil when no start time")
    func goalSessionFormattedPlannedStartTimeReturnsNilWhenNoStartTime() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.formattedPlannedStartTime == nil)
    }

    @Test("GoalSession formattedPlannedStartTime returns formatted string")
    func goalSessionFormattedPlannedStartTimeReturnsFormattedString() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        let startTime = Date()
        session.updatePlanningDetails(
            startTime: startTime,
            duration: 60,
            priority: 1,
            reasoning: "Test"
        )

        let formatted = session.formattedPlannedStartTime
        #expect(formatted != nil)
        #expect(!formatted!.isEmpty)
    }

    // MARK: - Widget Pinning Tests

    @Test("GoalSession pinnedInWidget is false by default")
    func goalSessionPinnedInWidgetIsFalseByDefault() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.pinnedInWidget == false)
    }

    @Test("GoalSession pinnedInWidget can be toggled")
    func goalSessionPinnedInWidgetCanBeToggled() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        session.pinnedInWidget = true
        #expect(session.pinnedInWidget == true)

        session.pinnedInWidget = false
        #expect(session.pinnedInWidget == false)
    }

    // MARK: - Daily Target Update Tests

    @Test("GoalSession can update daily target from goal")
    func goalSessionCanUpdateDailyTargetFromGoal() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.dailyTarget == 3600)

        // Change goal's weekly target
        goal.weeklyTarget = 7200 * 7 // 2 hours per day

        // Update session's daily target
        session.updateDailyTarget()

        #expect(session.dailyTarget == 7200)
    }

    @Test("GoalSession updateDailyTarget handles nil goal")
    func goalSessionUpdateDailyTargetHandlesNilGoal() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        // Remove goal reference
        session.goal = nil

        // Should not crash
        session.updateDailyTarget()

        #expect(session.dailyTarget == 0)
    }

    // MARK: - Recommendation Reasons Tests

    @Test("GoalSession can store multiple recommendation reasons")
    func goalSessionCanStoreMultipleRecommendationReasons() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal")
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        session.recommendationReasons = [
            .weeklyProgress,
            .weather,
            .preferredTime,
            .quickFinish
        ]

        #expect(session.recommendationReasons.count == 4)
        #expect(session.recommendationReasons.contains(.weeklyProgress))
        #expect(session.recommendationReasons.contains(.weather))
        #expect(session.recommendationReasons.contains(.preferredTime))
        #expect(session.recommendationReasons.contains(.quickFinish))
    }

    // MARK: - SessionProgressProvider Tests

    @Test("GoalSession conforms to SessionProgressProvider")
    func goalSessionConformsToSessionProgressProvider() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        // Should have elapsedTime and dailyTarget properties
        let provider: SessionProgressProvider = session
        #expect(provider.elapsedTime >= 0)
        #expect(provider.dailyTarget >= 0)
    }

    // MARK: - Edge Cases Tests

    @Test("GoalSession handles zero daily target")
    func goalSessionHandlesZeroDailyTarget() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 0)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.dailyTarget == 0)
        #expect(session.hasMetDailyTarget == false)
    }

    @Test("GoalSession markedComplete overrides elapsed time check")
    func goalSessionMarkedCompleteOverridesElapsedTimeCheck() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        // No elapsed time, but marked complete
        session.markedComplete = true

        #expect(session.elapsedTime == 0)
        #expect(session.hasMetDailyTarget == true)
    }

    @Test("GoalSession handles very large daily targets")
    func goalSessionHandlesVeryLargeDailyTargets() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 100) // 100 hours
        let day = Day(start: date, end: date, calendar: calendar)

        let session = GoalSession(title: "Test Session", goal: goal, day: day)

        #expect(session.dailyTarget > 0)
        #expect(session.hasMetDailyTarget == false)
    }
    
    // MARK: - Scheduled Days Tests
    
    @Test("GoalSession daily target is zero on unscheduled days")
    func goalSessionDailyTargetIsZeroOnUnscheduledDays() {
        let calendar = Calendar.current
        
        // Create a date that is a Sunday (weekday 1)
        var components = calendar.dateComponents([.year, .month, .day, .weekday], from: Date())
        components.weekday = 1 // Sunday
        let sunday = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)!
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7) // 7 hours per week
        // Schedule only Monday-Friday (weekdays 2-6)
        goal.dayTimeSchedule = [
            "2": [TimeOfDay.morning.rawValue],
            "3": [TimeOfDay.morning.rawValue],
            "4": [TimeOfDay.morning.rawValue],
            "5": [TimeOfDay.morning.rawValue],
            "6": [TimeOfDay.morning.rawValue]
        ]
        
        let day = Day(start: sunday, end: sunday, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        // Sunday is not scheduled, so daily target should be 0
        #expect(session.dailyTarget == 0)
    }
    
    @Test("GoalSession daily target is correct on scheduled days")
    func goalSessionDailyTargetIsCorrectOnScheduledDays() {
        let calendar = Calendar.current
        
        // Create a date that is a Monday (weekday 2)
        var components = calendar.dateComponents([.year, .month, .day, .weekday], from: Date())
        components.weekday = 2 // Monday
        let monday = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)!
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 5) // 5 hours per week
        // Schedule only Monday-Friday (weekdays 2-6)
        goal.dayTimeSchedule = [
            "2": [TimeOfDay.morning.rawValue],
            "3": [TimeOfDay.morning.rawValue],
            "4": [TimeOfDay.morning.rawValue],
            "5": [TimeOfDay.morning.rawValue],
            "6": [TimeOfDay.morning.rawValue]
        ]
        
        let day = Day(start: monday, end: monday, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        // Monday is scheduled, and there are 5 scheduled days total
        // 5 hours / 5 days = 1 hour per day = 3600 seconds
        #expect(session.dailyTarget == 3600)
    }
    
    @Test("GoalSession daily target uses all 7 days when no schedule is set")
    func goalSessionDailyTargetUsesAll7DaysWhenNoScheduleIsSet() {
        let calendar = Calendar.current
        let date = Date()
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7) // 7 hours per week
        // No schedule set (hasSchedule will be false)
        
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        // No schedule means all 7 days are active
        // 7 hours / 7 days = 1 hour per day = 3600 seconds
        #expect(session.dailyTarget == 3600)
    }
    
    @Test("GoalSession updateDailyTarget respects scheduled days")
    func goalSessionUpdateDailyTargetRespectsScheduledDays() {
        let calendar = Calendar.current
        
        // Create a date that is a Saturday (weekday 7)
        var components = calendar.dateComponents([.year, .month, .day, .weekday], from: Date())
        components.weekday = 7 // Saturday
        let saturday = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)!
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 5) // 5 hours per week
        // Initially no schedule
        
        let day = Day(start: saturday, end: saturday, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        // Should initially divide by 7 (no schedule)
        let initialTarget = session.dailyTarget
        #expect(initialTarget > 0)
        
        // Now add a schedule that excludes Saturday (weekday 7)
        goal.dayTimeSchedule = [
            "2": [TimeOfDay.morning.rawValue], // Monday
            "3": [TimeOfDay.morning.rawValue], // Tuesday
            "4": [TimeOfDay.morning.rawValue], // Wednesday
            "5": [TimeOfDay.morning.rawValue], // Thursday
            "6": [TimeOfDay.morning.rawValue]  // Friday
        ]
        
        // Update the session's daily target
        session.updateDailyTarget()
        
        // Saturday is not in the schedule, so daily target should be 0
        #expect(session.dailyTarget == 0)
    }
}
