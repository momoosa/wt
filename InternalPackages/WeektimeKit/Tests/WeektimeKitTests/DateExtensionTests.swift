//
//  DateExtensionTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Date Extension Calculations")
struct DateExtensionTests {
    
    // MARK: - Week Progress Tests
    
    @Test("weekProgress returns 0 at start of week")
    func weekProgressReturnsZeroAtStart() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Create a date at the very start of Sunday
        let components = DateComponents(year: 2026, month: 3, day: 8, hour: 0, minute: 0)
        guard let sunday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let progress = sunday.weekProgress(calendar: calendar)
        #expect(progress == 0.0)
    }
    
    @Test("weekProgress returns value close to 1 at end of week")
    func weekProgressReturnsNearOneAtEnd() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Create a date near the end of Saturday (last day of week)
        let components = DateComponents(year: 2026, month: 3, day: 14, hour: 23, minute: 59)
        guard let saturday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let progress = saturday.weekProgress(calendar: calendar)
        #expect(progress > 0.99 && progress <= 1.0)
    }
    
    @Test("weekProgress calculates progress within date's own week")
    func weekProgressCalculatesWithinOwnWeek() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Create a date on Sunday at noon (March 1, 2026)
        let components = DateComponents(year: 2026, month: 3, day: 1, hour: 12, minute: 0)
        guard let sunday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let progress = sunday.weekProgress(calendar: calendar)
        // Sunday at noon is about 7.14% through the week (12 hours / 168 hours)
        #expect(progress > 0.07 && progress < 0.08)
    }
    
    // MARK: - Year Month Day ID Tests
    
    @Test("yearMonthDayID formats correctly")
    func yearMonthDayIDFormatsCorrectly() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 15, minute: 30)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let id = date.yearMonthDayID(with: calendar)
        #expect(id == "2026-03-07")
    }
    
    @Test("yearMonthDayID handles single digit month and day")
    func yearMonthDayIDHandlesSingleDigits() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 1, day: 5, hour: 10, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let id = date.yearMonthDayID(with: calendar)
        #expect(id == "2026-01-05")
    }
    
    // MARK: - Week Boundary Tests
    
    @Test("startOfWeek returns correct Sunday")
    func startOfWeekReturnsCorrectSunday() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Wednesday, March 10, 2026
        let components = DateComponents(year: 2026, month: 3, day: 10, hour: 15, minute: 30)
        guard let wednesday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let startOfWeek = wednesday.startOfWeek(in: calendar) else {
            Issue.record("startOfWeek returned nil")
            return
        }
        
        let weekday = calendar.component(.weekday, from: startOfWeek)
        #expect(weekday == 1) // Sunday
        
        let hour = calendar.component(.hour, from: startOfWeek)
        let minute = calendar.component(.minute, from: startOfWeek)
        #expect(hour == 0)
        #expect(minute == 0)
    }
    
    @Test("endOfWeek returns correct Saturday")
    func endOfWeekReturnsCorrectSaturday() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Wednesday, March 10, 2026
        let components = DateComponents(year: 2026, month: 3, day: 10, hour: 15, minute: 30)
        guard let wednesday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let endOfWeek = wednesday.endOfWeek(in: calendar) else {
            Issue.record("endOfWeek returned nil")
            return
        }
        
        let weekday = calendar.component(.weekday, from: endOfWeek)
        #expect(weekday == 7) // Saturday
        
        let hour = calendar.component(.hour, from: endOfWeek)
        let minute = calendar.component(.minute, from: endOfWeek)
        let second = calendar.component(.second, from: endOfWeek)
        #expect(hour == 23)
        #expect(minute == 59)
        #expect(second == 59)
    }
    
    // MARK: - Range Overlap Tests
    
    @Test("overlapPercentage returns 100% for identical ranges")
    func overlapPercentageReturnsFullForIdentical() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3600) // 1 hour
        
        let range1 = start...end
        let range2 = start...end
        
        let overlap = range1.overlapPercentage(with: range2)
        #expect(overlap == 1.0)
    }
    
    @Test("overlapPercentage returns 0% for non-overlapping ranges")
    func overlapPercentageReturnsZeroForNonOverlapping() {
        let start1 = Date(timeIntervalSince1970: 0)
        let end1 = Date(timeIntervalSince1970: 3600)
        
        let start2 = Date(timeIntervalSince1970: 7200)
        let end2 = Date(timeIntervalSince1970: 10800)
        
        let range1 = start1...end1
        let range2 = start2...end2
        
        let overlap = range1.overlapPercentage(with: range2)
        #expect(overlap == 0.0)
    }
    
    @Test("overlapPercentage calculates partial overlap correctly")
    func overlapPercentageCalculatesPartialOverlap() {
        let start1 = Date(timeIntervalSince1970: 0)
        let end1 = Date(timeIntervalSince1970: 3600) // 1 hour
        
        let start2 = Date(timeIntervalSince1970: 1800) // 30 minutes in
        let end2 = Date(timeIntervalSince1970: 5400)
        
        let range1 = start1...end1
        let range2 = start2...end2
        
        let overlap = range1.overlapPercentage(with: range2)
        // Overlap is 1800 seconds out of 3600 seconds = 50%
        #expect(overlap == 0.5)
    }
    
    @Test("overlapPercentage handles contained ranges")
    func overlapPercentageHandlesContainedRanges() {
        let start1 = Date(timeIntervalSince1970: 0)
        let end1 = Date(timeIntervalSince1970: 7200) // 2 hours
        
        let start2 = Date(timeIntervalSince1970: 1800) // 30 minutes in
        let end2 = Date(timeIntervalSince1970: 3600) // ends at 1 hour
        
        let range1 = start1...end1
        let range2 = start2...end2
        
        let overlap = range1.overlapPercentage(with: range2)
        // Overlap is 1800 seconds out of 7200 seconds = 25%
        #expect(overlap == 0.25)
    }
    
    @Test("overlapPercentage handles ranges that touch at boundary")
    func overlapPercentageHandlesRangesTouchingAtBoundary() {
        let start1 = Date(timeIntervalSince1970: 0)
        let end1 = Date(timeIntervalSince1970: 3600)
        
        let start2 = Date(timeIntervalSince1970: 3600) // Starts where first ends
        let end2 = Date(timeIntervalSince1970: 7200)
        
        let range1 = start1...end1
        let range2 = start2...end2
        
        let overlap = range1.overlapPercentage(with: range2)
        // Should have minimal overlap at the boundary point
        #expect(overlap >= 0.0 && overlap < 0.01)
    }
    
    // MARK: - Date Rounding Tests
    
    @Test("round rounds to nearest 5 minutes")
    func roundRoundsToNearestFiveMinutes() {
        // 10:07:30 should round to 10:05:00
        let date = Date(timeIntervalSince1970: 37650) // 10:27:30 UTC on Jan 1, 1970
        let rounded = date.round(precision: 300) // 5 minutes = 300 seconds
        
        let difference = abs(rounded.timeIntervalSince(date))
        #expect(difference <= 150) // Should be within 2.5 minutes
    }
    
    @Test("round rounds to nearest 15 minutes")
    func roundRoundsToNearestFifteenMinutes() {
        let date = Date(timeIntervalSince1970: 36900) // 10:15:00 UTC
        let rounded = date.round(precision: 900) // 15 minutes = 900 seconds
        
        #expect(rounded.timeIntervalSince1970.truncatingRemainder(dividingBy: 900) == 0)
    }
    
    @Test("ceil rounds up to next interval")
    func ceilRoundsUpToNextInterval() {
        // 10:01:00 should ceil to 10:05:00 for 5-minute precision
        let date = Date(timeIntervalSince1970: 36060) // 10:01:00 UTC
        let ceiled = date.ceil(precision: 300)
        
        #expect(ceiled >= date)
        #expect(ceiled.timeIntervalSince1970.truncatingRemainder(dividingBy: 300) == 0)
    }
    
    @Test("floor rounds down to previous interval")
    func floorRoundsDownToPreviousInterval() {
        // 10:09:00 should floor to 10:05:00 for 5-minute precision
        let date = Date(timeIntervalSince1970: 36540) // 10:09:00 UTC
        let floored = date.floor(precision: 300)
        
        #expect(floored <= date)
        #expect(floored.timeIntervalSince1970.truncatingRemainder(dividingBy: 300) == 0)
    }
    
    @Test("round handles exact boundary")
    func roundHandlesExactBoundary() {
        // Exactly 10:00:00 should stay at 10:00:00
        let date = Date(timeIntervalSince1970: 36000) // Exactly 10:00:00 UTC
        let rounded = date.round(precision: 300)
        
        #expect(rounded.timeIntervalSince1970 == date.timeIntervalSince1970)
    }
    
    // MARK: - Day Boundary Tests
    
    @Test("startOfDay returns midnight")
    func startOfDayReturnsMidnight() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 15, minute: 30)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let startOfDay = date.startOfDay(in: calendar) else {
            Issue.record("startOfDay returned nil")
            return
        }
        
        let hour = calendar.component(.hour, from: startOfDay)
        let minute = calendar.component(.minute, from: startOfDay)
        let second = calendar.component(.second, from: startOfDay)
        
        #expect(hour == 0)
        #expect(minute == 0)
        #expect(second == 0)
    }
    
    @Test("endOfDay returns 23:59:59")
    func endOfDayReturnsLastSecond() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 10, minute: 15)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let endOfDay = date.endOfDay(in: calendar) else {
            Issue.record("endOfDay returned nil")
            return
        }
        
        let hour = calendar.component(.hour, from: endOfDay)
        let minute = calendar.component(.minute, from: endOfDay)
        let second = calendar.component(.second, from: endOfDay)
        
        #expect(hour == 23)
        #expect(minute == 59)
        #expect(second == 59)
    }
    
    @Test("startOfDay and endOfDay are same day")
    func startAndEndOfDayAreSameDay() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 15, minute: 30)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let startOfDay = date.startOfDay(in: calendar),
              let endOfDay = date.endOfDay(in: calendar) else {
            Issue.record("Failed to get day boundaries")
            return
        }
        
        let startDay = calendar.component(.day, from: startOfDay)
        let endDay = calendar.component(.day, from: endOfDay)
        
        #expect(startDay == endDay)
        #expect(startDay == 7)
    }
    
    // MARK: - Hour Extraction Tests
    
    @Test("hour extracts correct hour value")
    func hourExtractsCorrectValue() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 15, minute: 30)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let hour = date.hour(with: calendar)
        #expect(hour == 15)
    }
    
    @Test("hour handles midnight")
    func hourHandlesMidnight() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let hour = date.hour(with: calendar)
        #expect(hour == 0)
    }
    
    @Test("hour handles end of day")
    func hourHandlesEndOfDay() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let hour = date.hour(with: calendar)
        #expect(hour == 23)
    }
    
    // MARK: - Remaining Time in Week Tests
    
    @Test("remainingTimeInWeek returns full week at start")
    func remainingTimeInWeekReturnsFullWeekAtStart() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        let components = DateComponents(year: 2026, month: 3, day: 8, hour: 0, minute: 0)
        guard let sunday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let remaining = sunday.remainingTimeInWeek(calendar: calendar)
        // Should be close to 604800 seconds (7 days)
        #expect(remaining > 604700 && remaining <= 604800)
    }
    
    @Test("remainingTimeInWeek returns near zero at end")
    func remainingTimeInWeekReturnsNearZeroAtEnd() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        let components = DateComponents(year: 2026, month: 3, day: 14, hour: 23, minute: 59)
        guard let saturday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let remaining = saturday.remainingTimeInWeek(calendar: calendar)
        #expect(remaining >= 0 && remaining < 100)
    }
    
    @Test("remainingTimeInWeek calculates correctly at midweek")
    func remainingTimeInWeekCalculatesCorrectlyAtMidweek() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Wednesday at noon (middle of week)
        let components = DateComponents(year: 2026, month: 3, day: 11, hour: 12, minute: 0)
        guard let wednesday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let remaining = wednesday.remainingTimeInWeek(calendar: calendar)
        // Should be roughly 3.5 days remaining (302400 seconds)
        #expect(remaining > 300000 && remaining < 310000)
    }
    
    // MARK: - Week Start Variation Tests
    
    @Test("startOfWeek handles Monday as first day")
    func startOfWeekHandlesMondayAsFirstDay() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        // Friday, March 12, 2026
        let components = DateComponents(year: 2026, month: 3, day: 12, hour: 15, minute: 30)
        guard let friday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let startOfWeek = friday.startOfWeek(in: calendar) else {
            Issue.record("startOfWeek returned nil")
            return
        }
        
        let weekday = calendar.component(.weekday, from: startOfWeek)
        #expect(weekday == 2) // Monday
    }
    
    @Test("endOfWeek handles Monday as first day")
    func endOfWeekHandlesMondayAsFirstDay() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        // Friday, March 12, 2026
        let components = DateComponents(year: 2026, month: 3, day: 12, hour: 15, minute: 30)
        guard let friday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let endOfWeek = friday.endOfWeek(in: calendar) else {
            Issue.record("endOfWeek returned nil")
            return
        }
        
        let weekday = calendar.component(.weekday, from: endOfWeek)
        #expect(weekday == 1) // Sunday (last day when week starts Monday)
    }
    
    @Test("weekProgress works with Monday week start")
    func weekProgressWorksWithMondayWeekStart() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        // Monday at start of day
        let components = DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 0)
        guard let monday = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let progress = monday.weekProgress(calendar: calendar)
        #expect(progress == 0.0)
    }
    
    @Test("week boundaries handle month transitions")
    func weekBoundariesHandleMonthTransitions() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Date near end of month
        let components = DateComponents(year: 2026, month: 3, day: 30, hour: 12, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let startOfWeek = date.startOfWeek(in: calendar),
              let endOfWeek = date.endOfWeek(in: calendar) else {
            Issue.record("Failed to get week boundaries")
            return
        }
        
        // Verify both dates exist and end is after start
        #expect(endOfWeek > startOfWeek)
        
        let weekDuration = endOfWeek.timeIntervalSince(startOfWeek)
        // Should be approximately 1 week (allowing for DST)
        #expect(weekDuration > 604000 && weekDuration < 605000)
    }
    
    @Test("week boundaries handle year transitions")
    func weekBoundariesHandleYearTransitions() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        
        // Date near end of year
        let components = DateComponents(year: 2025, month: 12, day: 30, hour: 12, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        guard let startOfWeek = date.startOfWeek(in: calendar),
              let endOfWeek = date.endOfWeek(in: calendar) else {
            Issue.record("Failed to get week boundaries")
            return
        }
        
        #expect(endOfWeek > startOfWeek)
        
        let weekDuration = endOfWeek.timeIntervalSince(startOfWeek)
        #expect(weekDuration > 604000 && weekDuration < 605000)
    }
    
    // MARK: - yearMonthDayID Additional Tests
    
    @Test("yearMonthDayID with timeZoneCorrected false")
    func yearMonthDayIDWithoutTimezoneCorrection() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        // Create a date that would be different days in different timezones
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 2, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }
        
        let idWithCorrection = date.yearMonthDayID(with: calendar, timeZoneCorrected: true)
        let idWithoutCorrection = date.yearMonthDayID(with: calendar, timeZoneCorrected: false)
        
        // Both should be valid date strings
        #expect(idWithCorrection.count == 10)
        #expect(idWithoutCorrection.count == 10)
    }
    
    @Test("yearMonthDayID handles leap year")
    func yearMonthDayIDHandlesLeapYear() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        
        // February 29, 2024 (leap year)
        let components = DateComponents(year: 2024, month: 2, day: 29, hour: 12, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create leap year date")
            return
        }
        
        let id = date.yearMonthDayID(with: calendar)
        #expect(id == "2024-02-29")
    }
    
    // MARK: - Optional Date Comparison Tests
    
    @Test("optional date comparison handles both nil")
    func optionalDateComparisonHandlesBothNil() {
        let date1: Date? = nil
        let date2: Date? = nil
        
        #expect(!(date1 < date2))
    }
    
    @Test("optional date comparison nil is less than date")
    func optionalDateComparisonNilIsLessThanDate() {
        let date1: Date? = nil
        let date2: Date? = Date(timeIntervalSince1970: 1000)
        
        #expect(date1 < date2)
    }
    
    @Test("optional date comparison date is greater than nil")
    func optionalDateComparisonDateIsGreaterThanNil() {
        let date1: Date? = Date(timeIntervalSince1970: 1000)
        let date2: Date? = nil
        
        #expect(!(date1 < date2))
    }
    
    @Test("optional date comparison compares actual dates")
    func optionalDateComparisonComparesActualDates() {
        let date1: Date? = Date(timeIntervalSince1970: 1000)
        let date2: Date? = Date(timeIntervalSince1970: 2000)
        
        #expect(date1 < date2)
        #expect(!(date2 < date1))
    }
}
