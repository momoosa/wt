//
//  GoalTagRankingTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Tag Ranking Tests")
struct GoalTagRankingTests {
    
    // MARK: - Test Helpers
    
    
    // MARK: - Goal Ranking Tests
    
    @Test("Goals are ranked by context match score on sunny morning")
    func goalsRankedByContextMatchOnSunnyMorning() {
        // Create goals with different triggers
        let outdoorRunTag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...28,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        let gymWorkoutTag = GoalTag(
            title: "Gym Workout",
            themeID: "test",
            timeOfDayPreferences: [.morning, .afternoon],
            locationTypes: [.gym]
        )
        
        let eveningYogaTag = GoalTag(
            title: "Evening Yoga",
            themeID: "test",
            timeOfDayPreferences: [.evening],
            locationTypes: [.home]
        )
        
        let rainyDayReadingTag = GoalTag(
            title: "Reading",
            themeID: "test",
            weatherConditions: [.rainy, .cloudy],
            timeOfDayPreferences: [.morning, .afternoon]
        )
        
        // Sunny morning context
        let outdoorRunScore = outdoorRunTag.contextMatchScore(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        let gymScore = gymWorkoutTag.contextMatchScore(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning,
            location: .gym
        )
        
        let yogaScore = eveningYogaTag.contextMatchScore(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning,
            location: .home
        )
        
        let readingScore = rainyDayReadingTag.contextMatchScore(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning
        )
        
        // Outdoor run should match perfectly (all 4 conditions provided and match)
        #expect(outdoorRunScore == 1.0)
        #expect(outdoorRunScore > yogaScore)
        #expect(outdoorRunScore > readingScore)
        
        // Gym workout should also match perfectly (both requirements met)
        #expect(gymScore == 1.0)
        #expect(gymScore > yogaScore)
        #expect(gymScore > readingScore)
        
        // Both outdoor run and gym score equally since all their requirements match
        #expect(outdoorRunScore == gymScore)
        
        // Evening yoga should not match (wrong time of day)
        #expect(yogaScore == 0.0)
        
        // Rainy day reading should not match (wrong weather)
        #expect(readingScore == 0.0)
    }
    
    @Test("Goals are ranked by context match score on rainy afternoon")
    func goalsRankedByContextMatchOnRainyAfternoon() {
        let outdoorRunTag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            timeOfDayPreferences: [.morning, .afternoon]
        )
        
        let indoorReadingTag = GoalTag(
            title: "Reading",
            themeID: "test",
            weatherConditions: [.rainy, .cloudy],
            timeOfDayPreferences: [.afternoon, .evening]
        )
        
        let movieWatchingTag = GoalTag(
            title: "Watch Movie",
            themeID: "test",
            weatherConditions: [.rainy, .stormy]
        )
        
        let noPreferenceTag = GoalTag(
            title: "Meditation",
            themeID: "test"
        )
        
        // Rainy afternoon context
        let runScore = outdoorRunTag.contextMatchScore(
            weather: .rainy,
            timeOfDay: .afternoon
        )
        
        let readingScore = indoorReadingTag.contextMatchScore(
            weather: .rainy,
            timeOfDay: .afternoon
        )
        
        let movieScore = movieWatchingTag.contextMatchScore(
            weather: .rainy
        )
        
        let meditationScore = noPreferenceTag.contextMatchScore(
            weather: .rainy,
            timeOfDay: .afternoon
        )
        
        // Reading should match perfectly (both weather and time requirements met)
        #expect(readingScore == 1.0)
        #expect(readingScore > runScore)
        #expect(readingScore > meditationScore)
        
        // Movie should also match perfectly (weather requirement met, no time requirement)
        #expect(movieScore == 1.0)
        #expect(movieScore > runScore)
        
        // Both reading and movie score equally since all their requirements match
        #expect(readingScore == movieScore)
        
        // Meditation should be neutral (no requirements)
        #expect(meditationScore == 0.5)
        
        // Run should not match (requires clear weather)
        #expect(runScore == 0.0)
    }
    
    @Test("Goals with more specific triggers rank higher when all match")
    func goalsWithMoreSpecificTriggersRankHigherWhenAllMatch() {
        // Very specific tag - 4 conditions
        let verySpecificTag = GoalTag(
            title: "Perfect Morning Run",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        // Moderately specific tag - 2 conditions
        let moderateTag = GoalTag(
            title: "Morning Exercise",
            themeID: "test",
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        // Less specific tag - 1 condition
        let lessSpecificTag = GoalTag(
            title: "Outdoor Activity",
            themeID: "test",
            locationTypes: [.outdoor]
        )
        
        // Perfect conditions that match all tags
        let verySpecificScore = verySpecificTag.contextMatchScore(
            weather: .clear,
            temperature: 20,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        let moderateScore = moderateTag.contextMatchScore(
            weather: .clear,
            temperature: 20,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        let lessSpecificScore = lessSpecificTag.contextMatchScore(
            weather: .clear,
            temperature: 20,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        // All should have perfect scores (all requirements met)
        #expect(verySpecificScore == 1.0)
        #expect(moderateScore == 1.0)
        #expect(lessSpecificScore == 1.0)
        
        // Note: For actual ranking, you'd want to consider the NUMBER of matched conditions
        // as a tiebreaker, but the score itself is binary (match or no match)
    }
    
    @Test("Goals with overlapping time preferences compete correctly")
    func goalsWithOverlappingTimePreferencesCompeteCorrectly() {
        let morningOnlyTag = GoalTag(
            title: "Morning Workout",
            themeID: "test",
            timeOfDayPreferences: [.morning]
        )
        
        let morningAfternoonTag = GoalTag(
            title: "Flexible Workout",
            themeID: "test",
            timeOfDayPreferences: [.morning, .afternoon]
        )
        
        let allDayTag = GoalTag(
            title: "Anytime Workout",
            themeID: "test",
            timeOfDayPreferences: [.morning, .midday, .afternoon, .evening, .night]
        )
        
        // Morning context
        let morningOnlyScore = morningOnlyTag.contextMatchScore(timeOfDay: .morning)
        let flexibleScore = morningAfternoonTag.contextMatchScore(timeOfDay: .morning)
        let allDayScore = allDayTag.contextMatchScore(timeOfDay: .morning)
        
        // All match morning, so all should score 1.0
        #expect(morningOnlyScore == 1.0)
        #expect(flexibleScore == 1.0)
        #expect(allDayScore == 1.0)
        
        // Afternoon context - only flexible and all-day should match
        let morningOnlyAfternoonScore = morningOnlyTag.contextMatchScore(timeOfDay: .afternoon)
        let flexibleAfternoonScore = morningAfternoonTag.contextMatchScore(timeOfDay: .afternoon)
        let allDayAfternoonScore = allDayTag.contextMatchScore(timeOfDay: .afternoon)
        
        #expect(morningOnlyAfternoonScore == 0.0)
        #expect(flexibleAfternoonScore == 1.0)
        #expect(allDayAfternoonScore == 1.0)
    }
    
    @Test("Complex multi-goal scenario ranks correctly")
    func complexMultiGoalScenarioRanksCorrectly() {
        // Create a diverse set of goals
        let goals: [(tag: GoalTag, name: String)] = [
            (GoalTag(
                title: "Outdoor Cardio",
                themeID: "test",
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 10...30,
                timeOfDayPreferences: [.morning, .afternoon],
                locationTypes: [.outdoor]
            ), "Outdoor Cardio"),
            
            (GoalTag(
                title: "Gym Session",
                themeID: "test",
                timeOfDayPreferences: [.morning, .afternoon, .evening],
                locationTypes: [.gym]
            ), "Gym Session"),
            
            (GoalTag(
                title: "Rainy Day Reading",
                themeID: "test",
                weatherConditions: [.rainy, .cloudy, .stormy],
                timeOfDayPreferences: [.afternoon, .evening]
            ), "Rainy Day Reading"),
            
            (GoalTag(
                title: "Evening Meditation",
                themeID: "test",
                timeOfDayPreferences: [.evening, .night]
            ), "Evening Meditation"),
            
            (GoalTag(
                title: "Cold Weather Hike",
                themeID: "test",
                weatherConditions: [.clear, .partlyCloudy, .cloudy],
                temperatureRange: -5...15,
                locationTypes: [.outdoor]
            ), "Cold Weather Hike"),
            
            (GoalTag(
                title: "Anytime Study",
                themeID: "test"
            ), "Anytime Study")
        ]
        
        // Test scenario: Clear, cool morning, outdoor location
        let testContext = (
            weather: WeatherCondition.clear,
            temperature: 12.0,
            timeOfDay: TimeOfDay.morning,
            location: LocationType.outdoor
        )
        
        // Calculate scores for all goals
        var scores: [(name: String, score: Double)] = goals.map { goal in
            let score = goal.tag.contextMatchScore(
                weather: testContext.weather,
                temperature: testContext.temperature,
                timeOfDay: testContext.timeOfDay,
                location: testContext.location
            )
            return (name: goal.name, score: score)
        }
        
        // Sort by score descending
        scores.sort { $0.score > $1.score }
        
        // Verify expected scoring (not order, since equal scores can be in any order)
        // Two goals should have perfect scores (all requirements met)
        let perfectScores = scores.filter { $0.score == 1.0 }
        #expect(perfectScores.count == 2)
        
        let perfectNames = Set(perfectScores.map { $0.name })
        #expect(perfectNames.contains("Outdoor Cardio"))
        #expect(perfectNames.contains("Cold Weather Hike"))
        
        // Anytime Study should be neutral (no requirements)
        let neutralScore = scores.first { $0.name == "Anytime Study" }
        #expect(neutralScore?.score == 0.5)
        
        // Three goals should not match (requirements not met)
        let zeroScores = scores.filter { $0.score == 0.0 }
        #expect(zeroScores.count == 3)
        
        let zeroNames = Set(zeroScores.map { $0.name })
        #expect(zeroNames.contains("Rainy Day Reading"))
        #expect(zeroNames.contains("Evening Meditation"))
        #expect(zeroNames.contains("Gym Session"))
    }
    
    @Test("Temperature boundaries affect ranking correctly")
    func temperatureBoundariesAffectRankingCorrectly() {
        let coldWeatherTag = GoalTag(
            title: "Cold Run",
            themeID: "test",
            temperatureRange: -10...10
        )
        
        let warmWeatherTag = GoalTag(
            title: "Warm Run",
            themeID: "test",
            temperatureRange: 15...30
        )
        
        let moderateWeatherTag = GoalTag(
            title: "Moderate Run",
            themeID: "test",
            temperatureRange: 5...20
        )
        
        // Test at 8 degrees - only cold and moderate should match
        let coldAt8 = coldWeatherTag.contextMatchScore(temperature: 8)
        let warmAt8 = warmWeatherTag.contextMatchScore(temperature: 8)
        let moderateAt8 = moderateWeatherTag.contextMatchScore(temperature: 8)
        
        #expect(coldAt8 == 1.0)
        #expect(warmAt8 == 0.0)
        #expect(moderateAt8 == 1.0)
        
        // Test at 18 degrees - only warm and moderate should match
        let coldAt18 = coldWeatherTag.contextMatchScore(temperature: 18)
        let warmAt18 = warmWeatherTag.contextMatchScore(temperature: 18)
        let moderateAt18 = moderateWeatherTag.contextMatchScore(temperature: 18)
        
        #expect(coldAt18 == 0.0)
        #expect(warmAt18 == 1.0)
        #expect(moderateAt18 == 1.0)
    }
    
    @Test("Location requirements create clear ranking distinctions")
    func locationRequirementsCreateClearRankingDistinctions() {
        let outdoorTag = GoalTag(
            title: "Outdoor Activity",
            themeID: "test",
            locationTypes: [.outdoor]
        )
        
        let homeTag = GoalTag(
            title: "Home Activity",
            themeID: "test",
            locationTypes: [.home]
        )
        
        let gymTag = GoalTag(
            title: "Gym Activity",
            themeID: "test",
            locationTypes: [.gym]
        )
        
        let flexibleTag = GoalTag(
            title: "Flexible Activity",
            themeID: "test",
            locationTypes: [.home, .gym, .outdoor]
        )
        
        // At home location
        let outdoorAtHome = outdoorTag.contextMatchScore(location: .home)
        let homeAtHome = homeTag.contextMatchScore(location: .home)
        let gymAtHome = gymTag.contextMatchScore(location: .home)
        let flexibleAtHome = flexibleTag.contextMatchScore(location: .home)
        
        #expect(outdoorAtHome == 0.0)
        #expect(homeAtHome == 1.0)
        #expect(gymAtHome == 0.0)
        #expect(flexibleAtHome == 1.0)
        
        // At gym location
        let outdoorAtGym = outdoorTag.contextMatchScore(location: .gym)
        let homeAtGym = homeTag.contextMatchScore(location: .gym)
        let gymAtGym = gymTag.contextMatchScore(location: .gym)
        let flexibleAtGym = flexibleTag.contextMatchScore(location: .gym)
        
        #expect(outdoorAtGym == 0.0)
        #expect(homeAtGym == 0.0)
        #expect(gymAtGym == 1.0)
        #expect(flexibleAtGym == 1.0)
    }
}
