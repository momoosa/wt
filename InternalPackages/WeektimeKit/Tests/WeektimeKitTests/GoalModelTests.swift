//
//  GoalModelTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Model Tests")
struct GoalModelTests {

    // MARK: - Initialization Tests

    @Test("Goal initializes with title")
    func goalInitializesWithTitle() {
        let goal = Goal(title: "Read Books")

        #expect(goal.title == "Read Books")
        #expect(goal.status == .active)
        #expect(goal.weeklyTarget == 0)
    }

    @Test("Goal initializes with weekly target")
    func goalInitializesWithWeeklyTarget() {
        let goal = Goal(title: "Exercise", weeklyTarget: 3600)

        #expect(goal.weeklyTarget == 3600)
    }

    @Test("Goal generates unique ID")
    func goalGeneratesUniqueID() {
        let goal1 = Goal(title: "Goal 1")
        let goal2 = Goal(title: "Goal 2")

        #expect(goal1.id != goal2.id)
    }

    // MARK: - Status Tests

    @Test("Goal status enum has correct cases")
    func goalStatusEnumHasCorrectCases() {
        let suggestion = Goal.Status.suggestion
        let active = Goal.Status.active
        let archived = Goal.Status.archived

        #expect(suggestion.rawValue == "suggestion")
        #expect(active.rawValue == "active")
        #expect(archived.rawValue == "archived")
    }

    @Test("Goal status can be changed")
    func goalStatusCanBeChanged() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.status == .active)

        goal.status = .archived
        #expect(goal.status == .archived)

        goal.status = .suggestion
        #expect(goal.status == .suggestion)
    }

    // MARK: - Schedule Management Tests

    @Test("Goal has no schedule by default")
    func goalHasNoScheduleByDefault() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.hasSchedule == false)
        #expect(goal.scheduledWeekdays.isEmpty)
    }

    @Test("Goal can set times for weekday")
    func goalCanSetTimesForWeekday() {
        let goal = Goal(title: "Morning Routine")

        goal.setTimes([.morning], forWeekday: 2) // Monday

        #expect(goal.hasSchedule == true)
        #expect(goal.scheduledWeekdays.contains(2))
    }

    @Test("Goal retrieves times for weekday correctly")
    func goalRetrievesTimesForWeekdayCorrectly() {
        let goal = Goal(title: "Exercise")

        goal.setTimes([.morning, .evening], forWeekday: 2)

        let times = goal.timesForWeekday(2)
        #expect(times.count == 2)
        #expect(times.contains(.morning))
        #expect(times.contains(.evening))
    }

    @Test("Goal returns empty set for unscheduled weekday")
    func goalReturnsEmptySetForUnscheduledWeekday() {
        let goal = Goal(title: "Test Goal")

        let times = goal.timesForWeekday(5)
        #expect(times.isEmpty)
    }

    @Test("Goal removes schedule when setting empty times")
    func goalRemovesScheduleWhenSettingEmptyTimes() {
        let goal = Goal(title: "Test Goal")

        goal.setTimes([.morning], forWeekday: 2)
        #expect(goal.hasSchedule == true)

        goal.setTimes([], forWeekday: 2)
        #expect(goal.hasSchedule == false)
    }

    @Test("Goal isScheduled returns correct value")
    func goalIsScheduledReturnsCorrectValue() {
        let goal = Goal(title: "Test Goal")

        goal.setTimes([.morning, .afternoon], forWeekday: 3)

        #expect(goal.isScheduled(weekday: 3, time: .morning) == true)
        #expect(goal.isScheduled(weekday: 3, time: .evening) == false)
        #expect(goal.isScheduled(weekday: 4, time: .morning) == false)
    }

    @Test("Goal scheduledWeekdays returns sorted weekdays")
    func goalScheduledWeekdaysReturnsSortedWeekdays() {
        let goal = Goal(title: "Test Goal")

        goal.setTimes([.morning], forWeekday: 5)
        goal.setTimes([.evening], forWeekday: 2)
        goal.setTimes([.afternoon], forWeekday: 7)

        let weekdays = goal.scheduledWeekdays
        #expect(weekdays == [2, 5, 7])
    }

    // MARK: - Schedule Summary Tests

    @Test("Goal scheduleSummary shows Anytime for no schedule")
    func goalScheduleSummaryShowsAnytimeForNoSchedule() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.scheduleSummary == "Anytime")
    }

    @Test("Goal scheduleSummary shows weekday and time")
    func goalScheduleSummaryShowsWeekdayAndTime() {
        let goal = Goal(title: "Test Goal")

        goal.setTimes([.morning], forWeekday: 2) // Monday

        let summary = goal.scheduleSummary
        #expect(summary.contains("Mon"))
        #expect(summary.lowercased().contains("morning"))
    }

    @Test("Goal scheduleSummary includes multiple times")
    func goalScheduleSummaryIncludesMultipleTimes() {
        let goal = Goal(title: "Test Goal")

        goal.setTimes([.morning, .evening], forWeekday: 2)

        let summary = goal.scheduleSummary
        #expect(summary.contains("Mon"))
        #expect(summary.lowercased().contains("morning"))
        #expect(summary.lowercased().contains("evening"))
    }

    // MARK: - Daily Target Calculation Tests

    @Test("Goal dailyTargetFromSchedule divides by 7 with no schedule")
    func goalDailyTargetFromScheduleDividesBy7WithNoSchedule() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)

        let dailyTarget = goal.dailyTargetFromSchedule()
        #expect(dailyTarget == 3600)
    }

    @Test("Goal dailyTargetFromSchedule uses dailyMinimum if set")
    func goalDailyTargetFromScheduleUsesDailyMinimumIfSet() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 7)
        goal.dailyMinimum = 1800

        let dailyTarget = goal.dailyTargetFromSchedule()
        #expect(dailyTarget == 1800)
    }

    @Test("Goal dailyTargetFromSchedule divides by scheduled days")
    func goalDailyTargetFromScheduleDividesByScheduledDays() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 5)

        goal.setTimes([.morning], forWeekday: 2) // Monday
        goal.setTimes([.morning], forWeekday: 3) // Tuesday
        goal.setTimes([.morning], forWeekday: 4) // Wednesday
        goal.setTimes([.morning], forWeekday: 5) // Thursday
        goal.setTimes([.morning], forWeekday: 6) // Friday

        let dailyTarget = goal.dailyTargetFromSchedule()
        #expect(dailyTarget == 3600) // 5 hours / 5 days = 1 hour per day
    }

    @Test("Goal dailyTargetFromSchedule handles single scheduled day")
    func goalDailyTargetFromScheduleHandlesSingleScheduledDay() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)

        goal.setTimes([.morning], forWeekday: 1)

        let dailyTarget = goal.dailyTargetFromSchedule()
        #expect(dailyTarget == 3600)
    }

    // MARK: - HealthKit Integration Tests

    @Test("Goal healthKitMetric is nil by default")
    func goalHealthKitMetricIsNilByDefault() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.healthKitMetric == nil)
        #expect(goal.healthKitSyncEnabled == false)
    }

    @Test("Goal healthKitMetric can be set and retrieved")
    func goalHealthKitMetricCanBeSetAndRetrieved() {
        let goal = Goal(title: "Exercise")

        goal.healthKitMetric = .appleExerciseTime
        #expect(goal.healthKitMetric == .appleExerciseTime)

        goal.healthKitMetric = .mindfulMinutes
        #expect(goal.healthKitMetric == .mindfulMinutes)
    }

    @Test("Goal healthKitMetric can be cleared")
    func goalHealthKitMetricCanBeCleared() {
        let goal = Goal(title: "Exercise")

        goal.healthKitMetric = .appleExerciseTime
        #expect(goal.healthKitMetric != nil)

        goal.healthKitMetric = nil
        #expect(goal.healthKitMetric == nil)
    }

    // MARK: - Notification Settings Tests

    @Test("Goal notification settings default to false")
    func goalNotificationSettingsDefaultToFalse() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.notificationsEnabled == false)
        #expect(goal.scheduleNotificationsEnabled == false)
        #expect(goal.completionNotificationsEnabled == false)
    }

    @Test("Goal notification settings can be enabled")
    func goalNotificationSettingsCanBeEnabled() {
        let goal = Goal(title: "Test Goal")

        goal.notificationsEnabled = true
        goal.scheduleNotificationsEnabled = true
        goal.completionNotificationsEnabled = true

        #expect(goal.notificationsEnabled == true)
        #expect(goal.scheduleNotificationsEnabled == true)
        #expect(goal.completionNotificationsEnabled == true)
    }

    // MARK: - Weather Triggers Tests

    @Test("Goal has no weather triggers by default")
    func goalHasNoWeatherTriggersByDefault() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.hasWeatherTriggers == false)
        #expect(goal.weatherEnabled == false)
    }

    @Test("Goal hasWeatherTriggers returns true when weather conditions set")
    func goalHasWeatherTriggersReturnsTrueWhenConditionsSet() {
        let goal = Goal(title: "Test Goal")

        goal.weatherEnabled = true
        goal.weatherConditions = ["sunny"]

        #expect(goal.hasWeatherTriggers == true)
    }

    @Test("Goal hasWeatherTriggers returns true when temperature range set")
    func goalHasWeatherTriggersReturnsTrueWhenTemperatureSet() {
        let goal = Goal(title: "Test Goal")

        goal.weatherEnabled = true
        goal.minTemperature = 15.0
        goal.maxTemperature = 25.0

        #expect(goal.hasWeatherTriggers == true)
    }

    @Test("Goal weatherConditionsTyped converts strings to enums")
    func goalWeatherConditionsTypedConvertsStringsToEnums() {
        let goal = Goal(title: "Test Goal")

        goal.weatherConditions = ["clear", "partlyCloudy"]

        let typed = goal.weatherConditionsTyped
        #expect(typed?.count == 2)
        #expect(typed?.contains(.clear) == true)
        #expect(typed?.contains(.partlyCloudy) == true)
    }

    @Test("Goal temperatureRange returns range when both min and max set")
    func goalTemperatureRangeReturnsRangeWhenBothSet() {
        let goal = Goal(title: "Test Goal")

        goal.minTemperature = 10.0
        goal.maxTemperature = 20.0

        let range = goal.temperatureRange
        #expect(range?.lowerBound == 10.0)
        #expect(range?.upperBound == 20.0)
    }

    @Test("Goal temperatureRange returns nil when only one boundary set")
    func goalTemperatureRangeReturnsNilWhenOnlyOneBoundarySet() {
        let goal = Goal(title: "Test Goal")

        goal.minTemperature = 10.0
        #expect(goal.temperatureRange == nil)

        goal.minTemperature = nil
        goal.maxTemperature = 20.0
        #expect(goal.temperatureRange == nil)
    }

    // MARK: - Notes and Resources Tests

    @Test("Goal can have notes")
    func goalCanHaveNotes() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.notes == nil)

        goal.notes = "Important notes about this goal"
        #expect(goal.notes == "Important notes about this goal")
    }

    @Test("Goal can have link")
    func goalCanHaveLink() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.link == nil)

        goal.link = "https://example.com/tutorial"
        #expect(goal.link == "https://example.com/tutorial")
    }

    @Test("Goal can have icon name")
    func goalCanHaveIconName() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.iconName == nil)

        goal.iconName = "book.fill"
        #expect(goal.iconName == "book.fill")
    }

    // MARK: - Preferred Times of Day Tests

    @Test("Goal preferredTimesOfDay is empty by default")
    func goalPreferredTimesOfDayIsEmptyByDefault() {
        let goal = Goal(title: "Test Goal")

        #expect(goal.preferredTimesOfDay.isEmpty)
    }

    @Test("Goal can store preferred times of day")
    func goalCanStorePreferredTimesOfDay() {
        let goal = Goal(title: "Test Goal")

        goal.preferredTimesOfDay = ["morning", "evening"]

        #expect(goal.preferredTimesOfDay.count == 2)
        #expect(goal.preferredTimesOfDay.contains("morning"))
        #expect(goal.preferredTimesOfDay.contains("evening"))
    }

    // MARK: - Edge Cases Tests

    @Test("Goal handles zero weekly target")
    func goalHandlesZeroWeeklyTarget() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 0)

        let dailyTarget = goal.dailyTargetFromSchedule()
        #expect(dailyTarget == 0)
    }

    @Test("Goal handles very large weekly target")
    func goalHandlesVeryLargeWeeklyTarget() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600 * 100) // 100 hours

        let dailyTarget = goal.dailyTargetFromSchedule()
        #expect(dailyTarget > 0)
        #expect(dailyTarget == 3600 * 100 / 7)
    }

    @Test("Goal can schedule all days of week")
    func goalCanScheduleAllDaysOfWeek() {
        let goal = Goal(title: "Test Goal")

        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }

        #expect(goal.scheduledWeekdays.count == 7)
        #expect(goal.hasSchedule == true)
    }

    @Test("Goal can schedule all times of day")
    func goalCanScheduleAllTimesOfDay() {
        let goal = Goal(title: "Test Goal")

        goal.setTimes([.morning, .midday, .afternoon, .evening, .night], forWeekday: 2)

        let times = goal.timesForWeekday(2)
        #expect(times.count == 5)
    }
}
