//
//  RemindersManager.swift
//  Momentum
//
//  Created by Assistant on 15/02/2026.
//

import Foundation
import EventKit
import MomentumKit
import SwiftData

/// Manager for accessing and importing reminders from the Reminders app
@Observable
@MainActor
class RemindersManager {
    private let eventStore = EKEventStore()
    
    /// Authorization status for reminders access
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }
    
    /// Whether reminders access is granted
    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }
    
    /// Request full access to reminders
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToReminders()
    }
    
    /// Fetch all incomplete reminders
    func fetchIncompleteReminders() async throws -> [EKReminder] {
        guard isAuthorized else {
            throw RemindersError.notAuthorized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: nil
            )
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - List Operations
    
    /// Fetch all reminder-type calendars (lists)
    func fetchAllLists() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return eventStore.calendars(for: .reminder)
    }
    
    /// Look up a specific calendar by identifier
    func calendar(for identifier: String) -> EKCalendar? {
        guard isAuthorized else { return nil }
        return eventStore.calendar(withIdentifier: identifier)
    }
    
    /// Fetch reminders from a specific calendar
    func fetchReminders(in calendarID: String, includeCompleted: Bool = false) async throws -> [EKReminder] {
        guard isAuthorized else { throw RemindersError.notAuthorized }
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            throw RemindersError.fetchFailed
        }
        
        // Fetch incomplete reminders
        let incomplete: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil, ending: nil, calendars: [calendar]
            )
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        guard includeCompleted else { return incomplete }
        
        // Fetch completed reminders separately and merge
        let completed: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            let predicate = eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: nil, ending: nil, calendars: [calendar]
            )
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        return incomplete + completed
    }
    
    /// Save changes to a reminder (e.g. completion status)
    func saveReminder(_ reminder: EKReminder) throws {
        try eventStore.save(reminder, commit: true)
    }
    
    /// Look up a single reminder by its calendarItemIdentifier
    func fetchReminderByIdentifier(_ identifier: String) -> EKReminder? {
        guard isAuthorized else { return nil }
        return eventStore.calendarItem(withIdentifier: identifier) as? EKReminder
    }
    
    // MARK: - Goal Import
    
    /// Convert a reminder to a Goal
    func createGoal(from reminder: EKReminder, context: ModelContext, goalStore: GoalStore) -> Goal {
        let title = reminder.title ?? "Untitled Reminder"
        
        // Get or create a "Reminders" tag
        let remindersTag = goalStore.getOrCreateRemindersTag(context: context)
        
        // Create the goal with the tag and default daily target (30 minutes)
        let defaultDailySeconds: Double = 30 * 60 // 30 minutes in seconds
        let goal = Goal(title: title, primaryTag: remindersTag)
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = defaultDailySeconds
        
        // If the reminder has a due date, set up scheduling around it
        if let dueDate = reminder.dueDateComponents?.date {
            // Set up a schedule for the day the reminder is due
            let weekday = Calendar.current.component(.weekday, from: dueDate)
            goal.setTimes([.morning, .afternoon], forWeekday: weekday)
        } else {
            // Default to daily schedule if no due date
            for weekday in 1...7 {
                goal.setTimes([.morning], forWeekday: weekday)
            }
        }
        
        // Add notes as a checklist item if available
        if let notes = reminder.notes, !notes.isEmpty {
            let checklistItem = ChecklistItem(title: notes)
            if goal.checklistItems == nil {
                goal.checklistItems = []
            }
            goal.checklistItems?.append(checklistItem)
        }
        
        context.insert(goal)
        
        return goal
    }
    
    /// Import multiple reminders as goals
    func importReminders(_ reminders: [EKReminder], context: ModelContext, goalStore: GoalStore) -> [Goal] {
        return reminders.map { reminder in
            createGoal(from: reminder, context: context, goalStore: goalStore)
        }
    }
}

enum RemindersError: Error, LocalizedError {
    case notAuthorized
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Access to Reminders not authorized"
        case .fetchFailed:
            return "Failed to fetch reminders"
        }
    }
}

extension GoalStore {
    /// Get or create a tag for imported reminders
    func getOrCreateRemindersTag(context: ModelContext) -> GoalTag {
        // Try to find existing "Reminders" tag
        let descriptor = FetchDescriptor<GoalTag>(
            predicate: #Predicate { $0.title == "Reminders" }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Create new tag with a distinct theme
        let tag = GoalTag(title: "Reminders", themeID: "palette_03")
        context.insert(tag)
        return tag
    }
}
