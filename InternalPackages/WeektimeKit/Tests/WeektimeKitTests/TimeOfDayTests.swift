//
//  TimeOfDayTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Time of Day Tests")
struct TimeOfDayTests {

    // MARK: - Raw Value Tests

    @Test("TimeOfDay raw values are correct")
    func timeOfDayRawValuesCorrect() {
        #expect(TimeOfDay.morning.rawValue == "morning")
        #expect(TimeOfDay.midday.rawValue == "midday")
        #expect(TimeOfDay.afternoon.rawValue == "afternoon")
        #expect(TimeOfDay.evening.rawValue == "evening")
        #expect(TimeOfDay.night.rawValue == "night")
    }

    // MARK: - Display Name Tests

    @Test("TimeOfDay display names are correct")
    func timeOfDayDisplayNamesCorrect() {
        #expect(TimeOfDay.morning.displayName == "Morning")
        #expect(TimeOfDay.midday.displayName == "Midday")
        #expect(TimeOfDay.afternoon.displayName == "Afternoon")
        #expect(TimeOfDay.evening.displayName == "Evening")
        #expect(TimeOfDay.night.displayName == "Night")
    }

    @Test("All display names are non-empty")
    func allDisplayNamesAreNonEmpty() {
        for timeOfDay in TimeOfDay.allCases {
            #expect(!timeOfDay.displayName.isEmpty)
        }
    }

    @Test("Display names are properly capitalized")
    func displayNamesAreProperlyCapitalized() {
        for timeOfDay in TimeOfDay.allCases {
            let firstChar = timeOfDay.displayName.first
            #expect(firstChar?.isUppercase == true)
        }
    }

    // MARK: - Icon Tests

    @Test("TimeOfDay icons are valid SF Symbols")
    func timeOfDayIconsValid() {
        #expect(TimeOfDay.morning.icon == "sunrise.fill")
        #expect(TimeOfDay.midday.icon == "sun.max.fill")
        #expect(TimeOfDay.afternoon.icon == "sun.haze.fill")
        #expect(TimeOfDay.evening.icon == "sunset.fill")
        #expect(TimeOfDay.night.icon == "moon.stars.fill")
    }

    @Test("All icons are non-empty")
    func allIconsAreNonEmpty() {
        for timeOfDay in TimeOfDay.allCases {
            #expect(!timeOfDay.icon.isEmpty)
        }
    }

    @Test("Icon names contain expected keywords")
    func iconNamesContainExpectedKeywords() {
        #expect(TimeOfDay.morning.icon.contains("sunrise"))
        #expect(TimeOfDay.midday.icon.contains("sun"))
        #expect(TimeOfDay.afternoon.icon.contains("sun"))
        #expect(TimeOfDay.evening.icon.contains("sunset"))
        #expect(TimeOfDay.night.icon.contains("moon"))
    }

    // MARK: - CaseIterable Tests

    @Test("TimeOfDay has all expected cases")
    func timeOfDayHasAllExpectedCases() {
        #expect(TimeOfDay.allCases.count == 5)
    }

    @Test("TimeOfDay allCases contains all times")
    func timeOfDayAllCasesContainsAllTimes() {
        let allCases = TimeOfDay.allCases
        #expect(allCases.contains(.morning))
        #expect(allCases.contains(.midday))
        #expect(allCases.contains(.afternoon))
        #expect(allCases.contains(.evening))
        #expect(allCases.contains(.night))
    }

    // MARK: - Codable Tests

    @Test("TimeOfDay is Codable")
    func timeOfDayIsCodable() throws {
        let time = TimeOfDay.morning

        let encoder = JSONEncoder()
        let data = try encoder.encode(time)

        let decoder = JSONDecoder()
        let decodedTime = try decoder.decode(TimeOfDay.self, from: data)

        #expect(decodedTime == time)
    }

    @Test("TimeOfDay encodes to raw value")
    func timeOfDayEncodesToRawValue() throws {
        let time = TimeOfDay.afternoon

        let encoder = JSONEncoder()
        let data = try encoder.encode(time)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("afternoon") == true)
    }

    @Test("TimeOfDay decodes from string array")
    func timeOfDayDecodesFromStringArray() throws {
        let times: [TimeOfDay] = [.morning, .afternoon, .night]

        let encoder = JSONEncoder()
        let data = try encoder.encode(times)

        let decoder = JSONDecoder()
        let decodedTimes = try decoder.decode([TimeOfDay].self, from: data)

        #expect(decodedTimes.count == 3)
        #expect(decodedTimes[0] == .morning)
        #expect(decodedTimes[1] == .afternoon)
        #expect(decodedTimes[2] == .night)
    }

    // MARK: - Hashable Tests

    @Test("TimeOfDay is Hashable")
    func timeOfDayIsHashable() {
        let time1 = TimeOfDay.morning
        let time2 = TimeOfDay.morning
        let time3 = TimeOfDay.evening

        #expect(time1.hashValue == time2.hashValue)
        #expect(time1.hashValue != time3.hashValue)
    }

    @Test("TimeOfDay can be used in Set")
    func timeOfDayCanBeUsedInSet() {
        let times: Set<TimeOfDay> = [
            .morning,
            .afternoon,
            .evening,
            .morning // Duplicate
        ]

        #expect(times.count == 3) // Duplicate removed
        #expect(times.contains(.morning))
        #expect(times.contains(.afternoon))
        #expect(times.contains(.evening))
    }

    // MARK: - Comparable Tests

    @Test("TimeOfDay follows chronological order")
    func timeOfDayFollowsChronologicalOrder() {
        #expect(TimeOfDay.morning < TimeOfDay.midday)
        #expect(TimeOfDay.midday < TimeOfDay.afternoon)
        #expect(TimeOfDay.afternoon < TimeOfDay.evening)
        #expect(TimeOfDay.evening < TimeOfDay.night)
    }

    @Test("TimeOfDay morning is earliest")
    func timeOfDayMorningIsEarliest() {
        #expect(TimeOfDay.morning < TimeOfDay.midday)
        #expect(TimeOfDay.morning < TimeOfDay.afternoon)
        #expect(TimeOfDay.morning < TimeOfDay.evening)
        #expect(TimeOfDay.morning < TimeOfDay.night)
    }

    @Test("TimeOfDay night is latest")
    func timeOfDayNightIsLatest() {
        #expect(TimeOfDay.night > TimeOfDay.morning)
        #expect(TimeOfDay.night > TimeOfDay.midday)
        #expect(TimeOfDay.night > TimeOfDay.afternoon)
        #expect(TimeOfDay.night > TimeOfDay.evening)
    }

    @Test("TimeOfDay can be sorted")
    func timeOfDayCanBeSorted() {
        let unsorted: [TimeOfDay] = [.night, .morning, .afternoon, .evening, .midday]
        let sorted = unsorted.sorted()

        #expect(sorted[0] == .morning)
        #expect(sorted[1] == .midday)
        #expect(sorted[2] == .afternoon)
        #expect(sorted[3] == .evening)
        #expect(sorted[4] == .night)
    }

    @Test("TimeOfDay equal to itself in comparison")
    func timeOfDayEqualToItselfInComparison() {
        for time in TimeOfDay.allCases {
            #expect(!(time < time))
            #expect(!(time > time))
        }
    }

    // MARK: - Practical Usage Tests

    @Test("TimeOfDay can be stored in arrays")
    func timeOfDayCanBeStoredInArrays() {
        let workTimes: [TimeOfDay] = [.morning, .midday, .afternoon]
        let relaxTimes: [TimeOfDay] = [.evening, .night]

        #expect(workTimes.count == 3)
        #expect(relaxTimes.count == 2)
    }

    @Test("TimeOfDay can be used in switch statements")
    func timeOfDayCanBeUsedInSwitchStatements() {
        let time = TimeOfDay.morning

        var category = ""
        switch time {
        case .morning, .midday:
            category = "active"
        case .afternoon, .evening:
            category = "moderate"
        case .night:
            category = "rest"
        }

        #expect(category == "active")
    }

    @Test("TimeOfDay can be filtered by category")
    func timeOfDayCanBeFilteredByCategory() {
        let allTimes = TimeOfDay.allCases
        let dayTimes = allTimes.filter { time in
            [.morning, .midday, .afternoon].contains(time)
        }

        #expect(dayTimes.count == 3)
        #expect(dayTimes.contains(.morning))
        #expect(dayTimes.contains(.midday))
        #expect(dayTimes.contains(.afternoon))
    }

    @Test("Morning is distinguishable from evening")
    func morningIsDistinguishableFromEvening() {
        let morning = TimeOfDay.morning
        let evening = TimeOfDay.evening

        #expect(morning != evening)
        #expect(morning.displayName != evening.displayName)
        #expect(morning.icon != evening.icon)
        #expect(morning < evening)
    }

    @Test("TimeOfDay can determine range")
    func timeOfDayCanDetermineRange() {
        let start = TimeOfDay.morning
        let end = TimeOfDay.evening

        let range = TimeOfDay.allCases.filter { time in
            time >= start && time <= end
        }

        #expect(range.count == 4) // morning, midday, afternoon, evening
        #expect(range.contains(.morning))
        #expect(range.contains(.midday))
        #expect(range.contains(.afternoon))
        #expect(range.contains(.evening))
        #expect(!range.contains(.night))
    }
}
