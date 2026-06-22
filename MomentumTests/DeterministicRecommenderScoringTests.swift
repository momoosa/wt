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
}
