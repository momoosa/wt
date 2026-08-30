//
//  RemindersSyncService.swift
//  Momentum
//
//  Handles two-way sync between a Goal's checklist and a linked Apple Reminders list.
//

import Foundation
import EventKit
import SwiftData
import MomentumKit
import os

@MainActor
struct RemindersSyncService {
    
    private static let remindersManager = RemindersManager()
    
    // MARK: - Link / Unlink
    
    /// Link a Reminders list to a goal, replacing its checklist items with the list's reminders.
    static func linkList(
        calendarID: String,
        to goal: Goal,
        session: GoalSession?,
        context: ModelContext
    ) async throws {
        // Fetch incomplete reminders from the list
        let reminders = try await remindersManager.fetchReminders(in: calendarID)
        
        // Remove existing checklist items that were linked (keep manually-created ones)
        if let existing = goal.checklistItems {
            for item in existing where item.remindersIdentifier != nil {
                // Delete associated sessions first
                if let sessions = item.sessions {
                    for s in sessions { context.delete(s) }
                }
                context.delete(item)
            }
        }
        
        // Create ChecklistItems from reminders
        var newItems: [ChecklistItem] = []
        for reminder in reminders {
            let item = ChecklistItem(title: reminder.title ?? "Untitled")
            item.remindersIdentifier = reminder.calendarItemIdentifier
            item.notes = reminder.notes
            item.goal = goal
            context.insert(item)
            newItems.append(item)
        }
        
        // Keep any manually-created items (no remindersIdentifier)
        let manualItems = (goal.checklistItems ?? []).filter { $0.remindersIdentifier == nil }
        goal.checklistItems = manualItems + newItems
        
        // Update link metadata
        goal.linkedRemindersListID = calendarID
        goal.linkedRemindersLastSynced = Date()
        
        // Create ChecklistItemSessions for the current session
        if let session {
            for item in newItems {
                let itemSession = ChecklistItemSession(checklistItem: item, session: session)
                context.insert(itemSession)
                if session.checklist == nil { session.checklist = [] }
                session.checklist?.append(itemSession)
            }
        }
        
        context.safeSave()
    }
    
    /// Unlink a Reminders list from a goal. Keeps existing checklist items as standalone.
    static func unlinkList(from goal: Goal, context: ModelContext) {
        goal.linkedRemindersListID = nil
        goal.linkedRemindersLastSynced = nil
        
        // Clear reminders identifiers so items become standalone
        if let items = goal.checklistItems {
            for item in items {
                item.remindersIdentifier = nil
            }
        }
        
        context.safeSave()
    }
    
    // MARK: - Two-Way Sync
    
    /// Sync a linked goal's checklist with its Reminders list.
    /// Pulls new/changed reminders and pushes completion status.
    static func syncIfLinked(
        goal: Goal,
        session: GoalSession?,
        context: ModelContext
    ) async {
        guard let calendarID = goal.linkedRemindersListID else { return }
        
        // Ensure the event store is connected
        if !remindersManager.isAuthorized {
            _ = try? await remindersManager.requestAccess()
        }
        guard remindersManager.isAuthorized else { return }
        
        do {
            // Fetch all reminders (completed + incomplete) from the linked list
            let reminders = try await remindersManager.fetchReminders(
                in: calendarID,
                includeCompleted: true
            )
            
            let existingItems = goal.checklistItems ?? []
            let remindersByID = Dictionary(
                reminders.map { ($0.calendarItemIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let existingByReminderID = Dictionary(
                existingItems.compactMap { item -> (String, ChecklistItem)? in
                    guard let rid = item.remindersIdentifier else { return nil }
                    return (rid, item)
                },
                uniquingKeysWith: { first, _ in first }
            )
            
            // 1. Add new reminders that don't exist as checklist items
            for reminder in reminders {
                let rid = reminder.calendarItemIdentifier
                if existingByReminderID[rid] == nil {
                    let item = ChecklistItem(title: reminder.title ?? "Untitled")
                    item.remindersIdentifier = rid
                    item.notes = reminder.notes
                    item.goal = goal
                    context.insert(item)
                    if goal.checklistItems == nil { goal.checklistItems = [] }
                    goal.checklistItems?.append(item)
                    
                    // Create session entry for today
                    if let session {
                        let itemSession = ChecklistItemSession(
                            checklistItem: item,
                            isCompleted: reminder.isCompleted,
                            session: session
                        )
                        context.insert(itemSession)
                        if session.checklist == nil { session.checklist = [] }
                        session.checklist?.append(itemSession)
                    }
                }
            }
            
            // 2. Update existing items and remove deleted ones
            for item in existingItems {
                guard let rid = item.remindersIdentifier else { continue }
                
                if let reminder = remindersByID[rid] {
                    // Update title if changed
                    let newTitle = reminder.title ?? "Untitled"
                    if item.title != newTitle {
                        item.title = newTitle
                    }
                    if let notes = reminder.notes, item.notes != notes {
                        item.notes = notes
                    }
                } else {
                    // Reminder was deleted in Reminders — remove checklist item
                    if let sessions = item.sessions {
                        for s in sessions { context.delete(s) }
                    }
                    goal.checklistItems?.removeAll { $0.id == item.id }
                    context.delete(item)
                }
            }
            
            // 3. Sync completion status for today's session
            if let session, let checklist = session.checklist {
                for itemSession in checklist {
                    guard let rid = itemSession.checklistItem?.remindersIdentifier,
                          let reminder = remindersByID[rid] else { continue }
                    
                    if reminder.isCompleted && !itemSession.isCompleted {
                        // Completed in Reminders → mark completed in app
                        itemSession.isCompleted = true
                    } else if itemSession.isCompleted && !reminder.isCompleted {
                        // Completed in app → mark completed in Reminders
                        reminder.isCompleted = true
                        try? remindersManager.saveReminder(reminder)
                    }
                }
            }
            
            goal.linkedRemindersLastSynced = Date()
            context.safeSave()
            
        } catch {
            AppLogger.app.error("Reminders sync failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Single Item Sync
    
    /// Push a single checklist item's completion status to Reminders.
    static func pushCompletionToReminders(item: ChecklistItemSession) {
        guard let rid = item.checklistItem?.remindersIdentifier,
              remindersManager.isAuthorized else { return }
        
        // Look up the reminder by identifier
        guard let reminder = remindersManager.fetchReminderByIdentifier(rid) else { return }
        
        if reminder.isCompleted != item.isCompleted {
            reminder.isCompleted = item.isCompleted
            try? remindersManager.saveReminder(reminder)
        }
    }
}
