//
//  GoalNotificationManager.swift
//  Momentum
//
//  Manages schedule-based notifications for goals
//

import Foundation
import UserNotifications
import SwiftData
import MomentumKit

@MainActor
public class GoalNotificationManager {
    private let notificationCenter = UNUserNotificationCenter.current()
    
    public init() {}
    
    // MARK: - Authorization
    
    /// Request notification authorization
    public func requestAuthorization() async throws {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        
        if !granted {
            throw GoalNotificationError.authorizationDenied
        }
    }
    
    // MARK: - Schedule Management
    
    /// Schedule notifications for a goal for the next 7 days
    public func scheduleNotifications(for goal: Goal) async throws {
        // Request authorization first
        try await requestAuthorization()
        
        // Clear existing schedule notifications for this goal
        await cancelScheduleNotifications(for: goal)
        
        guard goal.scheduleNotificationsEnabled && goal.hasSchedule else {
            print("⏭️ Skipping schedule notifications for '\(goal.title)': disabled or no schedule")
            return
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Schedule for the next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: targetDate)
            let times = goal.timesForWeekday(weekday)
            
            // Schedule notification for each time slot on this day
            for timeOfDay in times {
                try await scheduleNotification(
                    for: goal,
                    on: targetDate,
                    at: timeOfDay
                )
            }
        }
        
        print("✅ Scheduled notifications for '\(goal.title)' for next 7 days")
    }
    
    /// Schedule a single notification for a goal at a specific date and time
    private func scheduleNotification(
        for goal: Goal,
        on date: Date,
        at timeOfDay: TimeOfDay
    ) async throws {
        let calendar = Calendar.current
        
        // Get the hour for this time of day
        let hour = timeOfDay.startHour
        
        // Create date components for the notification
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time for \(goal.title)"
        content.body = "Your \(timeOfDay.displayName.lowercased()) session is scheduled now"
        content.sound = .default
        content.categoryIdentifier = "goal-schedule"
        content.userInfo = [
            "goalId": goal.id.uuidString,
            "goalTitle": goal.title,
            "timeOfDay": timeOfDay.rawValue
        ]
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create unique identifier
        let identifier = notificationIdentifier(for: goal, date: date, time: timeOfDay)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule
        try await notificationCenter.add(request)
        
        // Debug log
        if let notificationDate = calendar.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            print("📅 Scheduled: '\(goal.title)' for \(formatter.string(from: notificationDate))")
        }
    }
    
    // MARK: - Session Notifications
    
    /// Send an immediate notification when a session starts
    public func sendSessionStartNotification(for goal: Goal) async {
        guard goal.scheduleNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Session Started"
        content.body = "Your \(goal.title) session has begun"
        content.sound = .default
        content.categoryIdentifier = "goal-session-start"
        content.userInfo = [
            "goalId": goal.id.uuidString,
            "goalTitle": goal.title
        ]
        
        // Fire immediately
        let request = UNNotificationRequest(
            identifier: "goal-session-start-\(goal.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // nil trigger = immediate notification
        )
        
        do {
            try await notificationCenter.add(request)
            print("▶️ Sent session start notification for '\(goal.title)'")
        } catch {
            print("❌ Failed to send session start notification: \(error)")
        }
    }
    
    // MARK: - Completion Notifications
    
    /// Send an immediate notification when a session meets its daily target
    public func sendCompletionNotification(for goal: Goal, elapsedTime: TimeInterval) async {
        guard goal.completionNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Goal Completed! 🎉"
        content.body = "You've completed your \(goal.title) goal for today (\(Int(elapsedTime / 60)) minutes)"
        content.sound = .default
        content.categoryIdentifier = "goal-completion"
        content.userInfo = [
            "goalId": goal.id.uuidString,
            "goalTitle": goal.title,
            "elapsedTime": elapsedTime
        ]
        
        // Fire immediately
        let request = UNNotificationRequest(
            identifier: "goal-completion-\(goal.id.uuidString)",
            content: content,
            trigger: nil // nil trigger = immediate notification
        )
        
        do {
            try await notificationCenter.add(request)
            print("🎉 Sent completion notification for '\(goal.title)'")
        } catch {
            print("❌ Failed to send completion notification: \(error)")
        }
    }
    
    // MARK: - Cancellation
    
    /// Cancel schedule notifications for a specific goal
    public func cancelScheduleNotifications(for goal: Goal) async {
        let calendar = Calendar.current
        let today = Date()
        
        var identifiers: [String] = []
        
        // Collect identifiers for the next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: targetDate)
            let times = goal.timesForWeekday(weekday)
            
            for timeOfDay in times {
                let identifier = notificationIdentifier(for: goal, date: targetDate, time: timeOfDay)
                identifiers.append(identifier)
            }
        }
        
        // Also cancel by prefix to catch any old schedule notifications
        let allPending = await notificationCenter.pendingNotificationRequests()
        let goalPrefix = "goal-\(goal.id.uuidString)"
        let scheduleIdentifiers = allPending
            .filter { $0.identifier.hasPrefix(goalPrefix) && !$0.identifier.contains("completion") }
            .map { $0.identifier }
        
        identifiers.append(contentsOf: scheduleIdentifiers)
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        print("🗑️ Cancelled schedule notifications for '\(goal.title)'")
    }
    
    /// Cancel all notifications (both schedule and completion) for a goal
    public func cancelAllNotifications(for goal: Goal) async {
        let allPending = await notificationCenter.pendingNotificationRequests()
        let goalPrefix = "goal-\(goal.id.uuidString)"
        let goalIdentifiers = allPending
            .filter { $0.identifier.hasPrefix(goalPrefix) || $0.identifier.contains("completion-\(goal.id.uuidString)") }
            .map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: goalIdentifiers)
        
        print("🗑️ Cancelled all notifications for '\(goal.title)'")
    }
    
    /// Cancel all goal notifications across all goals
    public func cancelAllGoalNotifications() async {
        let allPending = await notificationCenter.pendingNotificationRequests()
        let goalIdentifiers = allPending
            .filter { $0.identifier.hasPrefix("goal-") }
            .map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: goalIdentifiers)
        
        print("🗑️ Cancelled all goal notifications")
    }
    
    // MARK: - Batch Operations
    
    /// Reschedule notifications for all goals with schedule notifications enabled
    public func rescheduleAllGoals(goals: [Goal]) async throws {
        for goal in goals where goal.scheduleNotificationsEnabled && goal.hasSchedule {
            try await scheduleNotifications(for: goal)
        }
    }
    
    // MARK: - Utilities
    
    /// Get pending notifications count for a goal
    public func pendingNotificationsCount(for goal: Goal) async -> Int {
        let allPending = await notificationCenter.pendingNotificationRequests()
        let goalPrefix = "goal-\(goal.id.uuidString)"
        return allPending.filter { $0.identifier.hasPrefix(goalPrefix) }.count
    }
    
    /// Check if notifications need refreshing (scheduled > 24 hours ago)
    public func needsRefresh() async -> Bool {
        let allPending = await notificationCenter.pendingNotificationRequests()
        
        // If there are very few pending notifications, likely needs refresh
        let goalNotifications = allPending.filter { $0.identifier.hasPrefix("goal-") }
        return goalNotifications.count < 5
    }
    
    /// Create unique identifier for a notification
    private func notificationIdentifier(for goal: Goal, date: Date, time: TimeOfDay) -> String {
        let calendar = Calendar.current
        let dateString = calendar.startOfDay(for: date).timeIntervalSince1970
        return "goal-\(goal.id.uuidString)-\(dateString)-\(time.rawValue)"
    }
}

// MARK: - TimeOfDay Extension

extension TimeOfDay {
    /// The starting hour for this time of day (24-hour format)
    var startHour: Int {
        switch self {
        case .morning: return 7    // 7:00 AM
        case .midday: return 12    // 12:00 PM
        case .afternoon: return 15 // 3:00 PM
        case .evening: return 18   // 6:00 PM
        case .night: return 21     // 9:00 PM
        }
    }
}

// MARK: - Error Types

public enum GoalNotificationError: Error {
    case authorizationDenied
    case schedulingFailed
}
