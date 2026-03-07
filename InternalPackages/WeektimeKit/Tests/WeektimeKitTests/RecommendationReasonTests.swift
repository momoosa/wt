//
//  RecommendationReasonTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Recommendation Reason Tests")
struct RecommendationReasonTests {

    // MARK: - Raw Value Tests

    @Test("RecommendationReason raw values are correct")
    func recommendationReasonRawValuesCorrect() {
        #expect(RecommendationReason.weeklyProgress.rawValue == "weekly_progress")
        #expect(RecommendationReason.userPriority.rawValue == "user_priority")
        #expect(RecommendationReason.weather.rawValue == "weather")
        #expect(RecommendationReason.availableTime.rawValue == "available_time")
        #expect(RecommendationReason.plannedTheme.rawValue == "planned_theme")
        #expect(RecommendationReason.quickFinish.rawValue == "quick_finish")
        #expect(RecommendationReason.preferredTime.rawValue == "preferred_time")
        #expect(RecommendationReason.energyLevel.rawValue == "energy_level")
        #expect(RecommendationReason.usualTime.rawValue == "usual_time")
        #expect(RecommendationReason.constrained.rawValue == "constrained")
    }

    // MARK: - Display Name Tests

    @Test("RecommendationReason display names are correct")
    func recommendationReasonDisplayNamesCorrect() {
        #expect(RecommendationReason.weeklyProgress.displayName == "Behind Schedule")
        #expect(RecommendationReason.userPriority.displayName == "High Priority")
        #expect(RecommendationReason.weather.displayName == "Good Weather")
        #expect(RecommendationReason.availableTime.displayName == "Fits Schedule")
        #expect(RecommendationReason.plannedTheme.displayName == "Planned Theme")
        #expect(RecommendationReason.quickFinish.displayName == "Quick Finish")
        #expect(RecommendationReason.preferredTime.displayName == "Preferred Time")
        #expect(RecommendationReason.energyLevel.displayName == "Peak Energy")
        #expect(RecommendationReason.usualTime.displayName == "Usual Time")
        #expect(RecommendationReason.constrained.displayName == "Time-Limited")
    }

    @Test("All display names are non-empty")
    func allDisplayNamesAreNonEmpty() {
        for reason in RecommendationReason.allCases {
            #expect(!reason.displayName.isEmpty)
        }
    }

    // MARK: - Icon Tests

    @Test("RecommendationReason icons are valid SF Symbols")
    func recommendationReasonIconsValid() {
        #expect(RecommendationReason.weeklyProgress.icon == "chart.line.uptrend.xyaxis")
        #expect(RecommendationReason.userPriority.icon == "star.fill")
        #expect(RecommendationReason.weather.icon == "cloud.sun.fill")
        #expect(RecommendationReason.availableTime.icon == "clock.fill")
        #expect(RecommendationReason.plannedTheme.icon == "tag.fill")
        #expect(RecommendationReason.quickFinish.icon == "flag.checkered")
        #expect(RecommendationReason.preferredTime.icon == "calendar")
        #expect(RecommendationReason.energyLevel.icon == "bolt.fill")
        #expect(RecommendationReason.usualTime.icon == "clock.arrow.circlepath")
        #expect(RecommendationReason.constrained.icon == "hourglass")
    }

    @Test("All icons are non-empty")
    func allIconsAreNonEmpty() {
        for reason in RecommendationReason.allCases {
            #expect(!reason.icon.isEmpty)
        }
    }

    // MARK: - Description Tests

    @Test("RecommendationReason descriptions are meaningful")
    func recommendationReasonDescriptionsAreMeaningful() {
        #expect(RecommendationReason.weeklyProgress.description.contains("weekly target"))
        #expect(RecommendationReason.userPriority.description.contains("important"))
        #expect(RecommendationReason.weather.description.contains("weather"))
        #expect(RecommendationReason.availableTime.description.contains("time"))
        #expect(RecommendationReason.plannedTheme.description.contains("focus"))
        #expect(RecommendationReason.quickFinish.description.contains("finish"))
        #expect(RecommendationReason.preferredTime.description.contains("preferred"))
        #expect(RecommendationReason.energyLevel.description.contains("focus"))
        #expect(RecommendationReason.usualTime.description.contains("often"))
        #expect(RecommendationReason.constrained.description.contains("time window"))
    }

    @Test("All descriptions are non-empty")
    func allDescriptionsAreNonEmpty() {
        for reason in RecommendationReason.allCases {
            #expect(!reason.description.isEmpty)
        }
    }

    // MARK: - CaseIterable Tests

    @Test("RecommendationReason has all expected cases")
    func recommendationReasonHasAllExpectedCases() {
        #expect(RecommendationReason.allCases.count == 10)
    }

    @Test("RecommendationReason allCases contains all reasons")
    func recommendationReasonAllCasesContainsAllReasons() {
        let allCases = RecommendationReason.allCases
        #expect(allCases.contains(.weeklyProgress))
        #expect(allCases.contains(.userPriority))
        #expect(allCases.contains(.weather))
        #expect(allCases.contains(.availableTime))
        #expect(allCases.contains(.plannedTheme))
        #expect(allCases.contains(.quickFinish))
        #expect(allCases.contains(.preferredTime))
        #expect(allCases.contains(.energyLevel))
        #expect(allCases.contains(.usualTime))
        #expect(allCases.contains(.constrained))
    }

    // MARK: - Codable Tests

    @Test("RecommendationReason is Codable")
    func recommendationReasonIsCodable() throws {
        let reason = RecommendationReason.weeklyProgress

        let encoder = JSONEncoder()
        let data = try encoder.encode(reason)

        let decoder = JSONDecoder()
        let decodedReason = try decoder.decode(RecommendationReason.self, from: data)

        #expect(decodedReason == reason)
    }

    @Test("RecommendationReason encodes to raw value")
    func recommendationReasonEncodesToRawValue() throws {
        let reason = RecommendationReason.userPriority

        let encoder = JSONEncoder()
        let data = try encoder.encode(reason)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("user_priority") == true)
    }

    // MARK: - Hashable Tests

    @Test("RecommendationReason is Hashable")
    func recommendationReasonIsHashable() {
        let reason1 = RecommendationReason.weather
        let reason2 = RecommendationReason.weather
        let reason3 = RecommendationReason.userPriority

        #expect(reason1.hashValue == reason2.hashValue)
        #expect(reason1.hashValue != reason3.hashValue)
    }

    @Test("RecommendationReason can be used in Set")
    func recommendationReasonCanBeUsedInSet() {
        let reasons: Set<RecommendationReason> = [
            .weeklyProgress,
            .userPriority,
            .weather,
            .weeklyProgress // Duplicate
        ]

        #expect(reasons.count == 3) // Duplicate removed
        #expect(reasons.contains(.weeklyProgress))
        #expect(reasons.contains(.userPriority))
        #expect(reasons.contains(.weather))
    }

    // MARK: - Practical Usage Tests

    @Test("Multiple reasons can be combined")
    func multipleReasonsCanBeCombined() {
        let reasons: [RecommendationReason] = [
            .weeklyProgress,
            .weather,
            .preferredTime
        ]

        #expect(reasons.count == 3)
        #expect(reasons.contains(.weeklyProgress))
        #expect(reasons.contains(.weather))
        #expect(reasons.contains(.preferredTime))
    }

    @Test("Reasons can be filtered")
    func reasonsCanBeFiltered() {
        let allReasons = RecommendationReason.allCases
        let timeRelated = allReasons.filter { reason in
            reason.displayName.lowercased().contains("time")
        }

        #expect(timeRelated.count > 0)
    }
}
