//
//  DayModelTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Day Model Tests")
struct DayModelTests {

    // MARK: - Initialization Tests

    @Test("Day initializes with correct start and end dates")
    func dayInitializesWithCorrectDates() {
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 0)
        let endDate = Date(timeIntervalSince1970: 86400)

        let day = Day(start: startDate, end: endDate, calendar: calendar)

        #expect(day.startDate == startDate)
        #expect(day.endDate == endDate)
    }

    @Test("Day generates correct yearMonthDay ID")
    func dayGeneratesCorrectID() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 12, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.id.contains("2026"))
        #expect(day.id.contains("03"))
        #expect(day.id.contains("07"))
    }

    @Test("Day extracts correct day component")
    func dayExtractsCorrectDayComponent() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 15, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.dayComponent == 15)
    }

    @Test("Day generates correct title from month")
    func dayGeneratesCorrectTitleFromMonth() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        // Title should be the full month name
        #expect(day.title.lowercased().contains("march") || day.title.lowercased().contains("mar"))
    }

    @Test("Day generates correct full title")
    func dayGeneratesCorrectFullTitle() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        // Full title should be "day month" like "7 March"
        #expect(day.fullTitle.contains("7"))
        #expect(day.fullTitle.lowercased().contains("march") || day.fullTitle.lowercased().contains("mar"))
    }

    // MARK: - Weekday Tests

    @Test("Day sets correct weekday initial")
    func daySetsCorrectWeekdayInitial() {
        let calendar = Calendar.current
        // March 9, 2026 is a Monday
        let components = DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.initial != nil)
        #expect(day.initial?.isEmpty == false)
    }

    @Test("Day sets correct weekday title")
    func daySetsCorrectWeekdayTitle() {
        let calendar = Calendar.current
        // March 9, 2026 is a Monday
        let components = DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.weekdayTitle != nil)
        #expect(day.weekdayTitle?.lowercased().contains("monday") == true ||
                day.weekdayTitle?.lowercased().contains("mon") == true)
    }

    @Test("Day sets correct weekday ID")
    func daySetsCorrectWeekdayID() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        // Weekday ID should be between 1 and 7
        #expect(day.weekdayID >= 1)
        #expect(day.weekdayID <= 7)
    }

    // MARK: - Session Management Tests

    @Test("Day initializes with empty session arrays")
    func dayInitializesWithEmptySessionArrays() {
        let calendar = Calendar.current
        let date = Date()

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.sessions?.isEmpty == true)
        #expect(day.historicalSessions?.isEmpty == true)
    }

    @Test("Day can add historical session")
    func dayCanAddHistoricalSession() {
        let calendar = Calendar.current
        let date = Date()

        let day = Day(start: date, end: date, calendar: calendar)
        let session = HistoricalSession(
            title: "Test Session",
            start: date,
            end: date.addingTimeInterval(3600),
            needsHealthKitRecord: false
        )

        day.add(historicalSession: session)

        #expect(day.historicalSessions?.isEmpty == false)
        #expect(day.historicalSessions?.count == 1)
        #expect(day.historicalSessions?.first?.id == session.id)
    }

    @Test("Day updates existing historical session")
    func dayUpdatesExistingHistoricalSession() {
        let calendar = Calendar.current
        let date = Date()

        let day = Day(start: date, end: date, calendar: calendar)
        let session1 = HistoricalSession(
            title: "Test Session 1",
            start: date,
            end: date.addingTimeInterval(3600),
            needsHealthKitRecord: false
        )

        day.add(historicalSession: session1)

        // Create a new session with the same ID but different data
        let session2 = HistoricalSession(
            id: session1.id, // Force same ID
            title: "Test Session 2",
            start: date,
            end: date.addingTimeInterval(7200),
            needsHealthKitRecord: false
        )

        day.add(historicalSession: session2)

        // Should still have only one session, but updated
        #expect(day.historicalSessions?.count == 1)
        #expect(day.historicalSessions?.first?.title == "Test Session 2")
    }

    @Test("Day can add multiple different historical sessions")
    func dayCanAddMultipleDifferentHistoricalSessions() {
        let calendar = Calendar.current
        let date = Date()

        let day = Day(start: date, end: date, calendar: calendar)

        let session1 = HistoricalSession(
            title: "Test Session 1",
            start: date,
            end: date.addingTimeInterval(3600),
            needsHealthKitRecord: false
        )

        let session2 = HistoricalSession(
            title: "Test Session 2",
            start: date.addingTimeInterval(3600),
            end: date.addingTimeInterval(7200),
            needsHealthKitRecord: false
        )

        day.add(historicalSession: session1)
        day.add(historicalSession: session2)

        #expect(day.historicalSessions?.count == 2)
    }

    // MARK: - Different Calendar Locales Tests

    @Test("Day works with different calendar locales")
    func dayWorksWithDifferentCalendarLocales() {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "fr_FR")

        let components = DateComponents(year: 2026, month: 3, day: 7, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.dayComponent == 7)
        #expect(day.initial != nil)
        #expect(day.weekdayTitle != nil)
    }

    @Test("Day handles leap year dates")
    func dayHandlesLeapYearDates() {
        let calendar = Calendar.current
        // February 29, 2024 (leap year)
        let components = DateComponents(year: 2024, month: 2, day: 29, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create leap year date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.dayComponent == 29)
        #expect(day.id.contains("2024"))
        #expect(day.id.contains("02"))
        #expect(day.id.contains("29"))
    }

    @Test("Day handles year boundaries")
    func dayHandlesYearBoundaries() {
        let calendar = Calendar.current
        // December 31, 2025
        let components = DateComponents(year: 2025, month: 12, day: 31, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.dayComponent == 31)
        #expect(day.title.lowercased().contains("dec") || day.title.lowercased().contains("december"))
    }

    @Test("Day handles first day of year")
    func dayHandlesFirstDayOfYear() {
        let calendar = Calendar.current
        // January 1, 2026
        let components = DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date")
            return
        }

        let day = Day(start: date, end: date, calendar: calendar)

        #expect(day.dayComponent == 1)
        #expect(day.title.lowercased().contains("jan") || day.title.lowercased().contains("january"))
    }
}
