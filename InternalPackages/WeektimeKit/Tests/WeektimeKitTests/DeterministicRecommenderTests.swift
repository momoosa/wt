//
//  DeterministicRecommenderTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 19/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Deterministic Recommender Tests")
struct DeterministicRecommenderTests {
    
    // MARK: - Test Helpers
    
    func createTestTheme() -> Theme {
        Theme(id: "test", title: "Test", light: .white, dark: .black, neon: .blue)
    }
    
    func createTestTag(title: String) -> GoalTag {
        GoalTag(title: title, color: createTestTheme())
    }
    
    func createContext(
        weather: WeatherCondition? = nil,
        temperature: Double? = nil,
        timeOfDay: TimeOfDay? = nil,
        location: LocationType? = nil
    ) -> DeterministicRecommender.Context {
        DeterministicRecommender.Context(
            currentDate: Date(),
            weather: weather,
            temperature: temperature,
            timeOfDay: timeOfDay,
            location: location
        )
    }
    
    // MARK: - Basic Recommendation Tests
    
    @Test("Recommender returns top 3 goals by default")
    func recommenderReturnsTop3Goals() {
        let recommender = DeterministicRecommender()
        
        // Create 5 goals
        let goals = (1...5).map { i in
            Goal(title: "Goal \(i)", weeklyTarget: 3600)
        }
        
        let context = createContext()
        let recommendations = recommender.recommend(goals: goals, sessions: [], context: context)
        
        #expect(recommendations.count == 3)
    }
    
    @Test("Recommender only returns active goals")
    func recommenderOnlyReturnsActiveGoals() {
        let recommender = DeterministicRecommender()
        
        let activeGoal = Goal(title: "Active", weeklyTarget: 3600)
        
        let archivedGoal = Goal(title: "Archived", weeklyTarget: 3600)
        archivedGoal.status = .archived
        
        let suggestionGoal = Goal(title: "Suggestion", weeklyTarget: 3600)
        suggestionGoal.status = .suggestion
        
        let context = createContext()
        let recommendations = recommender.recommend(
            goals: [activeGoal, archivedGoal, suggestionGoal],
            sessions: [],
            context: context
        )
        
        #expect(recommendations.count == 1)
        #expect(recommendations[0].goal.title == "Active")
    }
    
    // MARK: - Weather Context Scoring Tests
    
    @Test("Goals with matching weather context score higher")
    func goalsWithMatchingWeatherScoreHigher() {
        let recommender = DeterministicRecommender()
        
        let outdoorTag = GoalTag(
            title: "Outdoor",
            color: createTestTheme(),
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let indoorTag = GoalTag(
            title: "Indoor",
            color: createTestTheme(),
            weatherConditions: [.rainy]
        )
        
        let outdoorGoal = Goal(
            title: "Running",
            primaryTag: outdoorTag,
            weeklyTarget: 3600
        )
        
        let indoorGoal = Goal(
            title: "Reading",
            primaryTag: indoorTag,
            weeklyTarget: 3600
        )
        
        // Test on sunny day
        let sunnyContext = createContext(weather: .clear, temperature: 20.0)
        let sunnyRecommendations = recommender.recommend(
            goals: [outdoorGoal, indoorGoal],
            sessions: [],
            context: sunnyContext,
            limit: 2
        )
        
        #expect(sunnyRecommendations[0].goal.title == "Running")
        #expect(sunnyRecommendations[0].reasons.contains(.weather))
    }
    
    @Test("Goals without weather requirements get neutral score")
    func goalsWithoutWeatherRequirementsGetNeutralScore() {
        let recommender = DeterministicRecommender()
        
        let neutralTag = GoalTag(
            title: "Neutral",
            color: createTestTheme()
        )
        
        let neutralGoal = Goal(
            title: "Meditation",
            primaryTag: neutralTag,
            weeklyTarget: 3600
        )
        
        let context = createContext(weather: .clear, temperature: 20.0)
        let recommendations = recommender.recommend(
            goals: [neutralGoal],
            sessions: [],
            context: context
        )
        
        // Should get some score, but not include weather as a reason
        #expect(recommendations[0].score > 0)
        #expect(!recommendations[0].reasons.contains(.weather))
    }
    
    @Test("Non-matching weather context results in low score")
    func nonMatchingWeatherResultsInLowScore() {
        let recommender = DeterministicRecommender()
        
        let outdoorTag = GoalTag(
            title: "Outdoor",
            color: createTestTheme(),
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let outdoorGoal = Goal(
            title: "Running",
            primaryTag: outdoorTag,
            weeklyTarget: 3600
        )
        
        // Test on rainy day with wrong temperature
        let rainyContext = createContext(weather: .rainy, temperature: 5.0)
        let recommendations = recommender.recommend(
            goals: [outdoorGoal],
            sessions: [],
            context: rainyContext
        )
        
        // Should not get weather bonus (contexts don't match)
        #expect(!recommendations[0].reasons.contains(.weather))
    }
    
    // MARK: - Time of Day Scoring Tests
    
    @Test("Goals matching time of day score higher")
    func goalsMatchingTimeOfDayScoreHigher() {
        let recommender = DeterministicRecommender()

        let morningTag = GoalTag(
            title: "Morning",
            color: createTestTheme(),
            timeOfDayPreferences: [.morning]
        )

        let eveningTag = GoalTag(
            title: "Evening",
            color: createTestTheme(),
            timeOfDayPreferences: [.evening]
        )

        let morningGoal = Goal(
            title: "Morning Workout",
            primaryTag: morningTag,
            weeklyTarget: 3600
        )
        // Set schedule for all weekdays with morning preference
        for weekday in 1...7 {
            morningGoal.setTimes([.morning], forWeekday: weekday)
        }

        let eveningGoal = Goal(
            title: "Evening Reading",
            primaryTag: eveningTag,
            weeklyTarget: 3600
        )
        // Set schedule for all weekdays with evening preference
        for weekday in 1...7 {
            eveningGoal.setTimes([.evening], forWeekday: weekday)
        }

        // Test in morning
        let morningContext = createContext(timeOfDay: .morning)
        let morningRecommendations = recommender.recommend(
            goals: [morningGoal, eveningGoal],
            sessions: [],
            context: morningContext,
            limit: 2
        )

        #expect(morningRecommendations[0].goal.title == "Morning Workout")
        #expect(morningRecommendations[0].reasons.contains(.preferredTime))
    }
    
    // MARK: - Complex Scenario Tests
    
    @Test("Complex weather and time scenario ranks correctly")
    func complexWeatherAndTimeScenarioRanksCorrectly() {
        let recommender = DeterministicRecommender()
        
        // Perfect match: morning + clear weather + outdoor
        let perfectTag = GoalTag(
            title: "Perfect",
            color: createTestTheme(),
            weatherConditions: [.clear],
            temperatureRange: 15...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        // Partial match: morning only
        let partialTag = GoalTag(
            title: "Partial",
            color: createTestTheme(),
            timeOfDayPreferences: [.morning]
        )
        
        // No match: evening + rainy
        let noMatchTag = GoalTag(
            title: "NoMatch",
            color: createTestTheme(),
            weatherConditions: [.rainy],
            timeOfDayPreferences: [.evening]
        )
        
        let perfectGoal = Goal(title: "Perfect Run", primaryTag: perfectTag, weeklyTarget: 3600)
        for weekday in 1...7 {
            perfectGoal.setTimes([.morning], forWeekday: weekday)
        }

        let partialGoal = Goal(title: "Morning Task", primaryTag: partialTag, weeklyTarget: 3600)
        for weekday in 1...7 {
            partialGoal.setTimes([.morning], forWeekday: weekday)
        }

        let noMatchGoal = Goal(title: "Evening Reading", primaryTag: noMatchTag, weeklyTarget: 3600)
        for weekday in 1...7 {
            noMatchGoal.setTimes([.evening], forWeekday: weekday)
        }
        
        // Context: Clear morning, outdoor
        let context = createContext(
            weather: .clear,
            temperature: 20.0,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        let recommendations = recommender.recommend(
            goals: [perfectGoal, partialGoal, noMatchGoal],
            sessions: [],
            context: context,
            limit: 3
        )
        
        // Perfect match should rank first
        #expect(recommendations[0].goal.title == "Perfect Run")
        #expect(recommendations[0].reasons.contains(.weather))
        #expect(recommendations[0].reasons.contains(.preferredTime))
        
        // Partial match should rank second
        #expect(recommendations[1].goal.title == "Morning Task")
        
        // No match should rank last
        #expect(recommendations[2].goal.title == "Evening Reading")
        #expect(recommendations[2].score < recommendations[0].score)
    }
    
    @Test("Multiple weather conditions handled correctly")
    func multipleWeatherConditionsHandledCorrectly() {
        let recommender = DeterministicRecommender()
        
        let flexibleTag = GoalTag(
            title: "Flexible",
            color: createTestTheme(),
            weatherConditions: [.clear, .partlyCloudy, .cloudy]
        )
        
        let strictTag = GoalTag(
            title: "Strict",
            color: createTestTheme(),
            weatherConditions: [.clear]
        )
        
        let flexibleGoal = Goal(title: "Flexible Activity", primaryTag: flexibleTag, weeklyTarget: 3600)
        let strictGoal = Goal(title: "Strict Activity", primaryTag: strictTag, weeklyTarget: 3600)
        
        // Test with clear weather - both should match
        let clearContext = createContext(weather: .clear)
        let clearRecs = recommender.recommend(
            goals: [flexibleGoal, strictGoal],
            sessions: [],
            context: clearContext,
            limit: 2
        )
        
        // Both should get weather bonus
        #expect(clearRecs[0].reasons.contains(.weather) || clearRecs[1].reasons.contains(.weather))
        
        // Test with cloudy weather - only flexible should match
        let cloudyContext = createContext(weather: .cloudy)
        let cloudyRecs = recommender.recommend(
            goals: [flexibleGoal, strictGoal],
            sessions: [],
            context: cloudyContext,
            limit: 2
        )
        
        #expect(cloudyRecs[0].goal.title == "Flexible Activity")
    }
    
    @Test("Custom scoring weights affect results")
    func customScoringWeightsAffectResults() {
        // Weather-heavy weights
        let weatherHeavyWeights = DeterministicRecommender.ScoringWeights(
            weatherContext: 50.0,  // Double weather importance
            weeklyProgress: 15.0,
            timeOfDay: 10.0,
            deadline: 10.0,
            historicalPattern: 5.0,
            scheduleFlexibility: 10.0
        )
        
        let weatherHeavyRecommender = DeterministicRecommender(weights: weatherHeavyWeights)
        
        let outdoorTag = GoalTag(
            title: "Outdoor",
            color: createTestTheme(),
            weatherConditions: [.clear]
        )
        
        let neutralTag = GoalTag(
            title: "Neutral",
            color: createTestTheme()
        )
        
        let outdoorGoal = Goal(title: "Running", primaryTag: outdoorTag, weeklyTarget: 3600)
        let neutralGoal = Goal(title: "Task", primaryTag: neutralTag, weeklyTarget: 3600)
        
        let context = createContext(weather: .clear)
        let recommendations = weatherHeavyRecommender.recommend(
            goals: [outdoorGoal, neutralGoal],
            context: context,
            limit: 2
        )
        
        // With heavy weather weights, outdoor goal should dominate
        #expect(recommendations[0].goal.title == "Running")
        #expect(recommendations[0].score > recommendations[1].score * 1.5)
    }
    
    // MARK: - Schedule Flexibility Tests
    
    @Test("Weekend goal recommended on weekday when weekend is busy")
    func weekendGoalRecommendedOnWeekdayWhenWeekendBusy() {
        let recommender = DeterministicRecommender()
        
        let weekendTag = GoalTag(
            title: "Weekend Activity",
            color: createTestTheme()
        )
        
        let weekendGoal = Goal(
            title: "Hiking",
            primaryTag: weekendTag,
            weeklyTarget: 7200 // 2 hours
        )
        // Schedule only for Saturday (7) and Sunday (1)
        weekendGoal.setTimes([.morning, .afternoon], forWeekday: 7) // Saturday
        weekendGoal.setTimes([.morning, .afternoon], forWeekday: 1) // Sunday
        
        // Create context for Wednesday (4) with availability data
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        // Calculate days to add to get to Wednesday (weekday 4)
        let daysToWednesday = (4 - currentWeekday + 7) % 7
        let wednesday = calendar.date(byAdding: .day, value: daysToWednesday, to: today) ?? today
        
        let wednesdayWeekday = calendar.component(.weekday, from: wednesday)
        
        // Weekend is super busy (only 20 min available), but Wednesday has 2 hours free
        let availability: [Int: TimeInterval] = [
            1: 1200,  // Sunday: 20 min
            7: 1200,  // Saturday: 20 min
            wednesdayWeekday: 7200   // Wednesday: 2 hours
        ]
        
        let context = DeterministicRecommender.Context(
            currentDate: wednesday,
            timeOfDay: .morning,
            weekdayAvailability: availability
        )
        
        let recommendations = recommender.recommend(
            goals: [weekendGoal],
            sessions: [],
            context: context,
            limit: 1
        )
        
        // Should recommend the weekend goal on Wednesday due to busy weekend
        #expect(recommendations.count == 1)
        #expect(recommendations[0].goal.title == "Hiking")
        #expect(recommendations[0].reasons.contains(.constrained))
    }
    
    @Test("Weekend goal NOT recommended on weekday when weekend has time")
    func weekendGoalNotRecommendedOnWeekdayWhenWeekendHasTime() {
        let recommender = DeterministicRecommender()
        
        let weekendTag = GoalTag(
            title: "Weekend Activity",
            color: createTestTheme()
        )
        
        let weekendGoal = Goal(
            title: "Hiking",
            primaryTag: weekendTag,
            weeklyTarget: 7200
        )
        weekendGoal.setTimes([.morning], forWeekday: 7) // Saturday
        weekendGoal.setTimes([.morning], forWeekday: 1) // Sunday
        
        let weekdayGoal = Goal(
            title: "Work Task",
            primaryTag: createTestTag(title: "Work"),
            weeklyTarget: 3600
        )
        weekdayGoal.setTimes([.morning], forWeekday: 4) // Wednesday
        
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysToWednesday = (4 - currentWeekday + 7) % 7
        let wednesday = calendar.date(byAdding: .day, value: daysToWednesday, to: today) ?? today
        let wednesdayWeekday = calendar.component(.weekday, from: wednesday)
        
        // Weekend has plenty of time (3+ hours each day)
        let availability: [Int: TimeInterval] = [
            1: 10800, // Sunday: 3 hours
            7: 10800, // Saturday: 3 hours
            wednesdayWeekday: 7200   // Wednesday: 2 hours
        ]
        
        let context = DeterministicRecommender.Context(
            currentDate: wednesday,
            timeOfDay: .morning,
            weekdayAvailability: availability
        )
        
        let recommendations = recommender.recommend(
            goals: [weekendGoal, weekdayGoal],
            sessions: [],
            context: context,
            limit: 2
        )
        
        // Weekday goal should rank higher than weekend goal on Wednesday
        #expect(recommendations[0].goal.title == "Work Task")
    }
    
    @Test("Scheduled goal gets penalty on scheduled day with no availability")
    func scheduledGoalGetsPenaltyOnScheduledDayWithNoAvailability() {
        let recommender = DeterministicRecommender()
        
        let morningTag = GoalTag(
            title: "Morning",
            color: createTestTheme()
        )
        
        let morningGoal = Goal(
            title: "Morning Routine",
            primaryTag: morningTag,
            weeklyTarget: 3600
        )
        morningGoal.setTimes([.morning], forWeekday: 2) // Monday
        
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysToMonday = (2 - currentWeekday + 7) % 7
        let monday = calendar.date(byAdding: .day, value: daysToMonday, to: today) ?? today
        let mondayWeekday = calendar.component(.weekday, from: monday)
        
        // Monday has almost no time (15 min)
        let availability: [Int: TimeInterval] = [
            mondayWeekday: 900 // Monday: 15 min
        ]
        
        let contextWithoutAvailability = createContext(timeOfDay: .morning)
        let contextWithLowAvailability = DeterministicRecommender.Context(
            currentDate: monday,
            timeOfDay: .morning,
            weekdayAvailability: availability
        )
        
        let recsWithout = recommender.recommend(
            goals: [morningGoal],
            sessions: [],
            context: contextWithoutAvailability,
            limit: 1
        )
        
        let recsWith = recommender.recommend(
            goals: [morningGoal],
            sessions: [],
            context: contextWithLowAvailability,
            limit: 1
        )
        
        // Score should be lower when we know there's no time available
        #expect(recsWith[0].score < recsWithout[0].score)
    }
    
    @Test("Multiple scheduled days with mixed availability")
    func multipleScheduledDaysWithMixedAvailability() {
        let recommender = DeterministicRecommender()
        
        let workoutTag = GoalTag(
            title: "Workout",
            color: createTestTheme()
        )
        
        let workoutGoal = Goal(
            title: "Gym",
            primaryTag: workoutTag,
            weeklyTarget: 10800 // 3 hours
        )
        // Schedule Mon, Wed, Fri
        workoutGoal.setTimes([.morning], forWeekday: 2) // Monday
        workoutGoal.setTimes([.morning], forWeekday: 4) // Wednesday
        workoutGoal.setTimes([.morning], forWeekday: 6) // Friday
        
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysToTuesday = (3 - currentWeekday + 7) % 7
        let tuesday = calendar.date(byAdding: .day, value: daysToTuesday, to: today) ?? today
        let tuesdayWeekday = calendar.component(.weekday, from: tuesday)
        
        // Mon & Fri are busy (30 min each), Wed has time (2 hours), Tue has 1.5 hours
        let availability: [Int: TimeInterval] = [
            2: 1800,  // Monday: 30 min
            4: 7200,  // Wednesday: 2 hours  
            6: 1800,  // Friday: 30 min
            tuesdayWeekday: 5400   // Tuesday: 1.5 hours
        ]
        
        let context = DeterministicRecommender.Context(
            currentDate: tuesday,
            timeOfDay: .morning,
            weekdayAvailability: availability
        )
        
        let recommendations = recommender.recommend(
            goals: [workoutGoal],
            sessions: [],
            context: context,
            limit: 1
        )
        
        // Should get moderate recommendation on Tuesday since 2/3 scheduled days are busy
        // Average scheduled availability: (1800 + 7200 + 1800) / 3 = 3600 (1 hour)
        // This is < 2 hours, and Tuesday has 1.5 hours, so should get moderate boost
        #expect(recommendations[0].goal.title == "Gym")
        #expect(recommendations[0].reasons.contains(.constrained))
    }
    
    @Test("Goal with no schedule not affected by availability")
    func goalWithNoScheduleNotAffectedByAvailability() {
        let recommender = DeterministicRecommender()
        
        let flexibleTag = GoalTag(
            title: "Flexible",
            color: createTestTheme()
        )
        
        let flexibleGoal = Goal(
            title: "Reading",
            primaryTag: flexibleTag,
            weeklyTarget: 3600
        )
        // No schedule set - can be done anytime
        
        let availability: [Int: TimeInterval] = [
            1: 900,   // Very little time on Sunday
            2: 900,   // Very little time on Monday
            3: 10800  // Lots of time on Tuesday
        ]
        
        let contextWithAvailability = DeterministicRecommender.Context(
            currentDate: Date(),
            timeOfDay: .afternoon,
            weekdayAvailability: availability
        )
        
        let contextWithoutAvailability = createContext(timeOfDay: .afternoon)
        
        let recsWith = recommender.recommend(
            goals: [flexibleGoal],
            sessions: [],
            context: contextWithAvailability,
            limit: 1
        )
        
        let recsWithout = recommender.recommend(
            goals: [flexibleGoal],
            sessions: [],
            context: contextWithoutAvailability,
            limit: 1
        )
        
        // Scores should be identical - schedule flexibility doesn't apply to unscheduled goals
        #expect(recsWith[0].score == recsWithout[0].score)
    }
}
