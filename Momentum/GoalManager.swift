//
//  GoalManager.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import SwiftData
import MomentumKit
#if canImport(WidgetKit)
import WidgetKit
#endif
// TODO: Static...
/// Manages goal CRUD operations with proper cleanup and ordering
@MainActor
class GoalManager {
    
    /// Delete a goal and all related data in the correct order
    /// - Parameters:
    ///   - goal: The goal to delete
    ///   - context: SwiftData model context
    ///   - timerManager: Optional timer manager to clear active sessions
    static func delete(
        _ goal: Goal,
        from context: ModelContext,
        timerManager: SessionTimerManager? = nil
    ) {
        // Check if active session needs clearing
        if let timerManager = timerManager,
           let activeSession = timerManager.activeSession {
            let sessionIDs = goal.goalSessions.map { $0.id }
            if sessionIDs.contains(activeSession.id) {
                timerManager.clearActiveSession()
            }
        }
        
        // CRITICAL: Delete sessions first to allow SwiftUI @Query to update
        // This prevents crashes from accessing deleted goal relationships
        let sessionsToDelete = goal.goalSessions
        for session in sessionsToDelete {
            context.delete(session)
        }
        
        // Delete checklist items
        for item in goal.checklistItems {
            context.delete(item)
        }
        
        // Delete interval lists
        for list in goal.intervalLists {
            context.delete(list)
        }
        
        // Now delete the goal itself
        context.delete(goal)
        
        // Save changes
        do {
            try context.save()
        } catch {
            print("Failed to delete goal: \(error)")
        }
        
        // Reload widget timelines
        #if canImport(WidgetKit)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Archive or unarchive a goal
    /// - Parameters:
    ///   - goal: The goal to archive/unarchive
    ///   - context: SwiftData model context
    static func toggleArchive(_ goal: Goal, context: ModelContext) {
        goal.status = goal.status == .archived ? .active : .archived
        
        do {
            try context.save()
        } catch {
            print("Failed to archive goal: \(error)")
        }
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    /// Duplicate a goal
    /// - Parameters:
    ///   - goal: The goal to duplicate
    ///   - context: SwiftData model context
    /// - Returns: The newly created goal
    @discardableResult
    static func duplicate(_ goal: Goal, context: ModelContext) -> Goal {
        let newGoal = Goal(
            title: "\(goal.title) (Copy)",
            primaryTag: goal.primaryTag,
            weeklyTarget: goal.weeklyTarget,
            notificationsEnabled: goal.notificationsEnabled,
            healthKitMetric: goal.healthKitMetric,
            healthKitSyncEnabled: goal.healthKitSyncEnabled
        )
        
        // Copy schedule if exists
        if goal.hasSchedule {
            newGoal.dayTimeSchedule = goal.dayTimeSchedule
        }
        
        context.insert(newGoal)
        
        do {
            try context.save()
        } catch {
            print("Failed to duplicate goal: \(error)")
        }
        
        return newGoal
    }
}
