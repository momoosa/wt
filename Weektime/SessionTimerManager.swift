//
//  SessionTimerManager.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 22/01/2026.
//

import SwiftUI
import SwiftData
import WeektimeKit

/// Manages timer state and historical session creation for goal sessions
@Observable
public final class SessionTimerManager {
    /// The currently active session being timed
    public private(set) var activeSession: ActiveSessionDetails?
    
    private let goalStore: GoalStore
    
    // MARK: - UserDefaults Keys for Timer Persistence
    private let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
    private let activeSessionStartDateKey = "ActiveSessionStartDateV1"
    private let activeSessionIDKey = "ActiveSessionIDV1"
    
    public init(goalStore: GoalStore) {
        self.goalStore = goalStore
    }
    
    // MARK: - Timer Control
    
    /// Starts or stops the timer for a given session
    public func toggleTimer(for session: GoalSession, in day: Day) {
        if let activeSession, activeSession.id == session.id {
            // Stop the timer
            stopTimer(for: session, in: day)
        } else {
            // Start the timer
            startTimer(for: session)
        }
    }
    
    /// Starts a timer for the given session
    public func startTimer(for session: GoalSession) {
        // Stop any existing timer
        if let existingSession = activeSession {
            existingSession.stopUITimer()
        }
        
        // Create new active session
        let newActiveSession = ActiveSessionDetails(
            id: session.id,
            startDate: .now,
            elapsedTime: session.elapsedTime,
            dailyTarget: session.dailyTarget
        ) {
            // Callback when target is reached
            self.onTargetReached(for: session)
        }
        
        activeSession = newActiveSession
        saveTimerState()
        newActiveSession.startUITimer()
        
        #if os(iOS)
        // Success haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Stops the timer and creates a historical session
    public func stopTimer(for session: GoalSession, in day: Day) {
        guard let activeSession, activeSession.id == session.id else { return }
        
        // Save the session to create a historical entry
        goalStore.save(
            session: session,
            in: day,
            startDate: activeSession.startDate,
            endDate: .now
        )
        
        // Stop and clear the active session
        activeSession.stopUITimer()
        self.activeSession = nil
        saveTimerState()
        
        #if os(iOS)
        // Medium impact haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    /// Gets the timer text for display
    public func timerText(for session: GoalSession) -> String? {
        guard let activeSession, activeSession.id == session.id else {
            return nil
        }
        return activeSession.timerText()
    }
    
    /// Checks if the given session is currently active
    public func isActive(_ session: GoalSession) -> Bool {
        return activeSession?.id == session.id
    }
    
    // MARK: - Timer State Persistence
    
    /// Saves the current timer state to UserDefaults
    private func saveTimerState() {
        if let activeSession {
            UserDefaults.standard.set(activeSession.id.uuidString, forKey: activeSessionIDKey)
            UserDefaults.standard.set(activeSession.startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            UserDefaults.standard.set(activeSession.elapsedTime, forKey: activeSessionElapsedTimeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeSessionStartDateKey)
            UserDefaults.standard.removeObject(forKey: activeSessionIDKey)
            UserDefaults.standard.removeObject(forKey: activeSessionElapsedTimeKey)
        }
    }
    
    /// Loads the timer state from UserDefaults on app launch
    public func loadTimerState(sessions: [GoalSession]) {
        guard let idString = UserDefaults.standard.string(forKey: activeSessionIDKey),
              let uuid = UUID(uuidString: idString) else {
            return
        }
        
        let timeInterval = UserDefaults.standard.double(forKey: activeSessionStartDateKey)
        let elapsed = UserDefaults.standard.double(forKey: activeSessionElapsedTimeKey)
        
        // Find the session to get the daily target
        guard let session = sessions.first(where: { $0.id == uuid }) else {
            // Session no longer exists, clear state
            saveTimerState()
            return
        }
        
        let startDate = Date(timeIntervalSince1970: timeInterval)
        
        // Recreate the active session
        let restoredSession = ActiveSessionDetails(
            id: uuid,
            startDate: startDate,
            elapsedTime: elapsed,
            dailyTarget: session.dailyTarget
        ) {
            self.onTargetReached(for: session)
        }
        
        activeSession = restoredSession
        restoredSession.startUITimer()
    }
    
    // MARK: - Session Actions
    
    /// Marks a goal as done by creating a historical session to meet the daily target
    public func markGoalAsDone(session: GoalSession, day: Day, context: ModelContext) {
        // Calculate how much time is needed to meet the daily target
        let currentElapsed = session.elapsedTime
        let timeNeeded = session.dailyTarget - currentElapsed
        
        // Only add a historical session if there's time remaining to meet target
        if timeNeeded > 0 {
            let now = Date()
            let historicalSession = HistoricalSession(
                title: session.goal.title,
                start: now,
                end: now.addingTimeInterval(timeNeeded),
                healthKitType: nil,
                needsHealthKitRecord: false
            )
            historicalSession.goalIDs = [session.goal.id.uuidString]
            
            day.add(historicalSession: historicalSession)
            context.insert(historicalSession)
        }
        
        // Mark all checklist items as complete
        for item in session.checklist {
            item.isCompleted = true
        }
        
        // Save context
        try? context.save()
    }
    
    // MARK: - Private Helpers
    
    private func onTargetReached(for session: GoalSession) {
        // Handle target reached event (e.g., send notification)
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        // Could also schedule a notification here
        print("🎯 Target reached for session: \(session.title)")
    }
}
