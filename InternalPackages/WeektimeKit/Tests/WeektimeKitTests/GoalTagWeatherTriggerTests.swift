//
//  GoalTagWeatherTriggerTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Tag Weather Trigger Tests")
struct GoalTagWeatherTriggerTests {
    
    // MARK: - Test Helpers
    
    
    // MARK: - Weather Matching Tests
    
    @Test("Tag with sunny weather requirement matches clear weather")
    func tagWithSunnyWeatherMatchesClearWeather() {
        let tag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear]
        )
        
        #expect(tag.matchesWeather(.clear) == true)
    }
    
    @Test("Tag with sunny weather requirement does not match rainy weather")
    func tagWithSunnyWeatherDoesNotMatchRainyWeather() {
        let tag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy]
        )
        
        #expect(tag.matchesWeather(.rainy) == false)
    }
    
    @Test("Tag with multiple weather conditions matches any of them")
    func tagWithMultipleWeatherConditionsMatchesAny() {
        let tag = GoalTag(
            title: "Outdoor Activity",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy, .cloudy]
        )
        
        #expect(tag.matchesWeather(.clear) == true)
        #expect(tag.matchesWeather(.partlyCloudy) == true)
        #expect(tag.matchesWeather(.cloudy) == true)
        #expect(tag.matchesWeather(.rainy) == false)
        #expect(tag.matchesWeather(.snowy) == false)
    }
    
    @Test("Tag without weather requirements matches any weather")
    func tagWithoutWeatherRequirementsMatchesAnyWeather() {
        let tag = GoalTag(
            title: "Indoor Activity",
            themeID: "test"
        )
        
        #expect(tag.matchesWeather(.clear) == true)
        #expect(tag.matchesWeather(.rainy) == true)
        #expect(tag.matchesWeather(.snowy) == true)
        #expect(tag.matchesWeather(.stormy) == true)
    }
    
    @Test("Tag with weather requirements returns false for nil weather")
    func tagWithWeatherRequirementsReturnsFalseForNilWeather() {
        let tag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear]
        )
        
        #expect(tag.matchesWeather(nil) == false)
    }
    
    @Test("Goal with rainy weather preference is highly ranked when raining")
    func goalWithRainyWeatherPreferenceHighlyRankedWhenRaining() {
        let indoorTag = GoalTag(
            title: "Indoor Reading",
            themeID: "test",
            weatherConditions: [.rainy, .stormy]
        )
        
        // Should match rainy weather
        #expect(indoorTag.matchesWeather(.rainy) == true)
        
        // Should not match sunny weather
        #expect(indoorTag.matchesWeather(.clear) == false)
        
        // Context match score should be high when raining
        let rainyScore = indoorTag.contextMatchScore(weather: .rainy)
        #expect(rainyScore > 0.5)
    }
    
    // MARK: - Temperature Matching Tests
    
    @Test("Tag with temperature range matches temperature within range")
    func tagWithTemperatureRangeMatchesWithinRange() {
        let tag = GoalTag(
            title: "Outdoor Cardio",
            themeID: "test",
            temperatureRange: 10...25
        )
        
        #expect(tag.matchesTemperature(10) == true)
        #expect(tag.matchesTemperature(15) == true)
        #expect(tag.matchesTemperature(25) == true)
    }
    
    @Test("Tag with temperature range does not match temperature outside range")
    func tagWithTemperatureRangeDoesNotMatchOutsideRange() {
        let tag = GoalTag(
            title: "Outdoor Cardio",
            themeID: "test",
            temperatureRange: 10...25
        )
        
        #expect(tag.matchesTemperature(5) == false)
        #expect(tag.matchesTemperature(30) == false)
        #expect(tag.matchesTemperature(-5) == false)
    }
    
    @Test("Tag without temperature requirements matches any temperature")
    func tagWithoutTemperatureRequirementsMatchesAnyTemperature() {
        let tag = GoalTag(
            title: "Indoor Activity",
            themeID: "test"
        )
        
        #expect(tag.matchesTemperature(-10) == true)
        #expect(tag.matchesTemperature(0) == true)
        #expect(tag.matchesTemperature(35) == true)
    }
    
    @Test("Tag with temperature requirements returns false for nil temperature")
    func tagWithTemperatureRequirementsReturnsFalseForNilTemperature() {
        let tag = GoalTag(
            title: "Outdoor Cardio",
            themeID: "test",
            temperatureRange: 10...25
        )
        
        #expect(tag.matchesTemperature(nil) == false)
    }
    
    @Test("Cold weather tag matches low temperatures")
    func coldWeatherTagMatchesLowTemperatures() {
        let winterTag = GoalTag(
            title: "Winter Sports",
            themeID: "test",
            weatherConditions: [.snowy],
            temperatureRange: -10...5
        )
        
        #expect(winterTag.matchesTemperature(-5) == true)
        #expect(winterTag.matchesTemperature(0) == true)
        #expect(winterTag.matchesTemperature(15) == false)
    }
    
    // MARK: - Time of Day Matching Tests
    
    @Test("Tag with morning preference matches morning time")
    func tagWithMorningPreferenceMatchesMorningTime() {
        let tag = GoalTag(
            title: "Morning Workout",
            themeID: "test",
            timeOfDayPreferences: [.morning]
        )
        
        #expect(tag.matchesTimeOfDay(.morning) == true)
        #expect(tag.matchesTimeOfDay(.evening) == false)
    }
    
    @Test("Tag with multiple time preferences matches any of them")
    func tagWithMultipleTimePreferencesMatchesAny() {
        let tag = GoalTag(
            title: "Flexible Activity",
            themeID: "test",
            timeOfDayPreferences: [.morning, .afternoon, .evening]
        )
        
        #expect(tag.matchesTimeOfDay(.morning) == true)
        #expect(tag.matchesTimeOfDay(.afternoon) == true)
        #expect(tag.matchesTimeOfDay(.evening) == true)
        #expect(tag.matchesTimeOfDay(.night) == false)
    }
    
    @Test("Tag without time preferences matches any time")
    func tagWithoutTimePreferencesMatchesAnyTime() {
        let tag = GoalTag(
            title: "Anytime Activity",
            themeID: "test"
        )
        
        #expect(tag.matchesTimeOfDay(.morning) == true)
        #expect(tag.matchesTimeOfDay(.midday) == true)
        #expect(tag.matchesTimeOfDay(.night) == true)
    }
    
    @Test("Tag with time preferences returns false for nil time")
    func tagWithTimePreferencesReturnsFalseForNilTime() {
        let tag = GoalTag(
            title: "Morning Workout",
            themeID: "test",
            timeOfDayPreferences: [.morning]
        )
        
        #expect(tag.matchesTimeOfDay(nil) == false)
    }
    
    // MARK: - Location Matching Tests
    
    @Test("Tag with outdoor location requirement matches outdoor location")
    func tagWithOutdoorLocationMatchesOutdoorLocation() {
        let tag = GoalTag(
            title: "Hiking",
            themeID: "test",
            locationTypes: [.outdoor]
        )
        
        #expect(tag.matchesLocation(.outdoor) == true)
        #expect(tag.matchesLocation(.home) == false)
    }
    
    @Test("Tag with multiple location types matches any of them")
    func tagWithMultipleLocationTypesMatchesAny() {
        let tag = GoalTag(
            title: "Flexible Workout",
            themeID: "test",
            locationTypes: [.home, .gym, .outdoor]
        )
        
        #expect(tag.matchesLocation(.home) == true)
        #expect(tag.matchesLocation(.gym) == true)
        #expect(tag.matchesLocation(.outdoor) == true)
        #expect(tag.matchesLocation(.office) == false)
    }
    
    @Test("Tag without location requirements matches any location")
    func tagWithoutLocationRequirementsMatchesAnyLocation() {
        let tag = GoalTag(
            title: "Anywhere Activity",
            themeID: "test"
        )
        
        #expect(tag.matchesLocation(.home) == true)
        #expect(tag.matchesLocation(.outdoor) == true)
        #expect(tag.matchesLocation(.office) == true)
    }
    
    // MARK: - Comprehensive Context Matching Tests
    
    @Test("Tag matches context when all conditions are met")
    func tagMatchesContextWhenAllConditionsMet() {
        let tag = GoalTag(
            title: "Perfect Morning Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        let matches = tag.matchesContext(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        #expect(matches == true)
    }
    
    @Test("Tag does not match context when one condition fails")
    func tagDoesNotMatchContextWhenOneConditionFails() {
        let tag = GoalTag(
            title: "Perfect Morning Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        // Wrong weather
        let matchesWrongWeather = tag.matchesContext(
            weather: .rainy,
            temperature: 18,
            timeOfDay: .morning,
            location: .outdoor
        )
        #expect(matchesWrongWeather == false)
        
        // Wrong temperature
        let matchesWrongTemp = tag.matchesContext(
            weather: .clear,
            temperature: 35,
            timeOfDay: .morning,
            location: .outdoor
        )
        #expect(matchesWrongTemp == false)
        
        // Wrong time
        let matchesWrongTime = tag.matchesContext(
            weather: .clear,
            temperature: 18,
            timeOfDay: .night,
            location: .outdoor
        )
        #expect(matchesWrongTime == false)
        
        // Wrong location
        let matchesWrongLocation = tag.matchesContext(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning,
            location: .home
        )
        #expect(matchesWrongLocation == false)
    }
    
    @Test("Tag with no requirements matches any context")
    func tagWithNoRequirementsMatchesAnyContext() {
        let tag = GoalTag(
            title: "Flexible Activity",
            themeID: "test"
        )
        
        let matches = tag.matchesContext(
            weather: .rainy,
            temperature: -5,
            timeOfDay: .night,
            location: .commute
        )
        
        #expect(matches == true)
    }
    
    // MARK: - Context Match Score Tests
    
    @Test("Perfect context match returns high score")
    func perfectContextMatchReturnsHighScore() {
        let tag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let score = tag.contextMatchScore(
            weather: .clear,
            temperature: 20
        )
        
        #expect(score == 1.0)
    }
    
    @Test("No match returns zero score")
    func noMatchReturnsZeroScore() {
        let tag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let score = tag.contextMatchScore(
            weather: .rainy,
            temperature: 5
        )
        
        #expect(score == 0.0)
    }
    
    @Test("Partial context information returns zero when required conditions missing")
    func partialContextInformationReturnsZeroWhenRequiredConditionsMissing() {
        let tag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        // Only weather provided - fails because temperature requirement not met
        let scoreWithWeatherOnly = tag.contextMatchScore(weather: .clear)
        #expect(scoreWithWeatherOnly == 0.0)
        
        // Only temperature provided - fails because weather requirement not met
        let scoreWithTempOnly = tag.contextMatchScore(temperature: 20)
        #expect(scoreWithTempOnly == 0.0)
    }
    
    @Test("Single requirement tag returns full score when that requirement is met")
    func singleRequirementTagReturnsFullScoreWhenMet() {
        let weatherOnlyTag = GoalTag(
            title: "Weather Dependent",
            themeID: "test",
            weatherConditions: [.clear]
        )
        
        // Weather requirement met, no other requirements
        let weatherScore = weatherOnlyTag.contextMatchScore(weather: .clear)
        #expect(weatherScore == 1.0)
        
        let tempOnlyTag = GoalTag(
            title: "Temperature Dependent",
            themeID: "test",
            temperatureRange: 15...25
        )
        
        // Temperature requirement met, no other requirements
        let tempScore = tempOnlyTag.contextMatchScore(temperature: 20)
        #expect(tempScore == 1.0)
    }
    
    @Test("Tag with no requirements returns neutral score")
    func tagWithNoRequirementsReturnsNeutralScore() {
        let tag = GoalTag(
            title: "Flexible Activity",
            themeID: "test"
        )
        
        let score = tag.contextMatchScore(
            weather: .clear,
            temperature: 20
        )
        
        #expect(score == 0.5)
    }
    
    @Test("Goal with sunny weather should be ranked higher than indoor goal on sunny day")
    func goalWithSunnyWeatherRankedHigherOnSunnyDay() {
        let outdoorTag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy]
        )
        
        let indoorTag = GoalTag(
            title: "Indoor Gym",
            themeID: "test",
            weatherConditions: [.rainy, .snowy]
        )
        
        let outdoorScore = outdoorTag.contextMatchScore(weather: .clear)
        let indoorScore = indoorTag.contextMatchScore(weather: .clear)
        
        #expect(outdoorScore > indoorScore)
        #expect(outdoorScore == 1.0)
        #expect(indoorScore == 0.0)
    }
    
    @Test("Goal with rainy weather should be ranked higher on rainy day")
    func goalWithRainyWeatherRankedHigherOnRainyDay() {
        let outdoorTag = GoalTag(
            title: "Outdoor Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy]
        )
        
        let indoorTag = GoalTag(
            title: "Indoor Reading",
            themeID: "test",
            weatherConditions: [.rainy, .cloudy]
        )
        
        let outdoorScore = outdoorTag.contextMatchScore(weather: .rainy)
        let indoorScore = indoorTag.contextMatchScore(weather: .rainy)
        
        #expect(indoorScore > outdoorScore)
        #expect(indoorScore == 1.0)
        #expect(outdoorScore == 0.0)
    }
    
    // MARK: - Real-World Scenario Tests
    
    @Test("Outdoor cardio tag matches perfect running conditions")
    func outdoorCardioTagMatchesPerfectRunningConditions() {
        let runningTag = GoalTag(
            title: "Morning Run",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...28,
            timeOfDayPreferences: [.morning, .afternoon],
            locationTypes: [.outdoor]
        )
        
        let perfectMorning = runningTag.matchesContext(
            weather: .clear,
            temperature: 18,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        #expect(perfectMorning == true)
        
        let perfectAfternoon = runningTag.matchesContext(
            weather: .partlyCloudy,
            temperature: 22,
            timeOfDay: .afternoon,
            location: .outdoor
        )
        
        #expect(perfectAfternoon == true)
    }
    
    @Test("Indoor yoga tag is not affected by weather")
    func indoorYogaTagNotAffectedByWeather() {
        let yogaTag = GoalTag(
            title: "Yoga Session",
            themeID: "test",
            timeOfDayPreferences: [.morning, .evening],
            locationTypes: [.home]
        )
        
        let sunnyMorning = yogaTag.matchesContext(
            weather: .clear,
            temperature: 25,
            timeOfDay: .morning,
            location: .home
        )
        
        let rainyMorning = yogaTag.matchesContext(
            weather: .rainy,
            temperature: 10,
            timeOfDay: .morning,
            location: .home
        )
        
        #expect(sunnyMorning == true)
        #expect(rainyMorning == true)
    }
    
    @Test("Winter sports tag only matches cold snowy conditions")
    func winterSportsTagOnlyMatchesColdSnowyConditions() {
        let skiingTag = GoalTag(
            title: "Skiing",
            themeID: "test",
            weatherConditions: [.snowy],
            temperatureRange: -10...5,
            locationTypes: [.outdoor]
        )
        
        let perfectSkiDay = skiingTag.matchesContext(
            weather: .snowy,
            temperature: -2,
            location: .outdoor
        )
        
        let summerDay = skiingTag.matchesContext(
            weather: .clear,
            temperature: 25,
            location: .outdoor
        )
        
        #expect(perfectSkiDay == true)
        #expect(summerDay == false)
    }
}
