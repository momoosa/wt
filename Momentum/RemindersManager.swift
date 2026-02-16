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
    
    /// Convert a reminder to a Goal
    func createGoal(from reminder: EKReminder, context: ModelContext, goalStore: GoalStore) -> Goal {
        let title = reminder.title ?? "Untitled Reminder"
        
        // Get or create a "Reminders" tag
        let remindersTag = goalStore.getOrCreateRemindersTag(context: context)
        
        // Create the goal with the tag
        let goal = Goal(title: title, primaryTag: remindersTag)
        
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
            goal.checklistItems.append(checklistItem)
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
        let tealPreset = themePresets.first(where: { $0.id == "teal" })!
        let tag = GoalTag(title: "Reminders", color: tealPreset.toTheme())
        context.insert(tag)
        return tag
    }
}
