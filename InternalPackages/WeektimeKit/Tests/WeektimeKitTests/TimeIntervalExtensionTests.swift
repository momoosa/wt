//
//  TimeIntervalExtensionTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("TimeInterval Extension Tests")
struct TimeIntervalExtensionTests {

    // MARK: - Hour Minute Format Tests

    @Test("hourMinute format with hours and minutes")
    func hourMinuteFormatWithHoursAndMinutes() {
        let interval: TimeInterval = 9000 // 2h 30m (2*3600 + 30*60)
        let formatted = interval.formatted(style: .hourMinute)

        #expect(formatted == "2h 30m")
    }

    @Test("hourMinute format with only minutes")
    func hourMinuteFormatWithOnlyMinutes() {
        let interval: TimeInterval = 2700 // 45m (45*60)
        let formatted = interval.formatted(style: .hourMinute)

        #expect(formatted == "45m")
    }

    @Test("hourMinute format with zero time")
    func hourMinuteFormatWithZeroTime() {
        let interval: TimeInterval = 0
        let formatted = interval.formatted(style: .hourMinute)

        #expect(formatted == "0m")
    }

    @Test("hourMinute format with exactly one hour")
    func hourMinuteFormatWithExactlyOneHour() {
        let interval: TimeInterval = 3600 // 1h 0m
        let formatted = interval.formatted(style: .hourMinute)

        #expect(formatted == "1h 0m")
    }

    @Test("hourMinute format drops seconds")
    func hourMinuteFormatDropsSeconds() {
        let interval: TimeInterval = 9045 // 2h 30m 45s
        let formatted = interval.formatted(style: .hourMinute)

        // Should only show hours and minutes, ignoring seconds
        #expect(formatted == "2h 30m")
    }

    @Test("hourMinute format with large hours")
    func hourMinuteFormatWithLargeHours() {
        let interval: TimeInterval = 36000 // 10h 0m
        let formatted = interval.formatted(style: .hourMinute)

        #expect(formatted == "10h 0m")
    }

    // MARK: - H:MM:SS Format Tests

    @Test("hmmss format with hours")
    func hmmssFormatWithHours() {
        let interval: TimeInterval = 5445 // 1:30:45
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "1:30:45")
    }

    @Test("hmmss format with only minutes")
    func hmmssFormatWithOnlyMinutes() {
        let interval: TimeInterval = 330 // 5:30
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "5:30")
    }

    @Test("hmmss format with only seconds")
    func hmmssFormatWithOnlySeconds() {
        let interval: TimeInterval = 45 // 0:45
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "0:45")
    }

    @Test("hmmss format zero pads minutes and seconds")
    func hmmssFormatZeroPadsMinutesAndSeconds() {
        let interval: TimeInterval = 3665 // 1:01:05
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "1:01:05")
    }

    @Test("hmmss format with zero time")
    func hmmssFormatWithZeroTime() {
        let interval: TimeInterval = 0
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "0:00")
    }

    @Test("hmmss format with exactly one minute")
    func hmmssFormatWithExactlyOneMinute() {
        let interval: TimeInterval = 60
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "1:00")
    }

    @Test("hmmss format with large hours")
    func hmmssFormatWithLargeHours() {
        let interval: TimeInterval = 36125 // 10:02:05
        let formatted = interval.formatted(style: .hmmss)

        #expect(formatted == "10:02:05")
    }

    // MARK: - Components Format Tests

    @Test("components format with all components")
    func componentsFormatWithAllComponents() {
        let interval: TimeInterval = 5475 // 1h 31m 15s
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "1h 31m 15s")
    }

    @Test("components format with only hours and minutes")
    func componentsFormatWithOnlyHoursAndMinutes() {
        let interval: TimeInterval = 5400 // 1h 30m 0s
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "1h 30m")
    }

    @Test("components format with only seconds")
    func componentsFormatWithOnlySeconds() {
        let interval: TimeInterval = 45
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "45s")
    }

    @Test("components format with zero time shows zero seconds")
    func componentsFormatWithZeroTimeShowsZeroSeconds() {
        let interval: TimeInterval = 0
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "0s")
    }

    @Test("components format with only hours")
    func componentsFormatWithOnlyHours() {
        let interval: TimeInterval = 7200 // 2h 0m 0s
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "2h")
    }

    @Test("components format with only minutes")
    func componentsFormatWithOnlyMinutes() {
        let interval: TimeInterval = 1800 // 30m 0s
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "30m")
    }

    @Test("components format with hours and seconds")
    func componentsFormatWithHoursAndSeconds() {
        let interval: TimeInterval = 3615 // 1h 0m 15s
        let formatted = interval.formatted(style: .components)

        #expect(formatted == "1h 15s")
    }

    // MARK: - Full Units Format Tests

    @Test("fullUnits format with singular hour")
    func fullUnitsFormatWithSingularHour() {
        let interval: TimeInterval = 3600 // 1 hour
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "1 hour")
    }

    @Test("fullUnits format with plural hours")
    func fullUnitsFormatWithPluralHours() {
        let interval: TimeInterval = 7200 // 2 hours
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "2 hours")
    }

    @Test("fullUnits format with singular minute")
    func fullUnitsFormatWithSingularMinute() {
        let interval: TimeInterval = 60 // 1 minute
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "1 minute")
    }

    @Test("fullUnits format with plural minutes")
    func fullUnitsFormatWithPluralMinutes() {
        let interval: TimeInterval = 300 // 5 minutes
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "5 minutes")
    }

    @Test("fullUnits format with singular second")
    func fullUnitsFormatWithSingularSecond() {
        let interval: TimeInterval = 1 // 1 second
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "1 second")
    }

    @Test("fullUnits format with plural seconds")
    func fullUnitsFormatWithPluralSeconds() {
        let interval: TimeInterval = 45 // 45 seconds
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "45 seconds")
    }

    @Test("fullUnits format with all components")
    func fullUnitsFormatWithAllComponents() {
        let interval: TimeInterval = 5475 // 1h 31m 15s
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "1 hour 31 minutes 15 seconds")
    }

    @Test("fullUnits format with zero time")
    func fullUnitsFormatWithZeroTime() {
        let interval: TimeInterval = 0
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "0 seconds")
    }

    @Test("fullUnits format with mixed singular and plural")
    func fullUnitsFormatWithMixedSingularAndPlural() {
        let interval: TimeInterval = 3661 // 1h 1m 1s
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "1 hour 1 minute 1 second")
    }

    @Test("fullUnits format with hours and seconds only")
    func fullUnitsFormatWithHoursAndSecondsOnly() {
        let interval: TimeInterval = 3601 // 1h 0m 1s
        let formatted = interval.formatted(style: .fullUnits)

        #expect(formatted == "1 hour 1 second")
    }

    // MARK: - Default Format Tests

    @Test("default format style is hourMinute")
    func defaultFormatStyleIsHourMinute() {
        let interval: TimeInterval = 5400 // 1h 30m
        let formatted = interval.formatted()

        #expect(formatted == "1h 30m")
    }
}
