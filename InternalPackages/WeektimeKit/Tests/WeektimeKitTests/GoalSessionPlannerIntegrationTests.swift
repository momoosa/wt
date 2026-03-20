//
//  GoalSessionPlannerIntegrationTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 19/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Goal Session Planner Integration Tests")
struct GoalSessionPlannerIntegrationTests {
    
    // MARK: - Test Helpers
    
    func createTestTheme() -> Theme {
        Theme(id: "test", title: "Test", light: .white, dark: .black, neon: .blue)
    }
    
    func createTestGoalSession(goalID: String, elapsedTime: TimeInterval = 0) -> GoalSession {
        let session = GoalSession(goalID: goalID, dayID: "2026-03-19")
        session.elapsedTime = elapsedTime
        return session
    }
    
    // MARK: - Quick Recommendations Tests
    
    @Test("Quick recommendations return weather-aware results")
    func quickRecommendationsReturnWeatherAwareResults() async {
        let planner = GoalSessionPlanner()
        
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
        
        let sessions = [
            createTestGoalSession(goalID: outdoorGoal.id.uuidString),
            createTestGoalSession(goalID: indoorGoal.id.uuidString)
        ]
        
        // Test on clear day
        let clearRecs = planner.getQuickRecommendations(
            for: [outdoorGoal, indoorGoal],
            goalSessions: sessions,
            currentDate: Date(),
            weather: .clear,
            temperature: 20.0
        )
        
        // Outdoor goal should be first
        #expect(clearRecs.goalIDs.first == outdoorGoal.id.uuidString)
        #expect(clearRecs.reasons.first?.contains("weather") == true)
    }
    
    @Test("Quick recommendations respect time of day preferences")
    func quickRecommendationsRespectTimeOfDayPreferences() async {
        let planner = GoalSessionPlanner()
        
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
        for weekday in 1...7 {
            morningGoal.setTimes([.morning], forWeekday: weekday)
        }
        
        let eveningGoal = Goal(
            title: "Evening Reading",
            primaryTag: eveningTag,
            weeklyTarget: 3600
        )
        for weekday in 1...7 {
            eveningGoal.setTimes([.evening], forWeekday: weekday)
        }
        
        let sessions = [
            createTestGoalSession(goalID: morningGoal.id.uuidString),
            createTestGoalSession(goalID: eveningGoal.id.uuidString)
        ]
        
        // Create a morning time (8 AM)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        let morningTime = calendar.date(from: components) ?? Date()
        
        let recs = planner.getQuickRecommendations(
            for: [morningGoal, eveningGoal],
            goalSessions: sessions,
            currentDate: morningTime
        )
        
        // Morning goal should be first
        #expect(recs.goalIDs.first == morningGoal.id.uuidString)
        #expect(recs.reasons.first?.contains("preferred time") == true)
    }
    
    @Test("Simple plan uses deterministic recommendations")
    func simplePlanUsesDeterministicRecommendations() async {
        let planner = GoalSessionPlanner()
        
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
        
        let sessions = [
            createTestGoalSession(goalID: outdoorGoal.id.uuidString)
        ]
        
        do {
            // Generate plan with weather context
            var preferences = PlannerPreferences.default
            preferences.currentWeather = .clear
            preferences.currentTemperature = 20.0
            
            let plan = try await planner.generateDailyPlan(
                for: [outdoorGoal],
                goalSessions: sessions,
                currentDate: Date(),
                userPreferences: preferences
            )
            
            // Verify plan includes recommendations
            #expect(plan.topThreeRecommendations != nil)
            #expect(plan.topThreeRecommendations?.isEmpty == false)
            #expect(plan.recommendationReasoning != nil)
        } catch {
            Issue.record("Plan generation failed: \(error)")
        }
    }
}
