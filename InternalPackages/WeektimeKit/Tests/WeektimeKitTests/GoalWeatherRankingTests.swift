//
//  GoalWeatherRankingTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 19/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Weather Ranking Tests")
struct GoalWeatherRankingTests {
    
    // MARK: - Test Helpers
    
    
    // MARK: - Goal Ranking Tests
    
    @Test("Goals with weather-matching tags rank higher than non-matching goals")
    func goalsWithWeatherMatchingTagsRankHigher() {
        // Create tags
        let outdoorTag = GoalTag(
            title: "Outdoor",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...28
        )
        
        let indoorTag = GoalTag(
            title: "Indoor",
            themeID: "test",
            weatherConditions: [.rainy, .cloudy]
        )
        
        let neutralTag = GoalTag(
            title: "Anytime",
            themeID: "test"
        )
        
        // Create goals
        let outdoorGoal = Goal(
            title: "Morning Run",
            primaryTag: outdoorTag,
            weeklyTarget: 3600
        )
        
        let indoorGoal = Goal(
            title: "Reading",
            primaryTag: indoorTag,
            weeklyTarget: 3600
        )
        
        let neutralGoal = Goal(
            title: "Meditation",
            primaryTag: neutralTag,
            weeklyTarget: 3600
        )
        
        // Test on sunny day
        let outdoorScore = outdoorGoal.primaryTag?.contextMatchScore(
            weather: .clear,
            temperature: 20
        ) ?? 0
        
        let indoorScore = indoorGoal.primaryTag?.contextMatchScore(
            weather: .clear,
            temperature: 20
        ) ?? 0
        
        let neutralScore = neutralGoal.primaryTag?.contextMatchScore(
            weather: .clear,
            temperature: 20
        ) ?? 0
        
        // Verify ranking
        #expect(outdoorScore == 1.0)
        #expect(indoorScore == 0.0)
        #expect(neutralScore == 0.5)
        #expect(outdoorScore > neutralScore)
        #expect(outdoorScore > indoorScore)
        #expect(neutralScore > indoorScore)
    }
    
    @Test("Goals without primary tags have neutral ranking")
    func goalsWithoutPrimaryTagsHaveNeutralRanking() {
        let goalWithoutTag = Goal(
            title: "Generic Goal",
            weeklyTarget: 3600
        )
        
        let score = goalWithoutTag.primaryTag?.contextMatchScore(
            weather: .clear,
            temperature: 20
        )
        
        // No tag means no score available
        #expect(score == nil)
    }
    
    @Test("Multiple goals compete correctly based on context")
    func multipleGoalsCompeteCorrectlyBasedOnContext() {
        // Create diverse tags
        let morningRunTag = GoalTag(
            title: "Morning Run",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        let gymTag = GoalTag(
            title: "Gym",
            themeID: "test",
            timeOfDayPreferences: [.morning, .afternoon],
            locationTypes: [.gym]
        )
        
        let yogaTag = GoalTag(
            title: "Yoga",
            themeID: "test",
            timeOfDayPreferences: [.evening],
            locationTypes: [.home]
        )
        
        // Create goals
        let runGoal = Goal(title: "Run", primaryTag: morningRunTag, weeklyTarget: 3600)
        let gymGoal = Goal(title: "Gym", primaryTag: gymTag, weeklyTarget: 3600)
        let yogaGoal = Goal(title: "Yoga", primaryTag: yogaTag, weeklyTarget: 3600)
        
        let goals = [runGoal, gymGoal, yogaGoal]
        
        // Test context: Clear morning, outdoor location
        let scores = goals.compactMap { goal -> (goal: Goal, score: Double)? in
            guard let score = goal.primaryTag?.contextMatchScore(
                weather: .clear,
                temperature: 20,
                timeOfDay: .morning,
                location: .outdoor
            ) else { return nil }
            return (goal: goal, score: score)
        }
        
        // Run should match perfectly
        let runScore = scores.first { $0.goal.title == "Run" }?.score
        #expect(runScore == 1.0)
        
        // Gym should fail (wrong location)
        let gymScore = scores.first { $0.goal.title == "Gym" }?.score
        #expect(gymScore == 0.0)
        
        // Yoga should fail (wrong time)
        let yogaScore = scores.first { $0.goal.title == "Yoga" }?.score
        #expect(yogaScore == 0.0)
    }
    
    @Test("Goal ranking considers time of day preferences")
    func goalRankingConsidersTimeOfDayPreferences() {
        let morningTag = GoalTag(
            title: "Morning Activity",
            themeID: "test",
            timeOfDayPreferences: [.morning]
        )
        
        let eveningTag = GoalTag(
            title: "Evening Activity",
            themeID: "test",
            timeOfDayPreferences: [.evening]
        )
        
        let flexibleTag = GoalTag(
            title: "Flexible Activity",
            themeID: "test",
            timeOfDayPreferences: [.morning, .afternoon, .evening]
        )
        
        let morningGoal = Goal(title: "Morning Workout", primaryTag: morningTag, weeklyTarget: 3600)
        let eveningGoal = Goal(title: "Evening Reading", primaryTag: eveningTag, weeklyTarget: 3600)
        let flexibleGoal = Goal(title: "Meditation", primaryTag: flexibleTag, weeklyTarget: 3600)
        
        // Test in morning context
        let morningScoreMorning = morningGoal.primaryTag?.contextMatchScore(timeOfDay: .morning) ?? 0
        let eveningScoreMorning = eveningGoal.primaryTag?.contextMatchScore(timeOfDay: .morning) ?? 0
        let flexibleScoreMorning = flexibleGoal.primaryTag?.contextMatchScore(timeOfDay: .morning) ?? 0
        
        #expect(morningScoreMorning == 1.0)
        #expect(eveningScoreMorning == 0.0)
        #expect(flexibleScoreMorning == 1.0)
        
        // Test in evening context
        let morningScoreEvening = morningGoal.primaryTag?.contextMatchScore(timeOfDay: .evening) ?? 0
        let eveningScoreEvening = eveningGoal.primaryTag?.contextMatchScore(timeOfDay: .evening) ?? 0
        let flexibleScoreEvening = flexibleGoal.primaryTag?.contextMatchScore(timeOfDay: .evening) ?? 0
        
        #expect(morningScoreEvening == 0.0)
        #expect(eveningScoreEvening == 1.0)
        #expect(flexibleScoreEvening == 1.0)
    }
    
    @Test("Complex goal ranking scenario with multiple context factors")
    func complexGoalRankingScenario() {
        // Scenario: Cold, snowy morning outdoors
        let context = (
            weather: WeatherCondition.snowy,
            temperature: -5.0,
            timeOfDay: TimeOfDay.morning,
            location: LocationType.outdoor
        )
        
        // Create diverse goals
        let skiingTag = GoalTag(
            title: "Skiing",
            themeID: "test",
            weatherConditions: [.snowy],
            temperatureRange: -10...5,
            locationTypes: [.outdoor]
        )
        
        let runningTag = GoalTag(
            title: "Running",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        let yogaTag = GoalTag(
            title: "Yoga",
            themeID: "test",
            timeOfDayPreferences: [.morning],
            locationTypes: [.home]
        )
        
        let skiingGoal = Goal(title: "Skiing", primaryTag: skiingTag, weeklyTarget: 3600)
        let runningGoal = Goal(title: "Running", primaryTag: runningTag, weeklyTarget: 3600)
        let yogaGoal = Goal(title: "Yoga", primaryTag: yogaTag, weeklyTarget: 3600)
        
        let goals = [skiingGoal, runningGoal, yogaGoal]
        
        // Calculate scores
        let scores = goals.compactMap { goal -> (title: String, score: Double)? in
            guard let score = goal.primaryTag?.contextMatchScore(
                weather: context.weather,
                temperature: context.temperature,
                timeOfDay: context.timeOfDay,
                location: context.location
            ) else { return nil }
            return (title: goal.title, score: score)
        }.sorted { $0.score > $1.score }
        
        // Skiing should rank highest (all conditions match)
        #expect(scores[0].title == "Skiing")
        #expect(scores[0].score == 1.0)

        // Both Running and Yoga should score 0.0 (order doesn't matter)
        let failedGoals = scores.filter { $0.score == 0.0 }
        #expect(failedGoals.count == 2)

        let failedTitles = Set(failedGoals.map { $0.title })
        #expect(failedTitles.contains("Running"))
        #expect(failedTitles.contains("Yoga"))
    }
}
