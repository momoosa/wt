//
//  SessionTimerManager.swift
//  MomentumKit
//
//  Created by Mo Moosa on 22/01/2026.
//

import SwiftUI
import SwiftData
import MomentumKit
import Foundation
import AVFoundation

#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Manages timer state and historical session creation for goal sessions
@Observable
public final class SessionTimerManager {
    /// The currently active session being timed
    public private(set) var activeSession: ActiveSessionDetails?
    
    /// Callback when external changes are detected (e.g., widget stopped the timer)
    public var onExternalChange: (() -> Void)?
    
    private let goalStore: GoalStore
    private let healthKitManager = HealthKitManager()
    private var userDefaultsObserver: NSObjectProtocol?
    
    #if canImport(ActivityKit)
    private var liveActivity: Activity<MomentumWidgetAttributes>?
    private var liveActivityUpdateCounter: Int = 0
    #endif
    
    // MARK: - UserDefaults Keys for Timer Persistence
    private let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
    private let activeSessionStartDateKey = "ActiveSessionStartDateV1"
    private let activeSessionIDKey = "ActiveSessionIDV1"
    
    // App Group identifier for sharing data with widgets
    private let appGroupIdentifier = "group.com.moosa.ios.momentum"
    
    // Shared UserDefaults for widget communication
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    public init(goalStore: GoalStore) {
        self.goalStore = goalStore
        setupUserDefaultsObservation()
    }
    
    deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - UserDefaults Observation
    
    /// Sets up observation of UserDefaults changes from widgets
    private func setupUserDefaultsObservation() {
        // UserDefaults.didChangeNotification doesn't work across processes
        // Instead, we'll check for changes when the app becomes active
        #if os(iOS)
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkForExternalChanges()
        }
        #endif
    }
    
    /// Checks if timer state was changed externally (e.g., by widget) and syncs
    public func checkForExternalChanges() {
        guard let defaults = sharedDefaults else { return }
        
        let storedSessionID = defaults.string(forKey: activeSessionIDKey)
        let currentSessionID = activeSession?.id.uuidString
        
        // If states don't match, something changed externally
        if storedSessionID != currentSessionID {
            print("🔄 SessionTimerManager: Detected external state change")
            print("   Current: \(currentSessionID ?? "none"), Stored: \(storedSessionID ?? "none")")
            
            // Stop current timer if we have one but shouldn't
            if let activeSession, storedSessionID == nil {
                print("   → Stopping timer (was stopped externally)")
                activeSession.stopUITimer()
                self.activeSession = nil
            }
            // Or if the session ID changed
            else if let activeSession, let storedID = storedSessionID, storedID != activeSession.id.uuidString {
                print("   → Stopping timer (different session started externally)")
                activeSession.stopUITimer()
                self.activeSession = nil
            }
            
            // Notify that external change occurred so UI can refresh
            DispatchQueue.main.async {
                self.onExternalChange?()
            }
        }
    }
    
    // MARK: - Timer Control
    
    /// Starts or stops the timer for a given session
    public func toggleTimer(for session: GoalSession, in day: Day) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let activeSession, activeSession.id == session.id {
                // Stop the timer
                stopTimer(for: session, in: day)
            } else {
                // Start the timer
                startTimer(for: session)
            }
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
        
        // Wire up the onTick callback to update Live Activity
        newActiveSession.onTick = { [weak self] in
            self?.updateFromActiveSession()
        }
        
        newActiveSession.startUITimer()
        
        // Start Live Activity
        startLiveActivity(for: session, activeSession: newActiveSession)
        
        // Send start notification if enabled
        if session.goal.scheduleNotificationsEnabled {
            Task { @MainActor in
                let notificationManager = GoalNotificationManager()
                await notificationManager.sendSessionStartNotification(for: session.goal)
            }
        }
        
        #if os(iOS)
        // Success haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Stops the timer and creates a historical session
    public func stopTimer(for session: GoalSession, in day: Day) {
        guard let activeSession, activeSession.id == session.id else { return }
        
        let startDate = activeSession.startDate
        let endDate = Date.now
        
        // Save the session to create a historical entry
        let historicalSession = goalStore.save(
            session: session,
            in: day,
            startDate: startDate,
            endDate: endDate
        )
        
        // Write to HealthKit if the goal has a writable metric
        if let metric = session.goal.healthKitMetric,
           metric.supportsWrite,
           session.goal.healthKitSyncEnabled,
           let historicalSession = historicalSession {
            Task { @MainActor in
                do {
                    let healthKitID = try await healthKitManager.writeSession(
                        metric: metric,
                        startDate: startDate,
                        endDate: endDate
                    )
                    
                    // Store the HealthKit ID so we know this came from us
                    historicalSession.setHealthKitType(metric.rawValue)
                    historicalSession.needsHealthKitRecord = false
                    
                    print("✅ Wrote session to HealthKit: \(metric.displayName)")
                } catch {
                    print("❌ Failed to write session to HealthKit: \(error)")
                }
            }
        }
        
        // Stop and clear the active session
        activeSession.stopUITimer()
        self.activeSession = nil
        saveTimerState()
        
        // End Live Activity
        endLiveActivity()
        
        #if os(iOS)
        // Play completion sound
        playCompletionSound()
        
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
        guard let defaults = sharedDefaults else {
            print("⚠️ SessionTimerManager: Failed to access shared UserDefaults")
            return
        }
        
        if let activeSession {
            defaults.set(activeSession.id.uuidString, forKey: activeSessionIDKey)
            defaults.set(activeSession.startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            defaults.set(activeSession.elapsedTime, forKey: activeSessionElapsedTimeKey)
        } else {
            defaults.removeObject(forKey: activeSessionStartDateKey)
            defaults.removeObject(forKey: activeSessionIDKey)
            defaults.removeObject(forKey: activeSessionElapsedTimeKey)
        }
        
        // Force synchronization of UserDefaults
        defaults.synchronize()
        
        // Reload widgets when timer state changes
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    /// Loads the timer state from UserDefaults on app launch
    public func loadTimerState(sessions: [GoalSession]) {
        guard let defaults = sharedDefaults,
              let idString = defaults.string(forKey: activeSessionIDKey),
              let uuid = UUID(uuidString: idString) else {
            return
        }
        
        let timeInterval = defaults.double(forKey: activeSessionStartDateKey)
        let elapsed = defaults.double(forKey: activeSessionElapsedTimeKey)
        
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
        
        // Wire up the onTick callback to update Live Activity
        restoredSession.onTick = { [weak self] in
            self?.updateFromActiveSession()
        }
        
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
        
        // Send completion notification
        let totalElapsed = session.elapsedTime + timeNeeded
        Task { @MainActor in
            let notificationManager = GoalNotificationManager()
            await notificationManager.sendCompletionNotification(
                for: session.goal,
                elapsedTime: totalElapsed
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func onTargetReached(for session: GoalSession) {
        // Handle target reached event (e.g., send notification)
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        // Send completion notification if enabled
        Task { @MainActor in
            let notificationManager = GoalNotificationManager()
            await notificationManager.sendCompletionNotification(
                for: session.goal,
                elapsedTime: session.elapsedTime
            )
        }
        print("🎯 Target reached for session: \(session.title)")
    }
    
    // MARK: - Live Activity Management
    
    #if canImport(ActivityKit)
    private func startLiveActivity(for session: GoalSession, activeSession: ActiveSessionDetails) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities are not enabled")
            return
        }
        
        // End any existing activity
        endLiveActivity()
        
        let attributes = MomentumWidgetAttributes(
            sessionID: session.id.uuidString,
            goalTitle: session.goal.title,
            dailyTarget: session.dailyTarget,
            themeLight: session.goal.primaryTag.theme.light.toHex(),
            themeDark: session.goal.primaryTag.theme.dark.toHex(),
            themeNeon: session.goal.primaryTag.theme.neon.toHex()
        )
        
        let contentState = MomentumWidgetAttributes.ContentState(
            elapsedTime: activeSession.elapsedTime,
            startDate: activeSession.startDate,
            isActive: true
        )
        
        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("✅ Live Activity started: \(session.goal.title)")
            
            // Set up observation of ActiveSessionDetails timer
            setupLiveActivityObservation()
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    private func setupLiveActivityObservation() {
        // Reset update counter
        liveActivityUpdateCounter = 0
        
        // The ActiveSessionDetails timer already fires every second
        // We'll update Live Activity every 5 ticks (5 seconds)
        // This happens automatically through observation in updateFromActiveSession()
    }
    
    /// Call this method from the ActiveSessionDetails timer callback
    public func updateFromActiveSession() {
        guard let activeSession = activeSession else { 
            print("⚠️ updateFromActiveSession called but no active session")
            return 
        }
        
        #if canImport(ActivityKit)
        // Update Live Activity every second for responsive updates
        updateLiveActivity(
            elapsedTime: activeSession.elapsedTime,
            startDate: activeSession.startDate,
            isActive: true
        )
        print("🔄 Updated Live Activity: \(activeSession.elapsedTime)s")
        #endif
    }
    
    private func updateLiveActivity(elapsedTime: TimeInterval, startDate: Date, isActive: Bool) {
        guard let activity = liveActivity else { return }
        
        Task {
            let contentState = MomentumWidgetAttributes.ContentState(
                elapsedTime: elapsedTime,
                startDate: startDate,
                isActive: isActive
            )
            
            // Set staleDate to 1 second in the future to encourage frequent updates
            let staleDate = Date.now.addingTimeInterval(1)
            await activity.update(.init(state: contentState, staleDate: staleDate))
        }
    }
    
    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        
        // Reset update counter
        liveActivityUpdateCounter = 0
        
        Task {
            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            liveActivity = nil
            print("✅ Live Activity ended")
        }
    }
    #endif
    
    // MARK: - Sound Effects
    
    #if os(iOS)
    /// Plays a completion sound when a session ends
    private func playCompletionSound() {
        // Use system sound for session completion
        // You can replace this with a custom sound file by adding it to your project
        // and using: AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // For a custom sound file, use this approach:
        // if let soundURL = Bundle.main.url(forResource: "completion", withExtension: "mp3") {
        //     var soundID: SystemSoundID = 0
        //     AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        //     AudioServicesPlaySystemSound(soundID)
        // }
        
        // Using system sound for now (Glass tone)
        AudioServicesPlaySystemSound(1057)
    }
    #endif
}

// MARK: - Color Extension

extension Color {
    func toHex() -> String {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = components[0]
        let g = components.count > 1 ? components[1] : r
        let b = components.count > 2 ? components[2] : r
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
        #else
        return "#000000"
        #endif
    }
}
