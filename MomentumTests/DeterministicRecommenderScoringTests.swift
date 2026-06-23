//
//  DeterministicRecommenderScoringTests.swift
//  MomentumTests
//
//  Tests for goal sequence scoring and condition match mode (ALL/ANY) logic
//  in the DeterministicRecommender.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Deterministic Recommender Scoring Tests")
struct DeterministicRecommenderScoringTests {
    
    // MARK: - Test Helpers
    
    private func createContext(
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
    
    private func createTestDay() -> Day {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return Day(start: start, end: end)
    }
    
    // MARK: - Goal Sequence: "After" Direction
    
    @Test("After-sequence goal scores high when linked goal is completed")
    func afterSequenceLinkedCompleted() {
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
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800
        
        let recs = recommender.recommend(
            goals: [stretchGoal],
            sessions: [runningSession],
            context: createContext(),
            limit: 1
        )
        
        #expect(recs[0].reasons.contains(.goalSequence))
        #expect(recs[0].score > 0)
    }
    
    @Test("After-sequence goal gets no sequence reason when linked goal not started")
    func afterSequenceLinkedNotStarted() {
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
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 0
        
        let recs = recommender.recommend(
            goals: [stretchGoal],
            sessions: [runningSession],
            context: createContext(),
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("After-sequence goal gets partial score when linked goal is in progress")
    func afterSequenceLinkedInProgress() {
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
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 900 // halfway
        
        let completedSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        completedSession.currentValue = 1800
        
        let recsPartial = recommender.recommend(
            goals: [stretchGoal],
            sessions: [runningSession],
            context: createContext(),
            limit: 1
        )
        
        let recsFull = recommender.recommend(
            goals: [stretchGoal],
            sessions: [completedSession],
            context: createContext(),
            limit: 1
        )
        
        // Partial should score but less than completed
        #expect(recsPartial[0].score > 0)
        #expect(recsPartial[0].score < recsFull[0].score)
        // Partial doesn't get the sequence reason, completed does
        #expect(!recsPartial[0].reasons.contains(.goalSequence))
        #expect(recsFull[0].reasons.contains(.goalSequence))
    }
    
    // MARK: - Goal Sequence: "Before" Direction
    
    @Test("Before-sequence goal scores high when linked goal has not started")
    func beforeSequenceLinkedNotStarted() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let warmupGoal = Goal(title: "Warmup")
        warmupGoal.targetUnit = .seconds
        warmupGoal.unifiedDailyTarget = 300
        warmupGoal.sequenceEnabled = true
        warmupGoal.sequenceGoalID = runningGoal.id.uuidString
        warmupGoal.sequenceDirection = "before"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 0
        
        let recs = recommender.recommend(
            goals: [warmupGoal],
            sessions: [runningSession],
            context: createContext(),
            limit: 1
        )
        
        #expect(recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Before-sequence goal scores high when no linked session exists at all")
    func beforeSequenceNoLinkedSession() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let warmupGoal = Goal(title: "Warmup")
        warmupGoal.targetUnit = .seconds
        warmupGoal.unifiedDailyTarget = 300
        warmupGoal.sequenceEnabled = true
        warmupGoal.sequenceGoalID = runningGoal.id.uuidString
        warmupGoal.sequenceDirection = "before"
        
        let recs = recommender.recommend(
            goals: [warmupGoal],
            sessions: [], // no sessions at all
            context: createContext(),
            limit: 1
        )
        
        #expect(recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Before-sequence goal gets no sequence reason when linked goal already done")
    func beforeSequenceLinkedAlreadyDone() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let warmupGoal = Goal(title: "Warmup")
        warmupGoal.targetUnit = .seconds
        warmupGoal.unifiedDailyTarget = 300
        warmupGoal.sequenceEnabled = true
        warmupGoal.sequenceGoalID = runningGoal.id.uuidString
        warmupGoal.sequenceDirection = "before"
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800 // completed
        
        let recs = recommender.recommend(
            goals: [warmupGoal],
            sessions: [runningSession],
            context: createContext(),
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    // MARK: - Goal Sequence: Edge Cases
    
    @Test("Sequence disabled goal gets no sequence score even if linked goal is set")
    func sequenceDisabledNoScore() {
        let recommender = DeterministicRecommender()
        
        let goalA = Goal(title: "Goal A")
        goalA.targetUnit = .seconds
        goalA.unifiedDailyTarget = 600
        
        let goalB = Goal(title: "Goal B")
        goalB.targetUnit = .seconds
        goalB.unifiedDailyTarget = 600
        goalB.sequenceEnabled = false // disabled
        goalB.sequenceGoalID = goalA.id.uuidString
        goalB.sequenceDirection = "after"
        
        let day = createTestDay()
        let sessionA = GoalSession(title: "A", goal: goalA, day: day)
        sessionA.currentValue = 600
        
        let recs = recommender.recommend(
            goals: [goalB],
            sessions: [sessionA],
            context: createContext(),
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("After-sequence goal outranks unlinked goal when linked is completed")
    func afterSequenceOutranksUnlinked() {
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
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800
        
        let recs = recommender.recommend(
            goals: [stretchGoal, readingGoal],
            sessions: [runningSession],
            context: createContext(),
            limit: 2
        )
        
        #expect(recs[0].goal.title == "Stretching")
        #expect(recs[0].score > recs[1].score)
    }
    
    // MARK: - Condition Match Mode: Default
    
    @Test("Default condition match mode is ANY")
    func defaultMatchModeIsAny() {
        let goal = Goal(title: "Test")
        #expect(goal.conditionMatchMode == .any)
    }
    
    @Test("Condition match mode round-trips through raw value")
    func matchModeRoundTrips() {
        let goal = Goal(title: "Test")
        
        goal.conditionMatchMode = .all
        #expect(goal.conditionMatchModeRaw == "all")
        #expect(goal.conditionMatchMode == .all)
        
        goal.conditionMatchMode = .any
        #expect(goal.conditionMatchModeRaw == "any")
        #expect(goal.conditionMatchMode == .any)
    }
    
    // MARK: - Condition Match Mode: ANY Behavior
    
    @Test("Match ANY: weather signal alone provides weather reason")
    func matchAnySingleWeatherSignal() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Outdoor Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.conditionMatchMode = .any
        // Also configure time that does NOT match
        for weekday in 1...7 {
            goal.setTimes([.evening], forWeekday: weekday)
        }
        
        // Clear weather, morning (time doesn't match)
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Weather matches, so we should get the weather reason
        #expect(recs[0].reasons.contains(.weather))
    }
    
    // MARK: - Condition Match Mode: ALL Behavior
    
    @Test("Match ALL: all signals matching gives higher score than Match ANY")
    func matchAllBonusWhenAllMatch() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "All Mode")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAll.conditionMatchMode = .all
        for weekday in 1...7 {
            goalAll.setTimes([.morning], forWeekday: weekday)
        }
        
        let goalAny = Goal(title: "Any Mode")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAny.conditionMatchMode = .any
        for weekday in 1...7 {
            goalAny.setTimes([.morning], forWeekday: weekday)
        }
        
        // Both signals match: clear morning
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recsAll = recommender.recommend(goals: [goalAll], sessions: [], context: context, limit: 1)
        let recsAny = recommender.recommend(goals: [goalAny], sessions: [], context: context, limit: 1)
        
        // Match ALL gets a bonus when all signals match
        #expect(recsAll[0].score > recsAny[0].score)
    }
    
    @Test("Match ALL: one signal missing penalizes score vs Match ANY")
    func matchAllPenaltyWhenOneMissing() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "Strict")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAll.conditionMatchMode = .all
        for weekday in 1...7 {
            goalAll.setTimes([.morning], forWeekday: weekday)
        }
        
        let goalAny = Goal(title: "Flexible")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAny.conditionMatchMode = .any
        for weekday in 1...7 {
            goalAny.setTimes([.morning], forWeekday: weekday)
        }
        
        // Clear weather but EVENING — time signal misses
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .evening)
        let recsAll = recommender.recommend(goals: [goalAll], sessions: [], context: context, limit: 1)
        let recsAny = recommender.recommend(goals: [goalAny], sessions: [], context: context, limit: 1)
        
        // Match ALL should be penalized when one signal misses
        #expect(recsAll[0].score < recsAny[0].score)
    }
    
    @Test("Match ALL: reasons suppressed when a signal is missing")
    func matchAllNoReasonsWhenSignalMissing() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Strict Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.conditionMatchMode = .all
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        
        // Rainy morning — weather misses, time matches
        let context = createContext(weather: .rainy, temperature: 10.0, timeOfDay: .morning)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Reasons should be suppressed since not all conditions matched
        #expect(!recs[0].reasons.contains(.weather))
        #expect(!recs[0].reasons.contains(.preferredTime))
    }
    
    @Test("Match ALL: all reasons present when all signals match")
    func matchAllReasonsWhenAllMatch() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Perfect Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.conditionMatchMode = .all
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        
        // Clear morning — both match
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].reasons.contains(.weather))
        #expect(recs[0].reasons.contains(.preferredTime))
    }
    
    // MARK: - Condition Match Mode: ALL with Sequence
    
    @Test("Match ALL with sequence: all three signals must match for full score")
    func matchAllWithSequenceAllMustMatch() {
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
        goal.conditionMatchMode = .all
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 1800 // completed
        
        // Both signals match: clear weather + sequence fulfilled
        let contextMatch = createContext(weather: .clear, temperature: 20.0)
        let recsMatch = recommender.recommend(
            goals: [goal],
            sessions: [runningSession],
            context: contextMatch,
            limit: 1
        )
        
        #expect(recsMatch[0].reasons.contains(.weather))
        #expect(recsMatch[0].reasons.contains(.goalSequence))
        
        // Weather misses: rainy + sequence fulfilled
        let contextPartial = createContext(weather: .rainy, temperature: 10.0)
        let recsPartial = recommender.recommend(
            goals: [goal],
            sessions: [runningSession],
            context: contextPartial,
            limit: 1
        )
        
        // Match ALL with one missing signal → reasons suppressed, lower score
        #expect(!recsPartial[0].reasons.contains(.weather))
        #expect(!recsPartial[0].reasons.contains(.goalSequence))
        #expect(recsPartial[0].score < recsMatch[0].score)
    }
    
    @Test("Match ALL with sequence: sequence not fulfilled penalizes even with weather match")
    func matchAllSequenceNotFulfilledPenalizes() {
        let recommender = DeterministicRecommender()
        
        let runningGoal = Goal(title: "Running")
        runningGoal.targetUnit = .seconds
        runningGoal.unifiedDailyTarget = 1800
        
        let goal = Goal(title: "Post-Run Stretch")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 600
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.sequenceEnabled = true
        goal.sequenceGoalID = runningGoal.id.uuidString
        goal.sequenceDirection = "after"
        goal.conditionMatchMode = .all
        
        let day = createTestDay()
        let runningSession = GoalSession(title: "Running", goal: runningGoal, day: day)
        runningSession.currentValue = 0 // NOT completed
        
        // Weather matches but sequence doesn't
        let context = createContext(weather: .clear, temperature: 20.0)
        let recs = recommender.recommend(
            goals: [goal],
            sessions: [runningSession],
            context: context,
            limit: 1
        )
        
        // Neither reason should appear since Match ALL requires both
        #expect(!recs[0].reasons.contains(.weather))
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    // MARK: - Match Mode: Ranking Impact
    
    @Test("Match ALL goal with all signals matching outranks Match ANY goal")
    func matchAllPerfectMatchOutranksAny() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "ALL-mode goal")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAll.conditionMatchMode = .all
        for weekday in 1...7 {
            goalAll.setTimes([.morning], forWeekday: weekday)
        }
        
        let goalAny = Goal(title: "ANY-mode goal")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAny.conditionMatchMode = .any
        for weekday in 1...7 {
            goalAny.setTimes([.morning], forWeekday: weekday)
        }
        
        // All signals match
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recs = recommender.recommend(
            goals: [goalAll, goalAny],
            sessions: [],
            context: context,
            limit: 2
        )
        
        // Match ALL with perfect match should rank first due to bonus
        #expect(recs[0].goal.title == "ALL-mode goal")
    }
    
    @Test("Match ALL goal with partial match ranks below Match ANY goal")
    func matchAllPartialMatchRanksBelowAny() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "ALL-mode goal")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAll.conditionMatchMode = .all
        for weekday in 1...7 {
            goalAll.setTimes([.morning], forWeekday: weekday)
        }
        
        let goalAny = Goal(title: "ANY-mode goal")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAny.conditionMatchMode = .any
        for weekday in 1...7 {
            goalAny.setTimes([.morning], forWeekday: weekday)
        }
        
        // Weather matches, time doesn't (evening instead of morning)
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .evening)
        let recs = recommender.recommend(
            goals: [goalAll, goalAny],
            sessions: [],
            context: context,
            limit: 2
        )
        
        // Match ANY should rank first because Match ALL is penalized
        #expect(recs[0].goal.title == "ANY-mode goal")
    }
    
    // MARK: - Goal-Level Weather Scoring
    
    @Test("Weather condition match gives full weather score")
    func weatherConditionMatchGivesFullScore() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Sunny Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        
        let context = createContext(weather: .clear, temperature: 20.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].reasons.contains(.weather))
    }
    
    @Test("Weather condition mismatch gives zero weather score")
    func weatherConditionMismatchGivesZero() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Sunny Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        
        let context = createContext(weather: .rainy, temperature: 20.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(!recs[0].reasons.contains(.weather))
    }
    
    @Test("Multiple weather conditions match any one of them")
    func multipleWeatherConditionsMatchAny() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Outdoor Activity")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [
            WeatherCondition.clear.rawValue,
            WeatherCondition.partlyCloudy.rawValue,
            WeatherCondition.cloudy.rawValue
        ]
        
        // Partly cloudy matches one of the conditions
        let context = createContext(weather: .partlyCloudy, temperature: 20.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].reasons.contains(.weather))
    }
    
    @Test("Temperature below minimum fails weather check")
    func temperatureBelowMinimumFails() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Warm Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.minTemperature = 15.0
        
        // Clear sky but too cold
        let context = createContext(weather: .clear, temperature: 5.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(!recs[0].reasons.contains(.weather))
    }
    
    @Test("Temperature above maximum fails weather check")
    func temperatureAboveMaximumFails() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Cool Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.maxTemperature = 25.0
        
        // Clear sky but too hot
        let context = createContext(weather: .clear, temperature: 35.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(!recs[0].reasons.contains(.weather))
    }
    
    @Test("Temperature within bounds passes weather check")
    func temperatureWithinBoundsPasses() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Perfect Temp Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.minTemperature = 10.0
        goal.maxTemperature = 30.0
        
        let context = createContext(weather: .clear, temperature: 20.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].reasons.contains(.weather))
    }
    
    @Test("Wind speed above maximum fails weather check")
    func windSpeedAboveMaxFails() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Calm Weather Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.maxWindSpeed = 20.0
        
        let context = DeterministicRecommender.Context(
            currentDate: Date(),
            weather: .clear,
            temperature: 20.0,
            windSpeed: 35.0
        )
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(!recs[0].reasons.contains(.weather))
    }
    
    @Test("Wind speed within limit passes weather check")
    func windSpeedWithinLimitPasses() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Calm Weather Run")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.maxWindSpeed = 20.0
        
        let context = DeterministicRecommender.Context(
            currentDate: Date(),
            weather: .clear,
            temperature: 20.0,
            windSpeed: 10.0
        )
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].reasons.contains(.weather))
    }
    
    @Test("No weather data gives neutral score for goal with weather config")
    func noWeatherDataGivesNeutralScore() {
        let recommender = DeterministicRecommender()
        
        let goalWithWeather = Goal(title: "Weather Goal")
        goalWithWeather.targetUnit = .seconds
        goalWithWeather.unifiedDailyTarget = 1800
        goalWithWeather.weatherEnabled = true
        goalWithWeather.weatherConditions = [WeatherCondition.clear.rawValue]
        
        let goalPlain = Goal(title: "Plain Goal")
        goalPlain.targetUnit = .seconds
        goalPlain.unifiedDailyTarget = 1800
        
        // No weather in context
        let context = createContext()
        let recsWeather = recommender.recommend(goals: [goalWithWeather], sessions: [], context: context, limit: 1)
        let recsPlain = recommender.recommend(goals: [goalPlain], sessions: [], context: context, limit: 1)
        
        // Weather goal without weather data should not get weather reason
        #expect(!recsWeather[0].reasons.contains(.weather))
        // Scores should be similar (both get neutral weather)
        #expect(abs(recsWeather[0].score - recsPlain[0].score) < 1.0)
    }
    
    // MARK: - Weekly Progress Scoring
    
    @Test("Goal behind schedule gets weeklyProgress reason")
    func goalBehindScheduleGetsProgressReason() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Behind Goal")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 3600 // 1 hour daily = 7 hours weekly
        
        // No sessions at all — goal is behind schedule
        let context = createContext()
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Score should be positive (behind schedule contributes)
        #expect(recs[0].score > 0)
    }
    
    @Test("Goal ahead of schedule gets lower score than goal behind")
    func goalAheadGetsLowerScoreThanBehind() {
        let recommender = DeterministicRecommender()
        
        // Use a mid-week date so the behind-schedule deficit is meaningful
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        let midWeek = calendar.date(byAdding: .day, value: 3, to: weekStart)!
        let midWeekDay = Day(
            start: calendar.startOfDay(for: midWeek),
            end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: midWeek))!
        )
        
        let behindGoal = Goal(title: "Behind")
        behindGoal.targetUnit = .seconds
        behindGoal.unifiedDailyTarget = 3600
        
        let aheadGoal = Goal(title: "Ahead")
        aheadGoal.targetUnit = .seconds
        aheadGoal.unifiedDailyTarget = 3600
        
        // Create a session that exceeds the weekly target for the ahead goal
        let aheadSession = GoalSession(title: "Ahead", goal: aheadGoal, day: midWeekDay)
        aheadSession.currentValue = 50000 // way over target
        
        let context = DeterministicRecommender.Context(currentDate: midWeek)
        let recs = recommender.recommend(
            goals: [behindGoal, aheadGoal],
            sessions: [aheadSession],
            context: context,
            limit: 2
        )
        
        // Behind goal should rank higher (mid-week deficit is significant)
        #expect(recs[0].goal.title == "Behind")
    }
    
    @Test("Weekly progress only counts sessions for the correct goal")
    func weeklyProgressCountsCorrectGoalOnly() {
        let recommender = DeterministicRecommender()
        
        // Use a mid-week date for meaningful deficit
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        let midWeek = calendar.date(byAdding: .day, value: 3, to: weekStart)!
        let midWeekDay = Day(
            start: calendar.startOfDay(for: midWeek),
            end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: midWeek))!
        )
        
        let goalA = Goal(title: "A")
        goalA.targetUnit = .seconds
        goalA.unifiedDailyTarget = 3600
        
        let goalB = Goal(title: "B")
        goalB.targetUnit = .seconds
        goalB.unifiedDailyTarget = 3600
        
        // Sessions for goal B only — A has no sessions
        let sessionB = GoalSession(title: "B", goal: goalB, day: midWeekDay)
        sessionB.currentValue = 50000
        
        let context = DeterministicRecommender.Context(currentDate: midWeek)
        let recs = recommender.recommend(
            goals: [goalA, goalB],
            sessions: [sessionB],
            context: context,
            limit: 2
        )
        
        // Goal A (behind) should rank higher than Goal B (ahead)
        #expect(recs[0].goal.title == "A")
    }
    
    // MARK: - Time of Day Scoring
    
    @Test("No time of day in context gives neutral score")
    func noTimeOfDayGivesNeutralScore() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Timed Goal")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        
        // No timeOfDay in context
        let context = createContext()
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(!recs[0].reasons.contains(.preferredTime))
    }
    
    @Test("Time mismatch gives low time score")
    func timeMismatchGivesLowScore() {
        let recommender = DeterministicRecommender()
        
        let morningGoal = Goal(title: "Morning")
        morningGoal.targetUnit = .seconds
        morningGoal.unifiedDailyTarget = 1800
        for weekday in 1...7 {
            morningGoal.setTimes([.morning], forWeekday: weekday)
        }
        
        let eveningGoal = Goal(title: "Evening")
        eveningGoal.targetUnit = .seconds
        eveningGoal.unifiedDailyTarget = 1800
        for weekday in 1...7 {
            eveningGoal.setTimes([.evening], forWeekday: weekday)
        }
        
        // Evening context — morning goal should score lower
        let context = createContext(timeOfDay: .evening)
        let recs = recommender.recommend(
            goals: [morningGoal, eveningGoal],
            sessions: [],
            context: context,
            limit: 2
        )
        
        #expect(recs[0].goal.title == "Evening")
        #expect(recs[0].reasons.contains(.preferredTime))
    }
    
    @Test("Goal with no time preference gets neutral time score")
    func noTimePreferenceGetsNeutral() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Anytime")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        // No time preferences set
        
        let context = createContext(timeOfDay: .morning)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Should not get preferredTime reason
        #expect(!recs[0].reasons.contains(.preferredTime))
    }
    
    // MARK: - Schedule Flexibility with Relevance Rules
    
    @Test("Open day gets a reduced schedule flexibility score")
    func openDayGetsReducedFlexibilityScore() {
        let recommender = DeterministicRecommender()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        let goalOpen = Goal(title: "Open Day Goal")
        goalOpen.targetUnit = .seconds
        goalOpen.unifiedDailyTarget = 1800
        goalOpen.dayAvailabilityRaw[String(weekday)] = DayAvailability.open.rawValue
        
        let goalNone = Goal(title: "No Rule Goal")
        goalNone.targetUnit = .seconds
        goalNone.unifiedDailyTarget = 1800
        
        let context = createContext()
        let recsOpen = recommender.recommend(goals: [goalOpen], sessions: [], context: context, limit: 1)
        let recsNone = recommender.recommend(goals: [goalNone], sessions: [], context: context, limit: 1)
        
        // Open day gets reduced schedule flexibility (0.4 * weight), no-rule gets 0
        #expect(recsOpen[0].score > recsNone[0].score)
    }
    
    @Test("Preferred day proceeds to schedule-based scoring")
    func preferredDayProceedsToScheduleScoring() {
        let recommender = DeterministicRecommender()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        let goalPreferred = Goal(title: "Preferred")
        goalPreferred.targetUnit = .seconds
        goalPreferred.unifiedDailyTarget = 1800
        goalPreferred.dayAvailabilityRaw[String(weekday)] = DayAvailability.preferred.rawValue
        goalPreferred.setTimes([.morning], forWeekday: weekday)
        
        let goalNoRule = Goal(title: "No Rule")
        goalNoRule.targetUnit = .seconds
        goalNoRule.unifiedDailyTarget = 1800
        goalNoRule.setTimes([.morning], forWeekday: weekday)
        
        let context = createContext(timeOfDay: .morning)
        let recsPreferred = recommender.recommend(goals: [goalPreferred], sessions: [], context: context, limit: 1)
        let recsNoRule = recommender.recommend(goals: [goalNoRule], sessions: [], context: context, limit: 1)
        
        // Preferred day with schedule delegates to old schedule logic (no availability data → 0 flexibility)
        // No-rule goal also gets 0 flexibility, so scores are equal
        #expect(abs(recsPreferred[0].score - recsNoRule[0].score) < 1.0)
    }
    
    @Test("Never day gets zero schedule flexibility score")
    func neverDayGetsZeroFlexibility() {
        let recommender = DeterministicRecommender()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        let goalNever = Goal(title: "Never Day Goal")
        goalNever.targetUnit = .seconds
        goalNever.unifiedDailyTarget = 1800
        goalNever.dayAvailabilityRaw[String(weekday)] = DayAvailability.never.rawValue
        
        let goalOpen = Goal(title: "Open Day Goal")
        goalOpen.targetUnit = .seconds
        goalOpen.unifiedDailyTarget = 1800
        goalOpen.dayAvailabilityRaw[String(weekday)] = DayAvailability.open.rawValue
        
        let context = createContext()
        let recsNever = recommender.recommend(goals: [goalNever], sessions: [], context: context, limit: 1)
        let recsOpen = recommender.recommend(goals: [goalOpen], sessions: [], context: context, limit: 1)
        
        // Never day should score lower than open day
        // (never returns 0 flexibility, open returns 0.4 * weight)
        #expect(recsNever[0].score < recsOpen[0].score)
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty goals list returns empty recommendations")
    func emptyGoalsReturnsEmpty() {
        let recommender = DeterministicRecommender()
        let context = createContext()
        let recs = recommender.recommend(goals: [], sessions: [], context: context, limit: 3)
        
        #expect(recs.isEmpty)
    }
    
    @Test("Single goal returns one recommendation")
    func singleGoalReturnsOne() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Solo")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        
        let context = createContext()
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 5)
        
        #expect(recs.count == 1)
        #expect(recs[0].goal.title == "Solo")
    }
    
    @Test("Limit larger than goal count returns all goals")
    func limitLargerThanGoalCountReturnsAll() {
        let recommender = DeterministicRecommender()
        
        let goals = (1...3).map { i -> Goal in
            let g = Goal(title: "Goal \(i)")
            g.targetUnit = .seconds
            g.unifiedDailyTarget = 1800
            return g
        }
        
        let context = createContext()
        let recs = recommender.recommend(goals: goals, sessions: [], context: context, limit: 10)
        
        #expect(recs.count == 3)
    }
    
    @Test("All archived goals returns empty")
    func allArchivedGoalsReturnsEmpty() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Archived")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.status = .archived
        
        let context = createContext()
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 3)
        
        #expect(recs.isEmpty)
    }
    
    @Test("Scores are non-negative")
    func scoresAreNonNegative() {
        let recommender = DeterministicRecommender()
        
        // Create a goal with every possible mismatch
        let goal = Goal(title: "Mismatched")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        
        // Everything mismatches: rainy, evening
        let context = createContext(weather: .rainy, temperature: 0.0, timeOfDay: .evening)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].score >= 0)
    }
    
    @Test("Results are sorted by score descending")
    func resultsSortedByScoreDescending() {
        let recommender = DeterministicRecommender()
        
        let goals = (1...5).map { i -> Goal in
            let g = Goal(title: "Goal \(i)")
            g.targetUnit = .seconds
            g.unifiedDailyTarget = Double(i * 1000) // varying targets
            return g
        }
        
        let context = createContext()
        let recs = recommender.recommend(goals: goals, sessions: [], context: context, limit: 5)
        
        for i in 0..<(recs.count - 1) {
            #expect(recs[i].score >= recs[i + 1].score)
        }
    }
    
    // MARK: - Match ALL with Single Signal
    
    @Test("Match ALL with single signal behaves like ANY")
    func matchAllSingleSignalBehavesLikeAny() {
        let recommender = DeterministicRecommender()
        
        let goalAll = Goal(title: "ALL single")
        goalAll.targetUnit = .seconds
        goalAll.unifiedDailyTarget = 1800
        goalAll.weatherEnabled = true
        goalAll.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAll.conditionMatchMode = .all
        // Only weather signal — no time signal
        
        let goalAny = Goal(title: "ANY single")
        goalAny.targetUnit = .seconds
        goalAny.unifiedDailyTarget = 1800
        goalAny.weatherEnabled = true
        goalAny.weatherConditions = [WeatherCondition.clear.rawValue]
        goalAny.conditionMatchMode = .any
        // Only weather signal — no time signal
        
        let context = createContext(weather: .clear, temperature: 20.0)
        let recsAll = recommender.recommend(goals: [goalAll], sessions: [], context: context, limit: 1)
        let recsAny = recommender.recommend(goals: [goalAny], sessions: [], context: context, limit: 1)
        
        // Both should get weather reason
        #expect(recsAll[0].reasons.contains(.weather))
        #expect(recsAny[0].reasons.contains(.weather))
        // ALL with single signal gets +5 bonus, so slightly higher
        #expect(recsAll[0].score >= recsAny[0].score)
    }
    
    @Test("Match ALL with single signal mismatch suppresses reasons")
    func matchAllSingleSignalMismatch() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "ALL single miss")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.conditionMatchMode = .all
        
        let context = createContext(weather: .rainy, temperature: 10.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(!recs[0].reasons.contains(.weather))
    }
    
    // MARK: - Weather Scoring: Goal-Level vs Tag-Level Fallback
    
    @Test("Goal without weather config falls back to tag-based scoring")
    func goalWithoutWeatherConfigFallsBackToTag() {
        let recommender = DeterministicRecommender()
        
        let tag = GoalTag(
            title: "Outdoor",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25
        )
        
        let goal = Goal(title: "Tag Run", primaryTag: tag)
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        // weatherEnabled is false (default) — should use tag
        
        let context = createContext(weather: .clear, temperature: 20.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        #expect(recs[0].reasons.contains(.weather))
    }
    
    @Test("Goal with weather config overrides tag-based scoring")
    func goalWeatherConfigOverridesTag() {
        let recommender = DeterministicRecommender()
        
        // Tag says rainy is good
        let tag = GoalTag(
            title: "Indoor",
            themeID: "test",
            weatherConditions: [.rainy]
        )
        
        let goal = Goal(title: "Override Goal", primaryTag: tag)
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        // Goal-level says clear is good — should override tag
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        
        // Clear weather — tag says no, goal-level says yes
        let context = createContext(weather: .clear, temperature: 20.0)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Goal-level config wins
        #expect(recs[0].reasons.contains(.weather))
    }
    
    // MARK: - Combined Temperature + Wind Speed Bounds
    
    @Test("All weather bounds must pass simultaneously")
    func allWeatherBoundsMustPass() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Strict Weather")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.minTemperature = 10.0
        goal.maxTemperature = 30.0
        goal.maxWindSpeed = 20.0
        
        // All pass: clear, 20°, 10km/h wind
        let ctxPass = DeterministicRecommender.Context(
            currentDate: Date(), weather: .clear, temperature: 20.0, windSpeed: 10.0
        )
        let recsPass = recommender.recommend(goals: [goal], sessions: [], context: ctxPass, limit: 1)
        #expect(recsPass[0].reasons.contains(.weather))
        
        // Temp fails: clear, 5°, 10km/h wind
        let ctxTempFail = DeterministicRecommender.Context(
            currentDate: Date(), weather: .clear, temperature: 5.0, windSpeed: 10.0
        )
        let recsTempFail = recommender.recommend(goals: [goal], sessions: [], context: ctxTempFail, limit: 1)
        #expect(!recsTempFail[0].reasons.contains(.weather))
        
        // Wind fails: clear, 20°, 30km/h wind
        let ctxWindFail = DeterministicRecommender.Context(
            currentDate: Date(), weather: .clear, temperature: 20.0, windSpeed: 30.0
        )
        let recsWindFail = recommender.recommend(goals: [goal], sessions: [], context: ctxWindFail, limit: 1)
        #expect(!recsWindFail[0].reasons.contains(.weather))
        
        // Condition fails: rainy, 20°, 10km/h
        let ctxCondFail = DeterministicRecommender.Context(
            currentDate: Date(), weather: .rainy, temperature: 20.0, windSpeed: 10.0
        )
        let recsCondFail = recommender.recommend(goals: [goal], sessions: [], context: ctxCondFail, limit: 1)
        #expect(!recsCondFail[0].reasons.contains(.weather))
    }
    
    // MARK: - Sequence Edge Cases: Invalid Direction
    
    @Test("Sequence with unknown direction gives no score")
    func sequenceUnknownDirectionNoScore() {
        let recommender = DeterministicRecommender()
        
        let goalA = Goal(title: "A")
        goalA.targetUnit = .seconds
        goalA.unifiedDailyTarget = 600
        
        let goalB = Goal(title: "B")
        goalB.targetUnit = .seconds
        goalB.unifiedDailyTarget = 600
        goalB.sequenceEnabled = true
        goalB.sequenceGoalID = goalA.id.uuidString
        goalB.sequenceDirection = "sideways" // invalid
        
        let day = createTestDay()
        let sessionA = GoalSession(title: "A", goal: goalA, day: day)
        sessionA.currentValue = 600
        
        let recs = recommender.recommend(
            goals: [goalB],
            sessions: [sessionA],
            context: createContext(),
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Sequence with nil goalID gives no score")
    func sequenceNilGoalIDNoScore() {
        let recommender = DeterministicRecommender()
        
        let goal = Goal(title: "Orphan")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 600
        goal.sequenceEnabled = true
        goal.sequenceGoalID = nil
        goal.sequenceDirection = "after"
        
        let recs = recommender.recommend(
            goals: [goal],
            sessions: [],
            context: createContext(),
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    @Test("Sequence with nil direction gives no score")
    func sequenceNilDirectionNoScore() {
        let recommender = DeterministicRecommender()
        
        let goalA = Goal(title: "A")
        goalA.targetUnit = .seconds
        goalA.unifiedDailyTarget = 600
        
        let goal = Goal(title: "No Direction")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 600
        goal.sequenceEnabled = true
        goal.sequenceGoalID = goalA.id.uuidString
        goal.sequenceDirection = nil
        
        let recs = recommender.recommend(
            goals: [goal],
            sessions: [],
            context: createContext(),
            limit: 1
        )
        
        #expect(!recs[0].reasons.contains(.goalSequence))
    }
    
    // MARK: - Before Sequence: Score Difference With vs Without Session
    
    @Test("Before-sequence with no session gives slightly less than with explicit zero session")
    func beforeSequenceNoSessionVsZeroSession() {
        let recommender = DeterministicRecommender()
        
        let runGoal = Goal(title: "Run")
        runGoal.targetUnit = .seconds
        runGoal.unifiedDailyTarget = 1800
        
        let warmup = Goal(title: "Warmup")
        warmup.targetUnit = .seconds
        warmup.unifiedDailyTarget = 300
        warmup.sequenceEnabled = true
        warmup.sequenceGoalID = runGoal.id.uuidString
        warmup.sequenceDirection = "before"
        
        let day = createTestDay()
        let zeroSession = GoalSession(title: "Run", goal: runGoal, day: day)
        zeroSession.currentValue = 0
        
        let recsWithSession = recommender.recommend(
            goals: [warmup],
            sessions: [zeroSession],
            context: createContext(),
            limit: 1
        )
        
        let recsNoSession = recommender.recommend(
            goals: [warmup],
            sessions: [],
            context: createContext(),
            limit: 1
        )
        
        // Both should get sequence reason
        #expect(recsWithSession[0].reasons.contains(.goalSequence))
        #expect(recsNoSession[0].reasons.contains(.goalSequence))
        
        // With explicit zero session gets full score (100%), no session gets 80%
        #expect(recsWithSession[0].score > recsNoSession[0].score)
    }
    
    // MARK: - Non-Signal Goals Still Get Weather/Time Scores
    
    @Test("Goal without explicit signals still gets tag-based weather and time scores")
    func nonSignalGoalStillGetsTagScores() {
        let recommender = DeterministicRecommender()
        
        let tag = GoalTag(
            title: "Outdoor Morning",
            themeID: "test",
            weatherConditions: [.clear],
            timeOfDayPreferences: [.morning]
        )
        
        let goal = Goal(title: "Tag Only", primaryTag: tag)
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        // No setTimes, no weatherEnabled — relies on tag
        
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .morning)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Should get weather from tag-based scoring
        #expect(recs[0].reasons.contains(.weather))
    }
    
    // MARK: - Match ALL Threshold Boundary
    
    @Test("Match ALL: signal at exactly 10% of max is considered a miss")
    func matchAllThresholdBoundary() {
        let recommender = DeterministicRecommender()
        
        // Time mismatch gives 10% of max (weights.timeOfDay * 0.1)
        // That's exactly at the threshold (> 0.1 * maxScore is the check)
        // So score == 0.1 * maxScore should fail the > check
        let goal = Goal(title: "Boundary")
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        goal.weatherEnabled = true
        goal.weatherConditions = [WeatherCondition.clear.rawValue]
        goal.conditionMatchMode = .all
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        
        // Weather matches, time mismatches (10% score = threshold)
        let context = createContext(weather: .clear, temperature: 20.0, timeOfDay: .evening)
        let recs = recommender.recommend(goals: [goal], sessions: [], context: context, limit: 1)
        
        // Time signal score = 0.1 * 20 = 2.0, threshold = 0.1 * 20 = 2.0
        // Since check is > (not >=), this should be treated as NOT matching
        #expect(!recs[0].reasons.contains(.weather))
        #expect(!recs[0].reasons.contains(.preferredTime))
    }
    
    // MARK: - Scoring Weights Customization
    
    @Test("Zero weather weight means weather contributes zero points to score")
    func zeroWeatherWeightContributesZeroPoints() {
        let weights = DeterministicRecommender.ScoringWeights(
            weatherContext: 0.0,
            weeklyProgress: 30.0,
            timeOfDay: 20.0,
            deadline: 15.0,
            historicalPattern: 10.0,
            scheduleFlexibility: 25.0
        )
        let recommender = DeterministicRecommender(weights: weights)
        
        let goalWithWeather = Goal(title: "With Weather")
        goalWithWeather.targetUnit = .seconds
        goalWithWeather.unifiedDailyTarget = 1800
        goalWithWeather.weatherEnabled = true
        goalWithWeather.weatherConditions = [WeatherCondition.clear.rawValue]
        
        let goalWithout = Goal(title: "Without Weather")
        goalWithout.targetUnit = .seconds
        goalWithout.unifiedDailyTarget = 1800
        
        let context = createContext(weather: .clear, temperature: 20.0)
        let recsWith = recommender.recommend(goals: [goalWithWeather], sessions: [], context: context, limit: 1)
        let recsWithout = recommender.recommend(goals: [goalWithout], sessions: [], context: context, limit: 1)
        
        // Zero weight means weather adds 0 points — scores should be equal
        #expect(abs(recsWith[0].score - recsWithout[0].score) < 1.0)
    }
    
    @Test("Heavy goal sequence weight makes sequence dominant")
    func heavySequenceWeightDominates() {
        let weights = DeterministicRecommender.ScoringWeights(
            weatherContext: 5.0,
            weeklyProgress: 5.0,
            timeOfDay: 5.0,
            deadline: 5.0,
            historicalPattern: 5.0,
            scheduleFlexibility: 5.0,
            goalSequence: 100.0
        )
        let recommender = DeterministicRecommender(weights: weights)
        
        let runGoal = Goal(title: "Run")
        runGoal.targetUnit = .seconds
        runGoal.unifiedDailyTarget = 1800
        
        let sequenceGoal = Goal(title: "Stretch After")
        sequenceGoal.targetUnit = .seconds
        sequenceGoal.unifiedDailyTarget = 600
        sequenceGoal.sequenceEnabled = true
        sequenceGoal.sequenceGoalID = runGoal.id.uuidString
        sequenceGoal.sequenceDirection = "after"
        
        let plainGoal = Goal(title: "Reading")
        plainGoal.targetUnit = .seconds
        plainGoal.unifiedDailyTarget = 600
        
        let day = createTestDay()
        let runSession = GoalSession(title: "Run", goal: runGoal, day: day)
        runSession.currentValue = 1800
        
        let context = createContext()
        let recs = recommender.recommend(
            goals: [sequenceGoal, plainGoal],
            sessions: [runSession],
            context: context,
            limit: 2
        )
        
        #expect(recs[0].goal.title == "Stretch After")
        // Sequence score (100) should make it clearly dominant
        #expect(recs[0].score > recs[1].score + 50)
    }
}
