//
//  SmartNotificationScheduler.swift
//  MomentumKit
//
//  Created by Mo Moosa on 17/01/2026.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine
/// Schedules intelligent notifications based on AI-generated plans
@MainActor
public class SmartNotificationScheduler: ObservableObject {
    @Published public var scheduledNotifications: Set<String> = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    public init() {}
    
    // MARK: - Schedule Notifications from Plan
    
    /// Schedule notifications for all sessions in a daily plan
    public func scheduleNotifications(for plan: DailyPlan, on date: Date = Date()) async throws {
        // Request authorization first
        try await requestAuthorization()
        
        // Clear existing scheduled notifications
        await clearScheduledNotifications()
        
        let calendar = Calendar.current
        
        for session in plan.sessions {
            let notificationId = "session-\(session.id)"
            
            // Parse the time string (HH:mm format)
            let components = session.recommendedStartTime.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]) else {
                continue
            }
            
            // Create date components for notification
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Time for \(session.goalTitle)"
            content.body = "Suggested duration: \(session.suggestedDuration) minutes"
            content.sound = .default
            content.categoryIdentifier = "goal-session"
            content.userInfo = [
                "goalId": session.id,
                "goalTitle": session.goalTitle,
                "duration": session.suggestedDuration,
                "priority": session.priority
            ]
            
            // Add action buttons
            content.threadIdentifier = "goal-sessions"
            
            // Create trigger
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: notificationId,
                content: content,
                trigger: trigger
            )
            
            // Schedule
            try await notificationCenter.add(request)
            scheduledNotifications.insert(notificationId)
            
            // Schedule reminder 5 minutes before for high-priority sessions
            if session.priority <= 2 {
                try await scheduleReminder(
                    for: session,
                    minutesBefore: 5,
                    on: date
                )
            }
        }
    }
    
    // MARK: - Smart Reminders
    
    /// Schedule a reminder notification before a session
    private func scheduleReminder(
        for session: PlannedSession,
        minutesBefore: Int,
        on date: Date
    ) async throws {
        let calendar = Calendar.current
        
        // Parse session time
        let components = session.recommendedStartTime.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return
        }
        
        // Calculate reminder time
        var sessionDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        let reminderDate = calendar.date(byAdding: .minute, value: -minutesBefore, to: sessionDate) ?? sessionDate
        
        let reminderComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming: \(session.goalTitle)"
        content.body = "Starting in \(minutesBefore) minutes"
        content.sound = .defaultCritical
        content.categoryIdentifier = "goal-reminder"
        content.userInfo = [
            "goalId": session.id,
            "isReminder": true
        ]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reminder-\(session.id)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    // MARK: - Adaptive Notifications
    
    /// Schedule notifications that adapt to user behavior
    public func scheduleAdaptiveNotifications(
        for plan: DailyPlan,
        on date: Date = Date(),
        userActivity: UserActivityLevel = .normal
    ) async throws {
        try await requestAuthorization()
        await clearScheduledNotifications()
        
        for session in plan.sessions {
            // Adjust notification timing based on user activity level
            let notificationOffset = calculateNotificationOffset(
                for: session,
                userActivity: userActivity
            )
            
            try await scheduleNotification(
                for: session,
                on: date,
                minutesOffset: notificationOffset
            )
        }
    }
    
    private func calculateNotificationOffset(
        for session: PlannedSession,
        userActivity: UserActivityLevel
    ) -> Int {
        switch userActivity {
        case .low:
            // User is less active, send earlier reminders
            return -15
        case .normal:
            // Standard timing
            return 0
        case .high:
            // User is very active, just-in-time notifications
            return -5
        }
    }
    
    private func scheduleNotification(
        for session: PlannedSession,
        on date: Date,
        minutesOffset: Int
    ) async throws {
        let calendar = Calendar.current
        
        let components = session.recommendedStartTime.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return
        }
        
        var sessionDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        let notificationDate = calendar.date(byAdding: .minute, value: minutesOffset, to: sessionDate) ?? sessionDate
        
        let notificationComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        
        let content = UNMutableNotificationContent()
        
        if minutesOffset < 0 {
            content.title = "Upcoming: \(session.goalTitle)"
            content.body = "Starting in \(abs(minutesOffset)) minutes • \(session.suggestedDuration) min session"
        } else {
            content.title = "Time for \(session.goalTitle)"
            content.body = "Let's spend \(session.suggestedDuration) minutes on this"
        }
        
        content.sound = .default
        content.categoryIdentifier = "goal-session"
        content.userInfo = [
            "goalId": session.id,
            "goalTitle": session.goalTitle,
            "duration": session.suggestedDuration,
            "priority": session.priority,
            "reasoning": session.reasoning
        ]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: notificationComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "adaptive-\(session.id)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        scheduledNotifications.insert("adaptive-\(session.id)")
    }
    
    // MARK: - Notification Actions
    
    /// Configure notification action categories
    public func configureNotificationActions() {
        // Start action
        let startAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: "Start Now",
            options: [.foreground]
        )
        
        // Snooze action
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_SESSION",
            title: "Remind in 15 min",
            options: []
        )
        
        // Skip action
        let skipAction = UNNotificationAction(
            identifier: "SKIP_SESSION",
            title: "Skip",
            options: [.destructive]
        )
        
        // Create category
        let sessionCategory = UNNotificationCategory(
            identifier: "goal-session",
            actions: [startAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "goal-reminder",
            actions: [startAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([sessionCategory, reminderCategory])
    }
    
    // MARK: - Management
    
    /// Request notification authorization
    public func requestAuthorization() async throws {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        
        if !granted {
            throw NotificationError.authorizationDenied
        }
    }
    
    /// Clear all scheduled notifications
    public func clearScheduledNotifications() async {
        let identifiers = Array(scheduledNotifications)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        scheduledNotifications.removeAll()
    }
    
    /// Get all pending notifications
    public func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }
    
    /// Cancel notification for specific session
    public func cancelNotification(for sessionId: String) {
        let identifier = "session-\(sessionId)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledNotifications.remove(identifier)
    }
}

// MARK: - Supporting Types

public enum UserActivityLevel {
    case low // Needs more reminders
    case normal // Standard reminders
    case high // Minimal reminders
}

public enum NotificationError: Error {
    case authorizationDenied
    case invalidTime
    case schedulingFailed
}

// MARK: - Smart Notification View

/// SwiftUI view to manage notifications for a plan
public struct SmartNotificationView: View {
    @StateObject private var scheduler = SmartNotificationScheduler()
    let plan: DailyPlan
    
    @State private var notificationsEnabled = false
    @State private var userActivity: UserActivityLevel = .normal
    
    public var body: some View {
        Form {
            Section {
                Toggle("Enable Smart Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            Task { await scheduleNotifications() }
                        } else {
                            Task { await scheduler.clearScheduledNotifications() }
                        }
                    }
            }
            
            if notificationsEnabled {
                Section("Activity Level") {
                    Picker("Your Activity Level", selection: $userActivity) {
                        Text("Low (More Reminders)").tag(UserActivityLevel.low)
                        Text("Normal").tag(UserActivityLevel.normal)
                        Text("High (Fewer Reminders)").tag(UserActivityLevel.high)
                    }
                    .onChange(of: userActivity) { _, _ in
                        Task { await scheduleNotifications() }
                    }
                }
                
                Section("Scheduled Notifications") {
                    ForEach(plan.sessions) { session in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.goalTitle)
                                    .font(.headline)
                                Text(session.recommendedStartTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if scheduler.scheduledNotifications.contains("session-\(session.id)") {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "bell.slash")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            scheduler.configureNotificationActions()
        }
    }
    
    private func scheduleNotifications() async {
        do {
            try await scheduler.scheduleAdaptiveNotifications(
                for: plan,
                userActivity: userActivity
            )
        } catch {
            print("Failed to schedule notifications: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SmartNotificationView(plan: DailyPlan(
            sessions: [
                PlannedSession(
                    id: "1",
                    goalTitle: "Meditation",
                    recommendedStartTime: "07:00",
                    suggestedDuration: 15,
                    priority: 2,
                    reasoning: "Morning meditation"
                ),
                PlannedSession(
                    id: "2",
                    goalTitle: "Reading",
                    recommendedStartTime: "19:30",
                    suggestedDuration: 30,
                    priority: 3,
                    reasoning: "Evening reading"
                )
            ],
            overallStrategy: "Balance morning and evening activities"
        ))
    }
}
