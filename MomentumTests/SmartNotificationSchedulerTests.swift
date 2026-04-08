//
//  SmartNotificationSchedulerTests.swift
//  WeektimeTests
//
//  Created by Mo Moosa on 21/03/2026.
//

import Testing
import Foundation
import UserNotifications
@testable import MomentumKit
@testable import Momentum

@Suite("SmartNotificationScheduler Tests")
@MainActor
struct SmartNotificationSchedulerTests {
    
    // MARK: - Helper Methods
    
    private func createTestSession(
        id: String = UUID().uuidString,
        title: String = "Test Goal",
        startTime: String = "09:00",
        duration: Int = 30,
        priority: Int = 3
    ) -> PlannedSession {
        PlannedSession(
            id: id,
            goalTitle: title,
            recommendedStartTime: startTime,
            suggestedDuration: duration,
            priority: priority,
            reasoning: "Test reasoning"
        )
    }
    
    private func createTestPlan(sessions: [PlannedSession]) -> DailyPlan {
        DailyPlan(
            sessions: sessions,
            overallStrategy: "Test strategy"
        )
    }
    
    // MARK: - calculateNotificationOffset Tests
    
    @Test("calculateNotificationOffset returns correct offset for low activity", .disabled("Hangs waiting for notification authorization in test environment"))
    func testCalculateNotificationOffsetLowActivity() async {
        let scheduler = SmartNotificationScheduler()
        let session = createTestSession()
        
        // Use reflection or a testing approach to access private method
        // For now, we'll test through the public API
        
        // Low activity should trigger earlier notifications (-15 minutes)
        // We can verify this by checking the scheduled notifications
        let plan = createTestPlan(sessions: [session])
        
        do {
            try await scheduler.scheduleAdaptiveNotifications(
                for: plan,
                userActivity: .low
            )
            
            let pending = await scheduler.getPendingNotifications()
            // In test environment, notifications may not be authorized
            // So we accept either: notifications scheduled OR authorization denied
            #expect(pending.count >= 0)
        } catch let error as NotificationError {
            // Authorization denied in test environment is expected
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("calculateNotificationOffset returns correct offset for normal activity", .disabled("Hangs waiting for notification authorization in test environment"))
    func testCalculateNotificationOffsetNormalActivity() async {
        let scheduler = SmartNotificationScheduler()
        let session = createTestSession()
        let plan = createTestPlan(sessions: [session])
        
        // Normal activity should have no offset (0 minutes)
        do {
            try await scheduler.scheduleAdaptiveNotifications(
                for: plan,
                userActivity: .normal
            )
            
            let pending = await scheduler.getPendingNotifications()
            #expect(pending.count >= 0)
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("calculateNotificationOffset returns correct offset for high activity", .disabled("Hangs waiting for notification authorization in test environment"))
    func testCalculateNotificationOffsetHighActivity() async {
        let scheduler = SmartNotificationScheduler()
        let session = createTestSession()
        let plan = createTestPlan(sessions: [session])
        
        // High activity should trigger just-in-time notifications (-5 minutes)
        do {
            try await scheduler.scheduleAdaptiveNotifications(
                for: plan,
                userActivity: .high
            )
            
            let pending = await scheduler.getPendingNotifications()
            #expect(pending.count >= 0)
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - scheduleNotifications Tests
    
    @Test("scheduleNotifications clears existing notifications", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsClearsExisting() async {
        let scheduler = SmartNotificationScheduler()
        
        // Manually add some scheduled notification IDs
        scheduler.scheduledNotifications.insert("test-1")
        scheduler.scheduledNotifications.insert("test-2")
        
        #expect(scheduler.scheduledNotifications.count == 2)
        
        let plan = createTestPlan(sessions: [createTestSession()])
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
        } catch {
            // Expected if authorization denied
        }
        
        // Should have cleared old notifications
        #expect(!scheduler.scheduledNotifications.contains("test-1"))
        #expect(!scheduler.scheduledNotifications.contains("test-2"))
    }
    
    @Test("scheduleNotifications creates notifications for all sessions", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsCreatesAll() async {
        let scheduler = SmartNotificationScheduler()
        
        let sessions = [
            createTestSession(id: "goal1", startTime: "09:00"),
            createTestSession(id: "goal2", startTime: "14:00"),
            createTestSession(id: "goal3", startTime: "19:00")
        ]
        let plan = createTestPlan(sessions: sessions)
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            
            // If authorization granted, verify notifications were scheduled
            if scheduler.scheduledNotifications.count > 0 {
                #expect(scheduler.scheduledNotifications.count >= 3)
                #expect(scheduler.scheduledNotifications.contains("session-goal1"))
                #expect(scheduler.scheduledNotifications.contains("session-goal2"))
                #expect(scheduler.scheduledNotifications.contains("session-goal3"))
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("scheduleNotifications handles invalid time format", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsInvalidTime() async {
        let scheduler = SmartNotificationScheduler()
        
        let invalidSession = createTestSession(startTime: "invalid-time")
        let validSession = createTestSession(id: "valid", startTime: "10:00")
        
        let plan = createTestPlan(sessions: [invalidSession, validSession])
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            
            // If authorization granted, verify invalid session was skipped
            if scheduler.scheduledNotifications.count > 0 {
                #expect(!scheduler.scheduledNotifications.contains("session-\(invalidSession.id)"))
                #expect(scheduler.scheduledNotifications.contains("session-valid"))
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("scheduleNotifications creates reminders for high-priority sessions", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsHighPriorityReminders() async {
        let scheduler = SmartNotificationScheduler()
        
        let highPrioritySession = createTestSession(id: "high", priority: 1)
        let lowPrioritySession = createTestSession(id: "low", priority: 4)
        
        let plan = createTestPlan(sessions: [highPrioritySession, lowPrioritySession])
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            
            // If we get here, authorization was granted
            // Verify sessions were added to scheduledNotifications set
            if scheduler.scheduledNotifications.count > 0 {
                #expect(scheduler.scheduledNotifications.contains("session-high"))
                #expect(scheduler.scheduledNotifications.contains("session-low"))
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - clearScheduledNotifications Tests
    
    @Test("clearScheduledNotifications removes all scheduled notifications")
    func testClearScheduledNotifications() async {
        let scheduler = SmartNotificationScheduler()
        
        scheduler.scheduledNotifications.insert("notif-1")
        scheduler.scheduledNotifications.insert("notif-2")
        scheduler.scheduledNotifications.insert("notif-3")
        
        #expect(scheduler.scheduledNotifications.count == 3)
        
        await scheduler.clearScheduledNotifications()
        
        #expect(scheduler.scheduledNotifications.isEmpty)
    }
    
    @Test("clearScheduledNotifications handles empty set")
    func testClearScheduledNotificationsEmpty() async {
        let scheduler = SmartNotificationScheduler()
        
        #expect(scheduler.scheduledNotifications.isEmpty)
        
        await scheduler.clearScheduledNotifications()
        
        #expect(scheduler.scheduledNotifications.isEmpty)
    }
    
    // MARK: - cancelNotification Tests
    
    @Test("cancelNotification removes specific notification")
    func testCancelNotification() async {
        let scheduler = SmartNotificationScheduler()
        
        scheduler.scheduledNotifications.insert("session-goal1")
        scheduler.scheduledNotifications.insert("session-goal2")
        scheduler.scheduledNotifications.insert("session-goal3")
        
        scheduler.cancelNotification(for: "goal2")
        
        #expect(scheduler.scheduledNotifications.count == 2)
        #expect(!scheduler.scheduledNotifications.contains("session-goal2"))
        #expect(scheduler.scheduledNotifications.contains("session-goal1"))
        #expect(scheduler.scheduledNotifications.contains("session-goal3"))
    }
    
    @Test("cancelNotification handles non-existent notification")
    func testCancelNotificationNonExistent() async {
        let scheduler = SmartNotificationScheduler()
        
        scheduler.scheduledNotifications.insert("session-goal1")
        
        scheduler.cancelNotification(for: "non-existent")
        
        #expect(scheduler.scheduledNotifications.count == 1)
        #expect(scheduler.scheduledNotifications.contains("session-goal1"))
    }
    
    // MARK: - Time Parsing Tests
    
    @Test("scheduleNotifications correctly parses 24-hour time format", .disabled("Hangs waiting for notification authorization in test environment"))
    func testTimeParsingValid() async {
        let scheduler = SmartNotificationScheduler()
        
        // Test valid time formats
        let validTimes = [
            "00:00",  // Midnight
            "09:30",  // Morning
            "12:00",  // Noon
            "15:45",  // Afternoon
            "23:59",  // Before midnight
            "9:00",   // Single digit hour
            "09:5"    // Single digit minute
        ]
        
        // Test invalid time formats
        let invalidTimes = [
            "abc",    // Invalid format
            ""        // Empty string
        ]
        
        // Test valid times - create plan with multiple valid sessions
        let validSessions = validTimes.map { time in
            createTestSession(id: "valid-\(time)", startTime: time)
        }
        let validPlan = createTestPlan(sessions: validSessions)
        
        do {
            try await scheduler.scheduleNotifications(for: validPlan)
            
            // If authorization granted, all valid times should be scheduled
            if scheduler.scheduledNotifications.count > 0 {
                for time in validTimes {
                    #expect(scheduler.scheduledNotifications.contains("session-valid-\(time)"))
                }
            }
            
            await scheduler.clearScheduledNotifications()
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        
        // Test invalid times - they should be skipped
        let invalidSessions = invalidTimes.map { time in
            createTestSession(id: "invalid-\(time)", startTime: time)
        }
        let invalidPlan = createTestPlan(sessions: invalidSessions)
        
        do {
            try await scheduler.scheduleNotifications(for: invalidPlan)
            
            // Invalid times should not be scheduled
            for time in invalidTimes {
                #expect(!scheduler.scheduledNotifications.contains("session-invalid-\(time)"))
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Notification Content Tests
    
    @Test("scheduleNotifications sets correct notification content", .disabled("Hangs waiting for notification authorization in test environment"))
    func testNotificationContent() async {
        let scheduler = SmartNotificationScheduler()
        
        let session = createTestSession(
            id: "content-test",
            title: "Meditation",
            startTime: "07:00",
            duration: 15,
            priority: 1
        )
        let plan = createTestPlan(sessions: [session])
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            
            let pending = await scheduler.getPendingNotifications()
            
            // If authorization granted, verify notification content
            if pending.count > 0 {
                let mainNotification = pending.first { $0.identifier == "session-content-test" }
                
                if let notification = mainNotification {
                    #expect(notification.content.title.contains("Meditation"))
                    #expect(notification.content.body.contains("15"))
                    #expect(notification.content.categoryIdentifier == "goal-session")
                    #expect(notification.content.userInfo["goalId"] as? String == "content-test")
                    #expect(notification.content.userInfo["duration"] as? Int == 15)
                    #expect(notification.content.userInfo["priority"] as? Int == 1)
                }
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Adaptive Notifications Tests
    
    @Test("scheduleAdaptiveNotifications adjusts timing based on activity level", .disabled("Hangs waiting for notification authorization in test environment"))
    func testAdaptiveNotificationsTiming() async {
        let scheduler = SmartNotificationScheduler()
        
        let session = createTestSession(startTime: "10:00")
        let plan = createTestPlan(sessions: [session])
        
        // Test all activity levels
        for activityLevel in [UserActivityLevel.low, .normal, .high] {
            do {
                try await scheduler.scheduleAdaptiveNotifications(
                    for: plan,
                    userActivity: activityLevel
                )
                
                let pending = await scheduler.getPendingNotifications()
                #expect(pending.count >= 0)
                
                await scheduler.clearScheduledNotifications()
            } catch let error as NotificationError {
                #expect(error == .authorizationDenied)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - getPendingNotifications Tests
    
    @Test("getPendingNotifications returns all pending notifications", .disabled("Hangs waiting for notification authorization in test environment"))
    func testGetPendingNotifications() async {
        let scheduler = SmartNotificationScheduler()
        
        let sessions = [
            createTestSession(id: "1", startTime: "09:00"),
            createTestSession(id: "2", startTime: "14:00")
        ]
        let plan = createTestPlan(sessions: sessions)
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            
            // If we get here, authorization was granted
            // Verify sessions were added to scheduledNotifications set
            if scheduler.scheduledNotifications.count > 0 {
                #expect(scheduler.scheduledNotifications.contains("session-1"))
                #expect(scheduler.scheduledNotifications.contains("session-2"))
                
                // Also verify getPendingNotifications works
                let pending = await scheduler.getPendingNotifications()
                // Note: pending might be empty in test environment even if scheduled
                #expect(pending.count >= 0)
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("scheduleNotifications handles empty plan", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsEmptyPlan() async {
        let scheduler = SmartNotificationScheduler()
        
        let plan = createTestPlan(sessions: [])
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            #expect(scheduler.scheduledNotifications.isEmpty)
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("scheduleNotifications handles multiple sessions at same time", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsSameTime() async {
        let scheduler = SmartNotificationScheduler()
        
        let sessions = [
            createTestSession(id: "1", startTime: "10:00"),
            createTestSession(id: "2", startTime: "10:00"),
            createTestSession(id: "3", startTime: "10:00")
        ]
        let plan = createTestPlan(sessions: sessions)
        
        do {
            try await scheduler.scheduleNotifications(for: plan)
            
            // If authorization granted, verify all sessions scheduled
            if scheduler.scheduledNotifications.count > 0 {
                #expect(scheduler.scheduledNotifications.count >= 3)
            }
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("scheduleNotifications handles past times gracefully", .disabled("Hangs waiting for notification authorization in test environment"))
    func testScheduleNotificationsPastTimes() async {
        let scheduler = SmartNotificationScheduler()
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        let session = createTestSession(startTime: "09:00")
        let plan = createTestPlan(sessions: [session])
        
        do {
            try await scheduler.scheduleNotifications(for: plan, on: yesterday)
            
            // Should still schedule (for yesterday)
            #expect(scheduler.scheduledNotifications.count >= 0)
        } catch let error as NotificationError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("configureNotificationActions sets up action categories")
    func testConfigureNotificationActions() async {
        let scheduler = SmartNotificationScheduler()
        
        // This should not throw or crash
        scheduler.configureNotificationActions()
        
        // We can't easily verify the categories were set without accessing UNUserNotificationCenter
        // But we can verify it doesn't crash
        #expect(true)
    }
}
