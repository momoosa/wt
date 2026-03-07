//
//  CalendarComponentExtensionTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Calendar Component Extension Tests")
struct CalendarComponentExtensionTests {

    @Test("yearMonthDay contains correct components")
    func yearMonthDayContainsCorrectComponents() {
        let components = Calendar.Component.yearMonthDay

        #expect(components.contains(.year))
        #expect(components.contains(.month))
        #expect(components.contains(.day))
        #expect(components.count == 3)
    }

    @Test("yearMonthDay does not contain time components")
    func yearMonthDayDoesNotContainTimeComponents() {
        let components = Calendar.Component.yearMonthDay

        #expect(!components.contains(.hour))
        #expect(!components.contains(.minute))
        #expect(!components.contains(.second))
    }

    @Test("yearMonthDayAndTime contains all components")
    func yearMonthDayAndTimeContainsAllComponents() {
        let components = Calendar.Component.yearMonthDayAndTime

        #expect(components.contains(.year))
        #expect(components.contains(.month))
        #expect(components.contains(.day))
        #expect(components.contains(.hour))
        #expect(components.contains(.minute))
        #expect(components.contains(.second))
        #expect(components.count == 6)
    }

    @Test("yearMonthDayAndTime is superset of yearMonthDay")
    func yearMonthDayAndTimeIsSupersetOfYearMonthDay() {
        let dateComponents = Calendar.Component.yearMonthDay
        let dateTimeComponents = Calendar.Component.yearMonthDayAndTime

        #expect(dateTimeComponents.isSuperset(of: dateComponents))
    }

    @Test("yearMonthDay can be used with Calendar.dateComponents")
    func yearMonthDayCanBeUsedWithCalendarDateComponents() {
        let calendar = Calendar.current
        let date = Date()

        let components = calendar.dateComponents(Calendar.Component.yearMonthDay, from: date)

        #expect(components.year != nil)
        #expect(components.month != nil)
        #expect(components.day != nil)
    }

    @Test("yearMonthDayAndTime can be used with Calendar.dateComponents")
    func yearMonthDayAndTimeCanBeUsedWithCalendarDateComponents() {
        let calendar = Calendar.current
        let date = Date()

        let components = calendar.dateComponents(Calendar.Component.yearMonthDayAndTime, from: date)

        #expect(components.year != nil)
        #expect(components.month != nil)
        #expect(components.day != nil)
        #expect(components.hour != nil)
        #expect(components.minute != nil)
        #expect(components.second != nil)
    }
}
