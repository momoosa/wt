//
//  SessionManagement.swift
//  Momentum
//
//  Extracted from ContentView.swift — Session CRUD, checklist sync, validation
//

import SwiftUI
import SwiftData
import MomentumKit
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Session Management

extension ContentView {
    
    func refreshGoals() {
        // Guard against re-entrant calls (e.g., refreshGoals modifying sessions triggers onChange which calls refreshGoals again)
        guard !isRefreshingGoals else { return }
        isRefreshingGoals = true
        defer { isRefreshingGoals = false }
        
        // Fetch all sessions for today on-demand (avoids a persistent @Query that re-fires on every DB change)
        let dayID = day.id
        let descriptor = FetchDescriptor<GoalSession>()
        let allSessionsForDay = (try? modelContext.fetch(descriptor))?.filter { $0.day?.id == dayID } ?? []
        
        // First, clean up any sessions whose goals have been deleted
        let orphanedSessions = allSessionsForDay.filter { !isGoalValid($0) }
        for session in orphanedSessions {
            modelContext.delete(session)
        }
        
        // Clean up duplicate sessions (same goal, same day) — keep the one with the most progress
        var sessionsByGoal: [UUID: [GoalSession]] = [:]
        for session in allSessionsForDay {
            guard let goalID = session.goal?.id else { continue }
            sessionsByGoal[goalID, default: []].append(session)
        }
        for (_, duplicates) in sessionsByGoal where duplicates.count > 1 {
            // Keep the session with the highest logged time; delete the rest
            let sorted = duplicates.sorted { (a: GoalSession, b: GoalSession) in a.elapsedTime > b.elapsedTime }
            for session in sorted.dropFirst() {
                modelContext.delete(session)
            }
        }
        
        // Then create sessions for goals that don't have them
        // Use allSessionsForDay (not filtered by dailyTarget) to check existence to avoid duplicates
        // Skip archived goals (e.g. system break goal)
        for goal in goals where goal.status != .archived {
            if !allSessionsForDay.contains(where: { $0.goal == goal && $0.day == day }) {
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                modelContext.insert(session)
                
                // Create checklist item sessions for this goal session
                if let checklistItems = goal.checklistItems {
                    for checklistItem in checklistItems {
                        let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                        modelContext.insert(itemSession)
                        session.checklist?.append(itemSession)
                    }
                }
            }
        }
        
        // Save without triggering animations — this is background data loading, not user interaction
        if modelContext.hasChanges {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                modelContext.safeSave(showingToast: $navigation.toastConfig)
                // Reload widgets when sessions are created or deleted
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }

    /// Sync checklist changes from a goal to its existing sessions
    func syncChecklistToSessions(for goal: Goal) {
        // Get all sessions for this goal
        let goalSessions = sessions.filter { $0.goal == goal }

        guard let goalChecklistItems = goal.checklistItems else {
            // Goal has no checklist items - remove all checklist sessions
            for session in goalSessions {
                if let checklistSessions = session.checklist {
                    for checklistSession in checklistSessions {
                        modelContext.delete(checklistSession)
                    }
                    session.checklist?.removeAll()
                }
            }
            return
        }

        // Sync checklist to each session
        for session in goalSessions {
            var sessionChecklist = session.checklist ?? []

            // Get existing checklist item IDs in the session
            let existingItemIDs = Set(sessionChecklist.compactMap { $0.checklistItem?.id })
            let goalItemIDs = Set(goalChecklistItems.map { $0.id })

            // Remove checklist sessions for items that no longer exist in goal
            let itemsToRemove = sessionChecklist.filter { checklistSession in
                guard let item = checklistSession.checklistItem else { return true }
                return !goalItemIDs.contains(item.id)
            }

            for checklistSession in itemsToRemove {
                modelContext.delete(checklistSession)
                if let index = sessionChecklist.firstIndex(where: { $0.id == checklistSession.id }) {
                    sessionChecklist.remove(at: index)
                }
            }

            // Add new checklist sessions for items that don't exist in session yet
            for checklistItem in goalChecklistItems {
                if !existingItemIDs.contains(checklistItem.id) {
                    let newChecklistSession = ChecklistItemSession(
                        checklistItem: checklistItem,
                        isCompleted: false,
                        session: session
                    )
                    modelContext.insert(newChecklistSession)
                    sessionChecklist.append(newChecklistSession)
                }
            }

            // Update the session's checklist
            session.checklist = sessionChecklist
        }

        // Save changes
        if modelContext.hasChanges {
            modelContext.safeSave(showingToast: $navigation.toastConfig)
        }
    }

    func skip(session: GoalSession) {
        // Delegate to ViewModel
        viewModel.skip(session)
    }
    
    /// Check if a session's goal is still valid (not deleted)
    func isGoalValid(_ session: GoalSession) -> Bool {
        // Try to access the session and goal properties - if it throws or fails, they were deleted
        // We need to catch both Swift errors and SwiftData faults
        guard let _ = try? session.persistentModelID else {
            return false
        }
        
        do {
            _ = session.status
            guard let goal = session.goal else { return false }
            _ = goal.id
            _ = goal.title
            _ = goal.status
            return true
        } catch {
            return false
        }
    }
}
