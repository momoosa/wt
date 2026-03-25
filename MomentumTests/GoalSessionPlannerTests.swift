//
//  GoalSessionPlannerTests.swift
//  WeektimeTests
//
//  Created by Mo Moosa on 21/03/2026.
//

import Testing
import Foundation
import SwiftData
@testable import MomentumKit
@testable import Momentum

@Suite("GoalSessionPlanner Tests")
@MainActor
struct GoalSessionPlannerTests {
    
    // MARK: - getQuickRecommendations Tests
    
    @Test("getQuickRecommendations returns top 3 goals")
    func testGetQuickRecommendationsLimit() async {
        let planner = GoalSessionPlanner()
        
        var goals: [Goal] = []
        let sessions: [GoalSession] = []
        
        // Create simple test data without needing full model context
        for i in 1...5 {
            let goal = Goal(title: "Goal \(i)", weeklyTarget: 3600)
            goals.append(goal)
        }
        
        let (goalIDs, reasons) = planner.getQuickRecommendations(
            for: goals,
            goalSessions: sessions
        )
        
        #expect(goalIDs.count <= 3) // Should return at most 3
        #expect(reasons.count == goalIDs.count)
    }
    
    @Test("getQuickRecommendations handles empty goals")
    func testGetQuickRecommendationsEmptyGoals() async {
        let planner = GoalSessionPlanner()
        
        let (goalIDs, reasons) = planner.getQuickRecommendations(
            for: [],
            goalSessions: []
        )
        
        #expect(goalIDs.isEmpty)
        #expect(reasons.isEmpty)
    }
    
    @Test("getQuickRecommendations considers time of day")
    func testGetQuickRecommendationsTimeOfDay() async {
        let planner = GoalSessionPlanner()
        
        let calendar = Calendar.current
        let morningDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let currentWeekday = calendar.component(.weekday, from: morningDate)
        
        let morningGoal = Goal(title: "Morning Goal", weeklyTarget: 3600)
        morningGoal.setTimes([.morning], forWeekday: currentWeekday)
        
        let eveningGoal = Goal(title: "Evening Goal", weeklyTarget: 3600)
        eveningGoal.setTimes([.evening], forWeekday: currentWeekday)
        
        let day = Day(start: Date.now.startOfDay() ?? Date.now, end: Date.now.endOfDay() ?? Date.now)
        let morningSession = GoalSession(title: morningGoal.title, goal: morningGoal, day: day)
        let eveningSession = GoalSession(title: eveningGoal.title, goal: eveningGoal, day: day)
        
        let (goalIDs, _) = planner.getQuickRecommendations(
            for: [morningGoal, eveningGoal],
            goalSessions: [morningSession, eveningSession],
            currentDate: morningDate
        )
        
        #expect(goalIDs.count > 0)
        
        // Morning goal should be recommended first during morning time
        if !goalIDs.isEmpty {
            #expect(goalIDs.first == morningGoal.id.uuidString)
        }
    }
    
    @Test("getQuickRecommendations considers calendar availability")
    func testGetQuickRecommendationsCalendarAvailability() async {
        let planner = GoalSessionPlanner()
        
        let calendar = Calendar.current
        let today = Date.now
        let currentWeekday = calendar.component(.weekday, from: today)
        
        let goal1 = Goal(title: "Flexible Goal", weeklyTarget: 3600)
        let goal2 = Goal(title: "Scheduled Goal", weeklyTarget: 3600)
        goal2.setTimes([.morning], forWeekday: currentWeekday)
        
        let day = Day(start: Date.now.startOfDay() ?? Date.now, end: Date.now.endOfDay() ?? Date.now)
        let session1 = GoalSession(title: goal1.title, goal: goal1, day: day)
        let session2 = GoalSession(title: goal2.title, goal: goal2, day: day)
        
        // Simulate low availability on scheduled days
        let weekdayAvailability: [Int: TimeInterval] = [
            currentWeekday: 300 // Only 5 minutes available
        ]
        
        let (goalIDs, _) = planner.getQuickRecommendations(
            for: [goal1, goal2],
            goalSessions: [session1, session2],
            currentDate: today,
            weekdayAvailability: weekdayAvailability
        )
        
        #expect(goalIDs.count > 0)
    }
    
    // MARK: - generateDailyPlan Tests
    
    @Test("generateDailyPlan returns empty plan for no goals")
    func testGenerateDailyPlanEmptyGoals() async throws {
        let planner = GoalSessionPlanner()
        
        let plan = try await planner.generateDailyPlan(
            for: [],
            goalSessions: []
        )
        
        #expect(plan.sessions.isEmpty)
        #expect(plan.overallStrategy != nil)
    }
    
    @Test("generateDailyPlan creates simple plan for 1-2 goals without AI")
    func testGenerateDailyPlanSimplePlan() async throws {
        let planner = GoalSessionPlanner()
        
        let goal = Goal(title: "Single Goal", weeklyTarget: 3600)
        let day = Day(start: Date.now.startOfDay() ?? Date.now, end: Date.now.endOfDay() ?? Date.now)
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        let plan = try await planner.generateDailyPlan(
            for: [goal],
            goalSessions: [session]
        )
        
        #expect(plan.sessions.count > 0)
        #expect(plan.sessions.first?.goalTitle == "Single Goal")
        #expect(plan.topThreeRecommendations != nil)
    }
    
    @Test("generateDailyPlan caches results")
    func testGenerateDailyPlanCaching() async throws {
        let planner = GoalSessionPlanner()
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: Date.now.startOfDay() ?? Date.now, end: Date.now.endOfDay() ?? Date.now)
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        
        let plan1 = try await planner.generateDailyPlan(
            for: [goal],
            goalSessions: [session]
        )
        
        let plan2 = try await planner.generateDailyPlan(
            for: [goal],
            goalSessions: [session]
        )
        
        // Should return same cached plan
        #expect(plan1.sessions.count == plan2.sessions.count)
        #expect(planner.currentPlan != nil)
    }
    
    // MARK: - getRecommendedSessionsFromPlan Tests
    
    @Test("getRecommendedSessionsFromPlan returns nil when no plan exists")
    func testGetRecommendedSessionsNoPlan() async {
        let planner = GoalSessionPlanner()
        
        let result = planner.getRecommendedSessionsFromPlan(allSessions: [])
        
        #expect(result == nil)
    }
    
    @Test("getRecommendedSessionsFromPlan returns nil when plan has no recommendations")
    func testGetRecommendedSessionsNoRecommendations() async {
        let planner = GoalSessionPlanner()
        
        let plan = DailyPlan(
            sessions: [],
            topThreeRecommendations: nil
        )
        planner.currentPlan = plan
        
        let result = planner.getRecommendedSessionsFromPlan(allSessions: [])
        
        #expect(result == nil)
    }
    
    // MARK: - getPlannedSession Tests
    
    @Test("getPlannedSession returns nil when no plan exists")
    func testGetPlannedSessionNoPlan() async throws {
        let planner = GoalSessionPlanner()
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let goal = Goal(title: "Test", weeklyTarget: 3600)
        let day = Day(start: Date.now.startOfDay() ?? .now, end: Date.now.endOfDay() ?? .now)
        context.insert(goal)
        context.insert(day)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        context.insert(session)
        
        let result = planner.getPlannedSession(for: session)
        
        #expect(result == nil)
    }
    
    @Test("getPlannedSession returns matching planned session")
    func testGetPlannedSessionReturnsMatching() async throws {
        let planner = GoalSessionPlanner()
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let goal = Goal(title: "Test", weeklyTarget: 3600)
        let day = Day(start: Date.now.startOfDay() ?? .now, end: Date.now.endOfDay() ?? .now)
        context.insert(goal)
        context.insert(day)
        
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        context.insert(session)
        
        let plannedSession = PlannedSession(
            id: goal.id.uuidString,
            goalTitle: goal.title,
            recommendedStartTime: "09:00",
            suggestedDuration: 30,
            priority: 1,
            reasoning: "Test"
        )
        
        let plan = DailyPlan(sessions: [plannedSession])
        planner.currentPlan = plan
        
        let result = planner.getPlannedSession(for: session)
        
        #expect(result != nil)
        #expect(result?.id == goal.id.uuidString)
        #expect(result?.suggestedDuration == 30)
    }
    
    @Test("getPlannedSession returns nil for non-matching session")
    func testGetPlannedSessionNonMatching() async throws {
        let planner = GoalSessionPlanner()
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let goal1 = Goal(title: "Goal 1", weeklyTarget: 3600)
        let goal2 = Goal(title: "Goal 2", weeklyTarget: 3600)
        let day = Day(start: Date.now.startOfDay() ?? .now, end: Date.now.endOfDay() ?? .now)
        
        context.insert(goal1)
        context.insert(goal2)
        context.insert(day)
        
        let session = GoalSession(title: goal2.title, goal: goal2, day: day)
        context.insert(session)
        
        let plannedSession = PlannedSession(
            id: goal1.id.uuidString,
            goalTitle: goal1.title,
            recommendedStartTime: "09:00",
            suggestedDuration: 30,
            priority: 1,
            reasoning: "Test"
        )
        
        let plan = DailyPlan(sessions: [plannedSession])
        planner.currentPlan = plan
        
        let result = planner.getPlannedSession(for: session)
        
        #expect(result == nil)
    }
    
    // MARK: - Helper Methods
    
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([Day.self, GoalSession.self, HistoricalSession.self, Goal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
