//
//  ChecklistTests.swift
//  Momentum Tests
//
//  Created by Assistant on 13/03/2026.
//

import Testing
import Foundation
@testable import Momentum
@testable import MomentumKit

@Suite("Checklist Tests")
struct ChecklistTests {
    
    // MARK: - ChecklistItem Tests
    
    @Test("ChecklistItem initializes with title and goal")
    func checklistItemInitializesWithTitleAndGoal() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let item = ChecklistItem(title: "Complete report", goal: goal)
        
        #expect(item.title == "Complete report")
        #expect(item.goal?.id == goal.id)
    }
    
    @Test("ChecklistItem generates unique ID")
    func checklistItemGeneratesUniqueID() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let item1 = ChecklistItem(title: "Item 1", goal: goal)
        let item2 = ChecklistItem(title: "Item 2", goal: goal)
        
        #expect(item1.id != item2.id)
    }
    
    @Test("Goal can have multiple checklist items")
    func goalCanHaveMultipleChecklistItems() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        
        let item1 = ChecklistItem(title: "Item 1", goal: goal)
        let item2 = ChecklistItem(title: "Item 2", goal: goal)
        let item3 = ChecklistItem(title: "Item 3", goal: goal)
        
        goal.checklistItems = [item1, item2, item3]
        
        #expect(goal.checklistItems?.count == 3)
    }
    
    // MARK: - ChecklistItemSession Tests
    
    @Test("ChecklistItemSession initializes with item and session")
    func checklistItemSessionInitializesWithItemAndSession() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        let checklistItem = ChecklistItem(title: "Test Item", goal: goal)
        
        let itemSession = ChecklistItemSession(
            checklistItem: checklistItem,
            isCompleted: false,
            session: session
        )
        
        #expect(itemSession.checklistItem?.id == checklistItem.id)
        #expect(itemSession.session?.id == session.id)
        #expect(itemSession.isCompleted == false)
    }
    
    @Test("ChecklistItemSession can be marked as completed")
    func checklistItemSessionCanBeMarkedAsCompleted() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        let checklistItem = ChecklistItem(title: "Test Item", goal: goal)
        
        let itemSession = ChecklistItemSession(
            checklistItem: checklistItem,
            isCompleted: false,
            session: session
        )
        
        #expect(itemSession.isCompleted == false)
        
        itemSession.isCompleted = true
        
        #expect(itemSession.isCompleted == true)
    }
    
    @Test("ChecklistItemSession can be toggled")
    func checklistItemSessionCanBeToggled() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        let checklistItem = ChecklistItem(title: "Test Item", goal: goal)
        
        let itemSession = ChecklistItemSession(
            checklistItem: checklistItem,
            isCompleted: false,
            session: session
        )
        
        itemSession.isCompleted.toggle()
        #expect(itemSession.isCompleted == true)
        
        itemSession.isCompleted.toggle()
        #expect(itemSession.isCompleted == false)
    }
    
    // MARK: - Goal Session Checklist Integration Tests
    
    @Test("GoalSession can have checklist item sessions")
    func goalSessionCanHaveChecklistItemSessions() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        let item1 = ChecklistItem(title: "Item 1", goal: goal)
        let item2 = ChecklistItem(title: "Item 2", goal: goal)
        
        let itemSession1 = ChecklistItemSession(checklistItem: item1, session: session)
        let itemSession2 = ChecklistItemSession(checklistItem: item2, session: session)
        
        session.checklist = [itemSession1, itemSession2]
        
        #expect(session.checklist?.count == 2)
    }
    
    @Test("Checklist completion count can be calculated")
    func checklistCompletionCountCanBeCalculated() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        let item1 = ChecklistItem(title: "Item 1", goal: goal)
        let item2 = ChecklistItem(title: "Item 2", goal: goal)
        let item3 = ChecklistItem(title: "Item 3", goal: goal)
        
        let itemSession1 = ChecklistItemSession(checklistItem: item1, isCompleted: true, session: session)
        let itemSession2 = ChecklistItemSession(checklistItem: item2, isCompleted: false, session: session)
        let itemSession3 = ChecklistItemSession(checklistItem: item3, isCompleted: true, session: session)
        
        session.checklist = [itemSession1, itemSession2, itemSession3]
        
        let completedCount = session.checklist?.filter { $0.isCompleted }.count ?? 0
        let totalCount = session.checklist?.count ?? 0
        
        #expect(completedCount == 2)
        #expect(totalCount == 3)
    }
    
    // MARK: - Checklist Session Independence Tests
    
    @Test("Checklist sessions are independent per day")
    func checklistSessionsAreIndependentPerDay() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let item = ChecklistItem(title: "Test Item", goal: goal)
        goal.checklistItems = [item]
        
        let dayToday = Day(start: today, end: today, calendar: calendar)
        let sessionToday = GoalSession(title: "Today Session", goal: goal, day: dayToday)
        
        let dayTomorrow = Day(start: tomorrow, end: tomorrow, calendar: calendar)
        let sessionTomorrow = GoalSession(title: "Tomorrow Session", goal: goal, day: dayTomorrow)
        
        let itemSessionToday = ChecklistItemSession(checklistItem: item, isCompleted: true, session: sessionToday)
        let itemSessionTomorrow = ChecklistItemSession(checklistItem: item, isCompleted: false, session: sessionTomorrow)
        
        sessionToday.checklist = [itemSessionToday]
        sessionTomorrow.checklist = [itemSessionTomorrow]
        
        // Verify sessions are independent
        #expect(sessionToday.checklist?.first?.isCompleted == true)
        #expect(sessionTomorrow.checklist?.first?.isCompleted == false)
    }
    
    @Test("Empty checklist has zero completion")
    func emptyChecklistHasZeroCompletion() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        session.checklist = []
        
        let completedCount = session.checklist?.filter { $0.isCompleted }.count ?? 0
        let totalCount = session.checklist?.count ?? 0
        
        #expect(completedCount == 0)
        #expect(totalCount == 0)
    }
    
    @Test("Fully completed checklist shows all items done")
    func fullyCompletedChecklistShowsAllItemsDone() {
        let calendar = Calendar.current
        let date = Date()
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let day = Day(start: date, end: date, calendar: calendar)
        let session = GoalSession(title: "Test Session", goal: goal, day: day)
        
        let item1 = ChecklistItem(title: "Item 1", goal: goal)
        let item2 = ChecklistItem(title: "Item 2", goal: goal)
        
        let itemSession1 = ChecklistItemSession(checklistItem: item1, isCompleted: true, session: session)
        let itemSession2 = ChecklistItemSession(checklistItem: item2, isCompleted: true, session: session)
        
        session.checklist = [itemSession1, itemSession2]
        
        let allCompleted = session.checklist?.allSatisfy { $0.isCompleted } ?? false
        
        #expect(allCompleted == true)
    }
    
    // MARK: - Checklist Item Title Tests
    
    @Test("ChecklistItem title can be empty")
    func checklistItemTitleCanBeEmpty() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let item = ChecklistItem(title: "", goal: goal)
        
        #expect(item.title == "")
    }
    
    @Test("ChecklistItem title can contain special characters")
    func checklistItemTitleCanContainSpecialCharacters() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let item = ChecklistItem(title: "Review code ✅ & deploy 🚀", goal: goal)
        
        #expect(item.title == "Review code ✅ & deploy 🚀")
    }
    
    @Test("ChecklistItem title can be very long")
    func checklistItemTitleCanBeVeryLong() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        let longTitle = String(repeating: "Very long title ", count: 20)
        let item = ChecklistItem(title: longTitle, goal: goal)
        
        #expect(item.title == longTitle)
        #expect(item.title.count > 100)
    }
}
