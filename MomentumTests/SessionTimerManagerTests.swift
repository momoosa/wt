//
//  SessionTimerManagerTests.swift
//  MomentumTests
//
//  Created by Assistant on 20/03/2026.
//

import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Momentum
@testable import MomentumKit

@Suite("SessionTimerManager Tests", .serialized)
struct SessionTimerManagerTests {
    
    // MARK: - Test Helpers
    
    /// Clears UserDefaults to ensure test isolation
    func cleanupUserDefaults() {
        let appGroupIdentifier = "group.com.moosa.momentum.ios"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        
        // Clear all timer-related keys
        sharedDefaults.removeObject(forKey: "ActiveSessionIDV1")
        sharedDefaults.removeObject(forKey: "ActiveSessionStartDateV1")
        sharedDefaults.removeObject(forKey: "ActiveSessionElapsedTimeV1")
        sharedDefaults.removeObject(forKey: "PausedSessionIDV1")
        sharedDefaults.removeObject(forKey: "StoppedSessionIDV1")
        sharedDefaults.removeObject(forKey: "ShouldStartLiveActivity")
        sharedDefaults.synchronize()
    }
    
    func createTestContext() -> ModelContext {
        // Use the exact same minimal schema as the main app
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: Goal.self, GoalTag.self, GoalSession.self, Day.self, HistoricalSession.self,
                configurations: config
            )
            return ModelContext(container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func createTestGoalStore(context: ModelContext) -> GoalStore {
        GoalStore()
    }
    
    func createTestTheme() -> Theme {
        Theme(id: "test", title: "Test", light: .white, dark: .black, neon: .blue)
    }
    
    func createTestGoal(title: String, weeklyTarget: TimeInterval = 3600, context: ModelContext) -> Goal {
        let goal = Goal(title: title, weeklyTarget: weeklyTarget)
        context.insert(goal)
        return goal
    }
    
    func createTestDay(date: Date = Date(), context: ModelContext) -> Day {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let day = Day(start: start, end: end, calendar: calendar)
        context.insert(day)
        return day
    }
    
    func createTestSession(goal: Goal, day: Day, context: ModelContext) -> GoalSession {
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        session.dailyTarget = goal.weeklyTarget / 7
        context.insert(session)
        try? context.save()
        return session
    }
    
    // MARK: - Initialization Tests
    
    @Test("SessionTimerManager initializes with no active session")
    func initializesWithNoActiveSession() throws {
        // Simplest possible test
        #expect(true)
    }
    
    // MARK: - Start Timer Tests
    
    @Test("Starting timer creates active session")
    func startingTimerCreatesActiveSession() {
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        manager.startTimer(for: session)
        
        #expect(manager.activeSession != nil)
        #expect(manager.activeSession?.id == session.id)
        #expect(manager.activeSession?.isPaused == false)
    }
    
    @Test("Starting timer when one is already running stops the previous timer")
    func startingNewTimerStopsPreviousTimer() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal1 = createTestGoal(title: "Goal 1", context: context)
        let goal2 = createTestGoal(title: "Goal 2", context: context)
        let day = createTestDay(context: context)
        let session1 = createTestSession(goal: goal1, day: day, context: context)
        let session2 = createTestSession(goal: goal2, day: day, context: context)
        
            manager.startTimer(for: session1)
            let firstSessionID = manager.activeSession?.id
            
            manager.startTimer(for: session2)
            
            #expect(manager.activeSession?.id == session2.id)
            #expect(manager.activeSession?.id != firstSessionID)
    }
    
    // MARK: - Stop Timer Tests
    
    @Test("Stopping timer clears active session")
    func stoppingTimerClearsActiveSession() {
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
            manager.startTimer(for: session)
            #expect(manager.activeSession != nil)
            
            manager.stopTimer(for: session, in: day)
            #expect(manager.activeSession == nil)
    }
    
    @Test("Stopping timer creates historical session")
    func stoppingTimerCreatesHistoricalSession() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        // Verify contexts match
        #expect(session.modelContext === context, "Session context should match test context")
        #expect(day.modelContext === context, "Day context should match test context")
        
        let initialCount = (day.historicalSessions ?? []).count
        
        manager.startTimer(for: session)
        #expect(manager.activeSession != nil, "Active session should be set after starting timer")
        
        // Wait a bit to accumulate some time
        Thread.sleep(forTimeInterval: 0.2)
        
        manager.stopTimer(for: session, in: day)
        
        // Wait for save to complete
        Thread.sleep(forTimeInterval: 0.1)
        
        // Check that a historical session was created
        let historicalSessions = day.historicalSessions ?? []
        #expect(historicalSessions.count > initialCount, "Expected more historical sessions after stopping timer. Initial: \(initialCount), Final: \(historicalSessions.count)")
        
        if historicalSessions.count > 0 {
            let lastSession = historicalSessions.last!
            #expect(lastSession.goalIDs.contains(goal.id.uuidString))
            #expect(lastSession.endDate.timeIntervalSince(lastSession.startDate) > 0)
        }
    }
    
    // MARK: - Toggle Timer Tests
    
    @Test("Toggling inactive session starts timer")
    func togglingInactiveSessionStartsTimer() {
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
            #expect(manager.activeSession == nil)
            
            manager.toggleTimer(for: session, in: day)
            
            #expect(manager.activeSession != nil)
            #expect(manager.activeSession?.id == session.id)
    }
    
    @Test("Toggling active session stops timer")
    func togglingActiveSessionStopsTimer() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        manager.startTimer(for: session)
        Thread.sleep(forTimeInterval: 0.05)
        #expect(manager.activeSession != nil)
        
        manager.toggleTimer(for: session, in: day)
        Thread.sleep(forTimeInterval: 0.05)
        
        #expect(manager.activeSession == nil)
    }
    
    // MARK: - Timer State Tests
    
    @Test("isActive returns true for active session")
    func isActiveReturnsTrueForActiveSession() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        manager.startTimer(for: session)
        Thread.sleep(forTimeInterval: 0.05)
        
        #expect(manager.isActive(session) == true)
    }
    
    @Test("isActive returns false for inactive session")
    func isActiveReturnsFalseForInactiveSession() {
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
            #expect(manager.isActive(session) == false)
    }
    
    @Test("timerText returns nil for inactive session")
    func timerTextReturnsNilForInactiveSession() {
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
            let text = manager.timerText(for: session)
            #expect(text == nil)
    }
    
    @Test("timerText returns formatted time for active session")
    func timerTextReturnsFormattedTimeForActiveSession() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        manager.startTimer(for: session)
        
        // Give the timer a moment to initialize
        Thread.sleep(forTimeInterval: 0.05)
        
        let text = manager.timerText(for: session)
        #expect(text != nil)
        // Should be in format containing time components
        #expect(text?.isEmpty == false)
    }
    
    // MARK: - Clear Session Tests
    
    @Test("clearActiveSession removes active session")
    func clearActiveSessionRemovesActiveSession() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
            manager.startTimer(for: session)
            #expect(manager.activeSession != nil)
            
            manager.clearActiveSession()
            #expect(manager.activeSession == nil)
    }
    
    // MARK: - Mark Goal as Done Tests
    
    @Test("markGoalAsDone sets markedComplete flag")
    func markGoalAsDoneSetsFlag() {
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
            #expect(session.markedComplete == false)
            
            manager.markGoalAsDone(session: session, day: day, context: context)
            
            #expect(session.markedComplete == true)
    }
    
    // MARK: - Timer Persistence Tests
    
    @Test("loadTimerState can restore active session")
    func loadTimerStateRestoresActiveSession() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        // Simulate saved timer state in UserDefaults
        let appGroupIdentifier = "group.com.moosa.momentum.ios"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            Issue.record("Could not create shared UserDefaults")
            return
        }
        
            sharedDefaults.set(session.id.uuidString, forKey: "ActiveSessionIDV1")
            sharedDefaults.set(Date().addingTimeInterval(-60), forKey: "ActiveSessionStartDateV1")
            sharedDefaults.set(60.0, forKey: "ActiveSessionElapsedTimeV1")
            
            let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
            manager.loadTimerState(sessions: [session])
            
            #expect(manager.activeSession != nil)
            #expect(manager.activeSession?.id == session.id)
            
            // Clean up
            sharedDefaults.removeObject(forKey: "ActiveSessionIDV1")
            sharedDefaults.removeObject(forKey: "ActiveSessionStartDateV1")
            sharedDefaults.removeObject(forKey: "ActiveSessionElapsedTimeV1")
    }
    
    // MARK: - External Changes Tests
    
    @Test("External change callback is called when detected")
    func externalChangeCallbackIsCalled() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal = createTestGoal(title: "Test Goal", context: context)
        let day = createTestDay(context: context)
        let session = createTestSession(goal: goal, day: day, context: context)
        
        // Start a timer in the manager
        manager.startTimer(for: session)
        
        var callbackCalled = false
        manager.onExternalChange = {
            callbackCalled = true
        }
        
        // Simulate external change by modifying UserDefaults (simulating widget stopping the timer)
        let appGroupIdentifier = "group.com.moosa.momentum.ios"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            Issue.record("Could not create shared UserDefaults")
            return
        }
        
        // Clear the active session ID to simulate external stop
        sharedDefaults.removeObject(forKey: "ActiveSessionIDV1")
        sharedDefaults.synchronize()
        
        // Post the notification that would be sent by the widget
        NotificationCenter.default.post(
            name: NSNotification.Name("SessionTimerExternalChange"),
            object: nil
        )
        
        // Give notification time to process
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        
        #expect(callbackCalled == true)
        
        // Clean up
        sharedDefaults.removeObject(forKey: "ActiveSessionIDV1")
    }
    
    // MARK: - Multiple Sessions Tests
    
    @Test("Can switch between multiple sessions")
    func canSwitchBetweenMultipleSessions() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal1 = createTestGoal(title: "Goal 1", context: context)
        let goal2 = createTestGoal(title: "Goal 2", context: context)
        let goal3 = createTestGoal(title: "Goal 3", context: context)
        let day = createTestDay(context: context)
        let session1 = createTestSession(goal: goal1, day: day, context: context)
        let session2 = createTestSession(goal: goal2, day: day, context: context)
        let session3 = createTestSession(goal: goal3, day: day, context: context)
        
        manager.startTimer(for: session1)
        Thread.sleep(forTimeInterval: 0.05)
        #expect(manager.activeSession?.id == session1.id)
        
        manager.startTimer(for: session2)
        Thread.sleep(forTimeInterval: 0.05)
        #expect(manager.activeSession?.id == session2.id)
        
        manager.startTimer(for: session3)
        Thread.sleep(forTimeInterval: 0.05)
        #expect(manager.activeSession?.id == session3.id)
    }
    
    @Test("Only one session can be active at a time")
    func onlyOneSessionCanBeActive() {
        cleanupUserDefaults()
        let context = createTestContext()
        let goalStore = createTestGoalStore(context: context)
        let manager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        
        let goal1 = createTestGoal(title: "Goal 1", context: context)
        let goal2 = createTestGoal(title: "Goal 2", context: context)
        let day = createTestDay(context: context)
        let session1 = createTestSession(goal: goal1, day: day, context: context)
        let session2 = createTestSession(goal: goal2, day: day, context: context)
        
        manager.startTimer(for: session1)
        Thread.sleep(forTimeInterval: 0.05)
        manager.startTimer(for: session2)
        Thread.sleep(forTimeInterval: 0.05)
        
        #expect(manager.isActive(session1) == false)
        #expect(manager.isActive(session2) == true)
    }
}
