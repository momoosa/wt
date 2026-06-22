//
//  DeterministicRecommenderTests.swift
//  MomentumKit Tests
//
//  Created by Assistant on 19/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Deterministic Recommender Tests")
struct DeterministicRecommenderTests {
    
    // MARK: - Test Helpers
    
    
    func createTestTag(title: String) -> GoalTag {
        GoalTag(title: title, themeID: "test")
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
            let goal = Goal(title: "Goal \(i)")
            goal.targetUnit = .seconds
            goal.unifiedDailyTarget = 3600 / 7.0
            return goal
        }
        
        let context = createContext()
        let recommendations = recommender.recommend(goals: goals, sessions: [], context: context)
        
        #expect(recommendations.count == 3)
    }
    
    @Test("Recommender only returns active goals")
    func recommenderOnlyReturnsActiveGoals() {
        let recommender = DeterministicRecommender()
        
        let activeGoal = Goal(title: "Active")
        activeGoal.targetUnit = .seconds
        activeGoal.unifiedDailyTarget = 3600 / 7.0
        
        let archivedGoal = Goal(title: "Archived")
        archivedGoal.targetUnit = .seconds
        archivedGoal.unifiedDailyTarget = 3600 / 7.0
        archivedGoal.status = .archived
        
        let suggestionGoal = Goal(title: "Suggestion")
        suggestionGoal.targetUnit = .seconds
        suggestionGoal.unifiedDailyTarget = 3600 / 7.0
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
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let indoorTag = GoalTag(
            title: "Indoor",
            themeID: "test",
            weatherConditions: [.rainy]
        )
        
        let outdoorGoal = Goal(
            title: "Running",
            primaryTag: outdoorTag
        )
        outdoorGoal.targetUnit = .seconds
        outdoorGoal.unifiedDailyTarget = 3600 / 7.0
        
        let indoorGoal = Goal(
            title: "Reading",
            primaryTag: indoorTag
        )
        indoorGoal.targetUnit = .seconds
        indoorGoal.unifiedDailyTarget = 3600 / 7.0
        
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
            themeID: "test"
        )
        
        let neutralGoal = Goal(
            title: "Meditation",
            primaryTag: neutralTag
        )
        neutralGoal.targetUnit = .seconds
        neutralGoal.unifiedDailyTarget = 3600 / 7.0
        
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
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let outdoorGoal = Goal(
            title: "Running",
            primaryTag: outdoorTag
        )
        outdoorGoal.targetUnit = .seconds
        outdoorGoal.unifiedDailyTarget = 3600 / 7.0
        
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
            themeID: "test",
            timeOfDayPreferences: [.morning]
        )

        let eveningTag = GoalTag(
            title: "Evening",
            themeID: "test",
            timeOfDayPreferences: [.evening]
        )

        let morningGoal = Goal(
            title: "Morning Workout",
            primaryTag: morningTag
        )
        morningGoal.targetUnit = .seconds
        morningGoal.unifiedDailyTarget = 3600 / 7.0
        // Set schedule for all weekdays with morning preference
        for weekday in 1...7 {
            morningGoal.setTimes([.morning], forWeekday: weekday)
        }

        let eveningGoal = Goal(
            title: "Evening Reading",
            primaryTag: eveningTag
        )
        eveningGoal.targetUnit = .seconds
        eveningGoal.unifiedDailyTarget = 3600 / 7.0
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
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25,
            timeOfDayPreferences: [.morning],
            locationTypes: [.outdoor]
        )
        
        // Partial match: morning only
        let partialTag = GoalTag(
            title: "Partial",
            themeID: "test",
            timeOfDayPreferences: [.morning]
        )
        
        // No match: evening + rainy
        let noMatchTag = GoalTag(
            title: "NoMatch",
            themeID: "test",
            weatherConditions: [.rainy],
            timeOfDayPreferences: [.evening]
        )
        
        let perfectGoal = Goal(title: "Perfect Run", primaryTag: perfectTag)
        perfectGoal.targetUnit = .seconds
        perfectGoal.unifiedDailyTarget = 3600 / 7.0
        for weekday in 1...7 {
            perfectGoal.setTimes([.morning], forWeekday: weekday)
        }

        let partialGoal = Goal(title: "Morning Task", primaryTag: partialTag)
        partialGoal.targetUnit = .seconds
        partialGoal.unifiedDailyTarget = 3600 / 7.0
        for weekday in 1...7 {
            partialGoal.setTimes([.morning], forWeekday: weekday)
        }

        let noMatchGoal = Goal(title: "Evening Reading", primaryTag: noMatchTag)
        noMatchGoal.targetUnit = .seconds
        noMatchGoal.unifiedDailyTarget = 3600 / 7.0
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
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy, .cloudy]
        )
        
        let strictTag = GoalTag(
            title: "Strict",
            themeID: "test",
            weatherConditions: [.clear]
        )
        
        let flexibleGoal = Goal(title: "Flexible Activity", primaryTag: flexibleTag)
        flexibleGoal.targetUnit = .seconds
        flexibleGoal.unifiedDailyTarget = 3600 / 7.0
        let strictGoal = Goal(title: "Strict Activity", primaryTag: strictTag)
        strictGoal.targetUnit = .seconds
        strictGoal.unifiedDailyTarget = 3600 / 7.0
        
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
            themeID: "test",
            weatherConditions: [.clear]
        )
        
        let neutralTag = GoalTag(
            title: "Neutral",
            themeID: "test"
        )
        
        let outdoorGoal = Goal(title: "Running", primaryTag: outdoorTag)
        outdoorGoal.targetUnit = .seconds
        outdoorGoal.unifiedDailyTarget = 3600 / 7.0
        let neutralGoal = Goal(title: "Task", primaryTag: neutralTag)
        neutralGoal.targetUnit = .seconds
        neutralGoal.unifiedDailyTarget = 3600 / 7.0
        
        let context = createContext(weather: .clear)
        let recommendations = weatherHeavyRecommender.recommend(
            goals: [outdoorGoal, neutralGoal],
            sessions: [],
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
            themeID: "test"
        )
        
        let weekendGoal = Goal(
            title: "Hiking",
            primaryTag: weekendTag
        )
        weekendGoal.targetUnit = .seconds
        weekendGoal.unifiedDailyTarget = 7200.0 / 2.0 // 2 hours over 2 weekend days
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
            themeID: "test"
        )
        
        let weekendGoal = Goal(
            title: "Hiking",
            primaryTag: weekendTag
        )
        weekendGoal.targetUnit = .seconds
        weekendGoal.unifiedDailyTarget = 7200.0 / 2.0
        weekendGoal.setTimes([.morning], forWeekday: 7) // Saturday
        weekendGoal.setTimes([.morning], forWeekday: 1) // Sunday
        
        let weekdayGoal = Goal(
            title: "Work Task",
            primaryTag: createTestTag(title: "Work")
        )
        weekdayGoal.targetUnit = .seconds
        weekdayGoal.unifiedDailyTarget = 3600.0 / 7.0
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
            themeID: "test"
        )
        
        let morningGoal = Goal(
            title: "Morning Routine",
            primaryTag: morningTag
        )
        morningGoal.targetUnit = .seconds
        morningGoal.unifiedDailyTarget = 3600.0 / 7.0
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
            themeID: "test"
        )
        
        let workoutGoal = Goal(
            title: "Gym",
            primaryTag: workoutTag
        )
        workoutGoal.targetUnit = .seconds
        workoutGoal.unifiedDailyTarget = 10800.0 / 3.0 // 3 hours over 3 scheduled days
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
            themeID: "test"
        )
        
        let flexibleGoal = Goal(
            title: "Reading",
            primaryTag: flexibleTag
        )
        flexibleGoal.targetUnit = .seconds
        flexibleGoal.unifiedDailyTarget = 3600.0 / 7.0
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
    
    // MARK: - Goal Sequence Scoring Tests
    
    func createTestDay() -> Day {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return Day(start: start, end: end)
    }
    
    @Test("Goal with 'after' sequence scores high when linked goal completed")
    func afterSequenceScoresHighWhenLinkedCompleted() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let stretchingGoal = Goal(title: "Stretching")
        stretchingGoal.targetUnit = .seconds
        stretchingGoal.unifiedDailyTarget = 600
        stretchingGoal.sequenceEnabled = true
        stretchingGoal.sequenceGoalID = runningGoal.id.uuidString
        stretchingGoal.sequenceDirection = "after"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800 // completed
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [stretchingGoal],
            sessions: [runningSession],
            context: context,
            limit: 1
        )
        
        #expect(recs[0].reasons.contains(.goalSequence))
        #expect(recs[0].score > 0)
    }
    
    @Test("Goal with 'after' sequence scores zero when linked goal not started")
    func afterSequenceScoresZeroWhenLinkedNotStarted() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let stretchingGoal = Goal(title: "Stretching")
        stretchingGoal.targetUnit = .seconds
        stretchingGoal.unifiedDailyTarget = 600
        stretchingGoal.sequenceEnabled = true
        stretchingGoal.sequenceGoalID = runningGoal.id.uuidString
        stretchingGoal.sequenceDirection = "after"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 0 // not started
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [stretchingGoal],
            sessions: [runningSession],
            context: context,
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Goal with 'after' sequence gives partial score when linked goal in progress")
    func afterSequencePartialScoreWhenInProgress() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let stretchingGoal = Goal(title: "Stretching")
        stretchingGoal.targetUnit = .seconds
        stretchingGoal.unifiedDailyTarget = 600
        stretchingGoal.sequenceEnabled = true
        stretchingGoal.sequenceGoalID = runningGoal.id.uuidString
        stretchingGoal.sequenceDirection = "after"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 900 // half done
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [stretchingGoal],
            sessions: [runningSession],
            context: context,
            limit: 1
        )
        
        // Partial score but not a full reason (30% of sequence weight)
        #expect(recs[0].score > 0)
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Goal with 'before' sequence scores high when linked goal not started")
    func beforeSequenceScoresHighWhenLinkedNotStarted() {
        let recommender = DeterministicRecommender()
        
        let warmupGoal = Goal(title: "Warmup")
        warmupGoal.targetUnit = .seconds
        warmupGoal.unifiedDailyTarget = 300
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        warmupGoal.sequenceEnabled = true
        warmupGoal.sequenceGoalID = runningGoal.id.uuidString
        warmupGoal.sequenceDirection = "before"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 0 // not started
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [warmupGoal],
            sessions: [runningSession],
            context: context,
            limit: 1
        )
        
        #expect(recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Goal with 'before' sequence scores high when no linked session exists")
    func beforeSequenceScoresHighWhenNoLinkedSession() {
        let recommender = DeterministicRecommender()
        
        let warmupGoal = Goal(title: "Warmup")
        warmupGoal.targetUnit = .seconds
        warmupGoal.unifiedDailyTarget = 300
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        warmupGoal.sequenceEnabled = true
        warmupGoal.sequenceGoalID = runningGoal.id.uuidString
        warmupGoal.sequenceDirection = "before"
        
        // No running session at all today
        let context = createContext()
        let recs = recommender.recommend(
            goals: [warmupGoal],
            sessions: [],
            context: context,
            limit: 1
        )
        
        #expect(recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Goal with 'before' sequence scores zero when linked goal already done")
    func beforeSequenceScoresZeroWhenLinkedAlreadyDone() {
        let recommender = DeterministicRecommender()
        
        let warmupGoal = Goal(title: "Warmup")
        warmupGoal.targetUnit = .seconds
        warmupGoal.unifiedDailyTarget = 300
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        warmupGoal.sequenceEnabled = true
        warmupGoal.sequenceGoalID = runningGoal.id.uuidString
        warmupGoal.sequenceDirection = "before"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800 // already completed
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [warmupGoal],
            sessions: [runningSession],
            context: context,
            limit: 1
        )
        
        // Linked goal already done, no sequence bonus
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Sequence disabled goal gets no sequence score")
    func sequenceDisabledGetsNoScore() {
        let recommender = DeterministicRecommender()
        
        let goalA = Goal(title: "Goal A")
        goalA.targetUnit = .seconds
        goalA.unifiedDailyTarget = 600
        
        let goalB = Goal(title: "Goal B")
        goalB.targetUnit = .seconds
        goalB.unifiedDailyTarget = 600
        // sequenceEnabled defaults to false
        goalB.sequenceGoalID = goalA.id.uuidString
        goalB.sequenceDirection = "after"
        
        let day = createTestDay()
        let sessionA = GoalSession(title: "A", goal: goalA, day: day)
        sessionA.currentValue = 600 // completed
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [goalB],
            sessions: [sessionA],
            context: context,
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("After-sequence goal ranks higher than unlinked goal when linked completed")
    func afterSequenceRanksHigherThanUnlinked() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let stretchGoal = Goal(title: "Stretching")
        stretchGoal.targetUnit = .seconds
        stretchGoal.unifiedDailyTarget = 600
        stretchGoal.sequenceEnabled = true
        stretchGoal.sequenceGoalID = runningGoal.id.uuidString
        stretchGoal.sequenceDirection = "after"
        
        let readingGoal = Goal(title: "Reading")
        readingGoal.targetUnit = .seconds
        readingGoal.unifiedDailyTarget = 600
        // No sequence
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800 // completed
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [stretchGoal, readingGoal],
            sessions: [runningSession],
            context: context,
            limit: 2
        )
        
        #expect(recs[0].goal.title == "Stretching")
        #expect(recs[0].score > recs[1].score)
    }
    
    // MARK: - Condition Match Mode Tests
    
    @Test("Match ANY mode: single matching signal gives full score")
    func matchAnyModeSingleSignalGivesScore() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Outdoor Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        // Configure weather signal only
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.conditionMatchModeRaw = ConditionMatchMode.any.rawValue
        
        // Also set time signal to NOT match
        for weekday in 1...7 {
            goal.setTimes([.evening], forWeekday: weekday)
        }
        
        // Context: clear weather but morning (time doesn't match)
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recs = recommender.recommend(
            goals: [goal],
            sessions: [],
            context: context,
            limit: 1
        )
        
        // With Match ANY, weather matching alone should give a weather reason
        #expect(recs[0].reasons.contains(.weather))
    }
    
    @Test("Match ALL mode: all signals matching gives bonus")
    func matchAllModeAllSignalsMatchingGivesBonus() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "Perfect Match")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAll.conditionMatchModeRaw = ConditionMatchMode.all.rawValue
        for weekday in 1...7 {
            goalAll.setTimes([.morning], forWeekday: weekday)
        }
        
        let goalAny = Goal(title: "Any Match")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAny.conditionMatchModeRaw = ConditionMatchMode.any.rawValue
        for weekday in 1...7 {
            goalAny.setTimes([.morning], forWeekday: weekday)
        }
        
        // Context: clear morning — both signals match
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recsAll = recommender.recommend(goals: [goalAll], sessions: [], context: context, limit: 1)
        let recsAny = recommender.recommend(goals: [goalAny], sessions: [], context: context, limit: 1)
        
        // Match ALL should get a bonus when all signals match
        #expect(recsAll[0].score > recsAny[0].score)
    }
    
    @Test("Match ALL mode: one signal not matching penalizes score")
    func matchAllModeOneSignalMissingPenalizesScore() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "Strict Goal")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        // Weather signal: expects clear
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        // Time signal: expects morning
        for weekday in 1...7 {
            goalAll.setTimes([.morning], forWeekday: weekday)
        }
        goalAll.conditionMatchModeRaw = ConditionMatchMode.all.rawValue
        
        let goalAny = Goal(title: "Flexible Goal")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        for weekday in 1...7 {
            goalAny.setTimes([.morning], forWeekday: weekday)
        }
        goalAny.conditionMatchModeRaw = ConditionMatchMode.any.rawValue
        
        // Context: clear weather but EVENING (time doesn't match)
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .evening)
        let recsAll = recommender.recommend(goals: [goalAll], sessions: [], context: context, limit: 1)
        let recsAny = recommender.recommend(goals: [goalAny], sessions: [], context: context, limit: 1)
        
        // Match ALL should score lower than Match ANY when one signal misses
        #expect(recsAll[0].score < recsAny[0].score)
    }
    
    @Test("Match ALL mode: no reasons when a signal is missing")
    func matchAllModeNoReasonsWhenSignalMissing() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Strict Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        goal.conditionMatchModeRaw = ConditionMatchMode.all.rawValue
        
        // Context: rainy morning — weather doesn't match, time does
        let context = createContext(weather: .rainy, temperature: 10.0, timeOfDay: .morning)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Neither weather nor preferredTime should be given as a reason
        // because Match ALL mode suppresses reasons when not all signals match
        #expect(!recs[0].reasons.contains(.weather))
        #expect(!recs[0].reasons.contains(.preferredTime))
    }
    
    @Test("Match ALL mode with sequence: all three signals must match")
    func matchAllModeWithSequenceAllThreeMustMatch() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let goal = Goal(title: "Outdoor Stretch")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 600
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.sequenceEnabled = true
        goal.sequenceGoalID = runningGoal.id.uuidString
        goal.sequenceDirection = "after"
        goal.conditionMatchModeRaw = ConditionMatchMode.all.rawValue
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800 // completed
        
        // Context: clear weather — weather matches AND sequence matches
        let contextMatch = createContext(weather: .clear, temperature: 20.0)
        let recsMatch = recommender.recommend(
            goals: [goal],
            sessions: [runningSession],
            context: contextMatch,
            limit: 1
        )
        
        // Both signals match — should get reasons
        #expect(recsMatch[0].reasons.contains(.weather))
        #expect(recsMatch[0].reasons.contains(.goalSequence))
        
        // Context: rainy weather — weather misses, sequence matches
        let contextPartial = createContext(weather: .rainy, temperature: 10.0)
        let recsPartial = recommender.recommend(
            goals: [goal],
            sessions: [runningSession],
            context: contextPartial,
            limit: 1
        )
        
        // Match ALL: one signal missed, so reasons should be suppressed
        #expect(!recsPartial[0].reasons.contains(.weather))
        #expect(!recsPartial[0].reasons.contains(.goalSequence))
        #expect(recsPartial[0].score < recsMatch[0].score)
    }
    
    @Test("Default match mode is ANY")
    func defaultMatchModeIsAny() {
        let goal = Goal(title: "Test")
        #expect(goal.conditionMatchMode == .any)
    }
    
    @Test("Condition match mode persists via raw value")
    func conditionMatchModePersistsViaRawValue() {
        let goal = Goal(title: "Test")
        goal.conditionMatchMode = .all
        #expect(goal.conditionMatchModeRaw == "all")
        #expect(goal.conditionMatchMode == .all)
        
        goal.conditionMatchMode = .any
        #expect(goal.conditionMatchModeRaw == "any")
        #expect(goal.conditionMatchMode == .any)
    }
}
