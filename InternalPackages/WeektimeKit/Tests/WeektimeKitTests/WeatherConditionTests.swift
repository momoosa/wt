//
//  WeatherConditionTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Weather Condition Tests")
struct WeatherConditionTests {

    // MARK: - Raw Value Tests

    @Test("WeatherCondition raw values are correct")
    func weatherConditionRawValuesCorrect() {
        #expect(WeatherCondition.clear.rawValue == "clear")
        #expect(WeatherCondition.partlyCloudy.rawValue == "partlyCloudy")
        #expect(WeatherCondition.cloudy.rawValue == "cloudy")
        #expect(WeatherCondition.rainy.rawValue == "rainy")
        #expect(WeatherCondition.snowy.rawValue == "snowy")
        #expect(WeatherCondition.stormy.rawValue == "stormy")
        #expect(WeatherCondition.foggy.rawValue == "foggy")
    }

    // MARK: - Display Name Tests

    @Test("WeatherCondition display names are correct")
    func weatherConditionDisplayNamesCorrect() {
        #expect(WeatherCondition.clear.displayName == "Clear")
        #expect(WeatherCondition.partlyCloudy.displayName == "Partly Cloudy")
        #expect(WeatherCondition.cloudy.displayName == "Cloudy")
        #expect(WeatherCondition.rainy.displayName == "Rainy")
        #expect(WeatherCondition.snowy.displayName == "Snowy")
        #expect(WeatherCondition.stormy.displayName == "Stormy")
        #expect(WeatherCondition.foggy.displayName == "Foggy")
    }

    @Test("All display names are non-empty")
    func allDisplayNamesAreNonEmpty() {
        for condition in WeatherCondition.allCases {
            #expect(!condition.displayName.isEmpty)
        }
    }

    @Test("Display names are properly capitalized")
    func displayNamesAreProperlyCapitalized() {
        for condition in WeatherCondition.allCases {
            let firstChar = condition.displayName.first
            #expect(firstChar?.isUppercase == true)
        }
    }

    // MARK: - Icon Tests

    @Test("WeatherCondition icons are valid SF Symbols")
    func weatherConditionIconsValid() {
        #expect(WeatherCondition.clear.icon == "sun.max.fill")
        #expect(WeatherCondition.partlyCloudy.icon == "cloud.sun.fill")
        #expect(WeatherCondition.cloudy.icon == "cloud.fill")
        #expect(WeatherCondition.rainy.icon == "cloud.rain.fill")
        #expect(WeatherCondition.snowy.icon == "cloud.snow.fill")
        #expect(WeatherCondition.stormy.icon == "cloud.bolt.fill")
        #expect(WeatherCondition.foggy.icon == "cloud.fog.fill")
    }

    @Test("All icons are non-empty")
    func allIconsAreNonEmpty() {
        for condition in WeatherCondition.allCases {
            #expect(!condition.icon.isEmpty)
        }
    }

    @Test("All icons contain cloud or sun")
    func allIconsContainCloudOrSun() {
        for condition in WeatherCondition.allCases {
            let icon = condition.icon
            #expect(icon.contains("cloud") || icon.contains("sun"))
        }
    }

    // MARK: - CaseIterable Tests

    @Test("WeatherCondition has all expected cases")
    func weatherConditionHasAllExpectedCases() {
        #expect(WeatherCondition.allCases.count == 7)
    }

    @Test("WeatherCondition allCases contains all conditions")
    func weatherConditionAllCasesContainsAllConditions() {
        let allCases = WeatherCondition.allCases
        #expect(allCases.contains(.clear))
        #expect(allCases.contains(.partlyCloudy))
        #expect(allCases.contains(.cloudy))
        #expect(allCases.contains(.rainy))
        #expect(allCases.contains(.snowy))
        #expect(allCases.contains(.stormy))
        #expect(allCases.contains(.foggy))
    }

    // MARK: - Codable Tests

    @Test("WeatherCondition is Codable")
    func weatherConditionIsCodable() throws {
        let condition = WeatherCondition.clear

        let encoder = JSONEncoder()
        let data = try encoder.encode(condition)

        let decoder = JSONDecoder()
        let decodedCondition = try decoder.decode(WeatherCondition.self, from: data)

        #expect(decodedCondition == condition)
    }

    @Test("WeatherCondition encodes to raw value")
    func weatherConditionEncodesToRawValue() throws {
        let condition = WeatherCondition.partlyCloudy

        let encoder = JSONEncoder()
        let data = try encoder.encode(condition)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("partlyCloudy") == true)
    }

    @Test("WeatherCondition decodes from string array")
    func weatherConditionDecodesFromStringArray() throws {
        let conditions: [WeatherCondition] = [.clear, .rainy, .snowy]

        let encoder = JSONEncoder()
        let data = try encoder.encode(conditions)

        let decoder = JSONDecoder()
        let decodedConditions = try decoder.decode([WeatherCondition].self, from: data)

        #expect(decodedConditions.count == 3)
        #expect(decodedConditions[0] == .clear)
        #expect(decodedConditions[1] == .rainy)
        #expect(decodedConditions[2] == .snowy)
    }

    // MARK: - Practical Usage Tests

    @Test("Weather conditions can be stored in arrays")
    func weatherConditionsCanBeStoredInArrays() {
        let outdoorConditions: [WeatherCondition] = [.clear, .partlyCloudy]
        let badWeatherConditions: [WeatherCondition] = [.rainy, .stormy, .snowy]

        #expect(outdoorConditions.count == 2)
        #expect(badWeatherConditions.count == 3)
    }

    @Test("Weather conditions can be used in switch statements")
    func weatherConditionsCanBeUsedInSwitchStatements() {
        let condition = WeatherCondition.clear

        var category = ""
        switch condition {
        case .clear, .partlyCloudy:
            category = "good"
        case .cloudy, .foggy:
            category = "moderate"
        case .rainy, .snowy, .stormy:
            category = "bad"
        }

        #expect(category == "good")
    }

    @Test("Weather conditions can be filtered by category")
    func weatherConditionsCanBeFilteredByCategory() {
        let allConditions = WeatherCondition.allCases
        let precipitationConditions = allConditions.filter { condition in
            [.rainy, .snowy, .stormy].contains(condition)
        }

        #expect(precipitationConditions.count == 3)
        #expect(precipitationConditions.contains(.rainy))
        #expect(precipitationConditions.contains(.snowy))
        #expect(precipitationConditions.contains(.stormy))
    }

    @Test("Clear weather is distinguishable from cloudy")
    func clearWeatherIsDistinguishableFromCloudy() {
        let clear = WeatherCondition.clear
        let cloudy = WeatherCondition.cloudy

        #expect(clear != cloudy)
        #expect(clear.displayName != cloudy.displayName)
        #expect(clear.icon != cloudy.icon)
    }
}
