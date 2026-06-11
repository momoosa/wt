//
//  RecommendationConsistencyTests.swift
//  MomentumTests
//
//  Tests that run the recommendation logic multiple times to verify
//  deterministic, consistent results with identical inputs.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Recommendation Consistency Tests")
struct RecommendationConsistencyTests {
    
    // MARK: - Test Helpers
    
    /// Create a fixed date at a specific hour to eliminate time-dependent variation
    private func makeFixedDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 4 // Wednesday
        components.hour = hour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)!
    }
    
    /// Create a diverse set of goals with different configurations to stress-test ranking
    private func createDiverseGoalSet() -> [Goal] {
        // Goal 1: Outdoor morning goal with weather preference
        let outdoorTag = GoalTag(
            title: "Outdoor",
            themeID: "test",
            weatherConditions: [.clear, .partlyCloudy],
            temperatureRange: 10...30,
            timeOfDayPreferences: [.morning]
        )
        let running = Goal(title: "Running", primaryTag: outdoorTag)
        running.targetUnit = .seconds
        running.unifiedDailyTarget = 1800
        for weekday in 1...7 {
            running.setTimes([.morning], forWeekday: weekday)
        }
        
        // Goal 2: Evening indoor goal
        let indoorTag = GoalTag(
            title: "Indoor",
            themeID: "test",
            weatherConditions: [.rainy, .cloudy],
            timeOfDayPreferences: [.evening]
        )
        let reading = Goal(title: "Reading", primaryTag: indoorTag)
        reading.targetUnit = .seconds
        reading.unifiedDailyTarget = 3600
        for weekday in 1...7 {
            reading.setTimes([.evening], forWeekday: weekday)
        }
        
        // Goal 3: Flexible goal with no time/weather preference
        let flexTag = GoalTag(title: "Flexible", themeID: "test")
        let meditation = Goal(title: "Meditation", primaryTag: flexTag)
        meditation.targetUnit = .seconds
        meditation.unifiedDailyTarget = 600
        
        // Goal 4: Afternoon-only weekday goal
        let afternoonTag = GoalTag(
            title: "Afternoon",
            themeID: "test",
            timeOfDayPreferences: [.afternoon]
        )
        let coding = Goal(title: "Coding", primaryTag: afternoonTag)
        coding.targetUnit = .seconds
        coding.unifiedDailyTarget = 5400
        for weekday in 2...6 {
            coding.setTimes([.afternoon], forWeekday: weekday)
        }
        
        // Goal 5: No tag at all
        let writing = Goal(title: "Writing")
        writing.targetUnit = .seconds
        writing.unifiedDailyTarget = 2400
        
        return [running, reading, meditation, coding, writing]
    }
    
    // MARK: - Score Consistency
    
    @Test("Scores are identical across 100 runs with same inputs")
    func scoresIdenticalAcross100Runs() {
        let recommender = DeterministicRecommender()
        let fixedDate = makeFixedDate(hour: 10)
        
        let goals = createDiverseGoalSet()
        let context = DeterministicRecommender.Context(
            currentDate: fixedDate,
            weather: .clear,
            temperature: 20.0,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        let baseline = recommender.recommend(
            goals: goals,
            sessions: [],
            context: context,
            limit: goals.count
        )
        
        for run in 1...100 {
            let result = recommender.recommend(
                goals: goals,
                sessions: [],
                context: context,
                limit: goals.count
            )
            
            #expect(result.count == baseline.count, "Run \(run): count mismatch")
            for i in 0..<baseline.count {
                #expect(
                    result[i].score == baseline[i].score,
                    "Run \(run): score mismatch for \(baseline[i].goal.title) — expected \(baseline[i].score), got \(result[i].score)"
                )
                #expect(
                    result[i].goal.id == baseline[i].goal.id,
                    "Run \(run): ranking order changed at position \(i)"
                )
            }
        }
    }
    
    // MARK: - Ranking Order Consistency
    
    @Test("Ranking order is stable across 100 runs with same inputs")
    func rankingOrderStableAcross100Runs() {
        let recommender = DeterministicRecommender()
        let fixedDate = makeFixedDate(hour: 14)
        
        let goals = createDiverseGoalSet()
        let context = DeterministicRecommender.Context(
            currentDate: fixedDate,
            weather: .partlyCloudy,
            temperature: 18.0,
            timeOfDay: .afternoon,
            location: nil
        )
        
        let baseline = recommender.recommend(
            goals: goals,
            sessions: [],
            context: context,
            limit: goals.count
        )
        let baselineOrder = baseline.map { $0.goal.id }
        
        for run in 1...100 {
            let result = recommender.recommend(
                goals: goals,
                sessions: [],
                context: context,
                limit: goals.count
            )
            let resultOrder = result.map { $0.goal.id }
            
            #expect(
                resultOrder == baselineOrder,
                "Run \(run): ranking order changed"
            )
        }
    }
    
    // MARK: - Reason Consistency
    
    @Test("Reasons are identical across 50 runs with same inputs")
    func reasonsIdenticalAcross50Runs() {
        let recommender = DeterministicRecommender()
        let fixedDate = makeFixedDate(hour: 8)
        
        let outdoorTag = GoalTag(
            title: "Outdoor",
            themeID: "test",
            weatherConditions: [.clear],
            temperatureRange: 15...25,
            timeOfDayPreferences: [.morning]
        )
        
        let goal = Goal(title: "Morning Run", primaryTag: outdoorTag)
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 1800
        for weekday in 1...7 {
            goal.setTimes([.morning], forWeekday: weekday)
        }
        
        let context = DeterministicRecommender.Context(
            currentDate: fixedDate,
            weather: .clear,
            temperature: 20.0,
            timeOfDay: .morning,
            location: .outdoor
        )
        
        let baseline = recommender.recommend(
            goals: [goal],
            sessions: [],
            context: context,
            limit: 1
        )
        let baselineReasons = Set(baseline[0].reasons)
        
        for run in 1...50 {
            let result = recommender.recommend(
                goals: [goal],
                sessions: [],
                context: context,
                limit: 1
            )
            let resultReasons = Set(result[0].reasons)
            
            #expect(
                resultReasons == baselineReasons,
                "Run \(run): reasons changed — expected \(baselineReasons), got \(resultReasons)"
            )
        }
    }
    
    // MARK: - Cross-Context Consistency
    
    @Test("Consistent results across all time-of-day values over 20 runs each")
    func consistencyAcrossTimeOfDayValues() {
        let recommender = DeterministicRecommender()
        let goals = createDiverseGoalSet()
        
        let timesOfDay: [(TimeOfDay, Int)] = [
            (.morning, 8),
            (.midday, 12),
            (.afternoon, 15),
            (.evening, 19),
            (.night, 22)
        ]
        
        for (timeOfDay, hour) in timesOfDay {
            let fixedDate = makeFixedDate(hour: hour)
            let context = DeterministicRecommender.Context(
                currentDate: fixedDate,
                weather: .clear,
                temperature: 20.0,
                timeOfDay: timeOfDay
            )
            
            let baseline = recommender.recommend(
                goals: goals,
                sessions: [],
                context: context,
                limit: goals.count
            )
            
            for run in 1...20 {
                let result = recommender.recommend(
                    goals: goals,
                    sessions: [],
                    context: context,
                    limit: goals.count
                )
                
                #expect(result.count == baseline.count, "\(timeOfDay) run \(run): count mismatch")
                for i in 0..<baseline.count {
                    #expect(
                        result[i].score == baseline[i].score,
                        "\(timeOfDay) run \(run): score mismatch at position \(i)"
                    )
                    #expect(
                        result[i].goal.id == baseline[i].goal.id,
                        "\(timeOfDay) run \(run): order changed at position \(i)"
                    )
                }
            }
        }
    }
    
    // MARK: - Instance Independence
    
    @Test("Different recommender instances produce identical results over 50 runs")
    func consistencyWithDifferentRecommenderInstances() {
        let fixedDate = makeFixedDate(hour: 10)
        let goals = createDiverseGoalSet()
        let context = DeterministicRecommender.Context(
            currentDate: fixedDate,
            weather: .clear,
            temperature: 22.0,
            timeOfDay: .morning
        )
        
        let baseline = DeterministicRecommender().recommend(
            goals: goals,
            sessions: [],
            context: context,
            limit: goals.count
        )
        
        for run in 1...50 {
            let freshRecommender = DeterministicRecommender()
            let result = freshRecommender.recommend(
                goals: goals,
                sessions: [],
                context: context,
                limit: goals.count
            )
            
            #expect(result.count == baseline.count, "Run \(run): count mismatch with fresh instance")
            for i in 0..<baseline.count {
                #expect(
                    result[i].score == baseline[i].score,
                    "Run \(run): fresh instance produced different score at position \(i)"
                )
            }
        }
    }
    
    // MARK: - Custom Weights Consistency
    
    @Test("Custom weights produce consistent results across 50 runs")
    func consistencyWithCustomWeightsAcross50Runs() {
        let customWeights = DeterministicRecommender.ScoringWeights(
            weatherContext: 40.0,
            weeklyProgress: 10.0,
            timeOfDay: 30.0,
            deadline: 5.0,
            historicalPattern: 5.0,
            scheduleFlexibility: 10.0
        )
        let recommender = DeterministicRecommender(weights: customWeights)
        let fixedDate = makeFixedDate(hour: 9)
        
        let goals = createDiverseGoalSet()
        let context = DeterministicRecommender.Context(
            currentDate: fixedDate,
            weather: .clear,
            temperature: 20.0,
            timeOfDay: .morning
        )
        
        let baseline = recommender.recommend(
            goals: goals,
            sessions: [],
            context: context,
            limit: goals.count
        )
        
        for run in 1...50 {
            let result = recommender.recommend(
                goals: goals,
                sessions: [],
                context: context,
                limit: goals.count
            )
            
            #expect(result.count == baseline.count, "Run \(run): count mismatch")
            for i in 0..<baseline.count {
                #expect(
                    result[i].score == baseline[i].score,
                    "Run \(run): custom weights score mismatch at position \(i)"
                )
                #expect(
                    result[i].goal.id == baseline[i].goal.id,
                    "Run \(run): custom weights order changed at position \(i)"
                )
            }
        }
    }
    
    // MARK: - Limit Consistency
    
    @Test("Top-N subset is consistent with full ranking across 50 runs")
    func topNSubsetConsistentWithFullRanking() {
        let recommender = DeterministicRecommender()
        let fixedDate = makeFixedDate(hour: 10)
        let goals = createDiverseGoalSet()
        let context = DeterministicRecommender.Context(
            currentDate: fixedDate,
            weather: .clear,
            temperature: 20.0,
            timeOfDay: .morning
        )
        
        // Get full ranking
        let fullRanking = recommender.recommend(
            goals: goals,
            sessions: [],
            context: context,
            limit: goals.count
        )
        
        for run in 1...50 {
            // Get top-3 subset
            let top3 = recommender.recommend(
                goals: goals,
                sessions: [],
                context: context,
                limit: 3
            )
            
            #expect(top3.count == 3, "Run \(run): top-3 count mismatch")
            
            // Top 3 from limited call should match first 3 from full ranking
            for i in 0..<3 {
                #expect(
                    top3[i].goal.id == fullRanking[i].goal.id,
                    "Run \(run): top-3 position \(i) differs from full ranking"
                )
                #expect(
                    top3[i].score == fullRanking[i].score,
                    "Run \(run): top-3 score at position \(i) differs from full ranking"
                )
            }
        }
    }
}
