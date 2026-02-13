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
    private let modelContext: ModelContext
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
    
    public init(goalStore: GoalStore, modelContext: ModelContext) {
        self.goalStore = goalStore
        self.modelContext = modelContext
        setupUserDefaultsObservation()
        setupExternalChangeNotification()
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
    
    /// Sets up observation for external change notifications from intents
    private func setupExternalChangeNotification() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SessionTimerExternalChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📬 Received external change notification from intent")
            self?.checkForExternalChanges()
        }
    }
    
    /// Handles a session that was stopped externally (from widget/Live Activity)
    @MainActor
    private func handleStoppedSession(sessionID: String) async {
        print("🔍 handleStoppedSession: Called for session \(sessionID)")
        
        guard let defaults = sharedDefaults else {
            print("❌ handleStoppedSession: No shared defaults")
            return
        }
        
        // Get the elapsed time that was accumulated
        let elapsedTime = defaults.double(forKey: activeSessionElapsedTimeKey)
        print("🔍 handleStoppedSession: Elapsed time = \(elapsedTime)s")
        
        guard elapsedTime > 0 else {
            print("⚠️ SessionTimerManager: No elapsed time for stopped session")
            defaults.removeObject(forKey: activeSessionElapsedTimeKey)
            return
        }
        
        // Find the session in the data store
        guard let sessionUUID = UUID(uuidString: sessionID) else {
            print("⚠️ SessionTimerManager: Invalid session ID")
            return
        }
        
        let context = modelContext
        let descriptor = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.id == sessionUUID }
        )
        
        // Fetch the session - if it doesn't exist, the goal was likely deleted (cascade)
        guard let session = try? context.fetch(descriptor).first else {
            print("⚠️ SessionTimerManager: Session not found for ID \(sessionUUID) - goal may have been deleted")
            defaults.removeObject(forKey: activeSessionElapsedTimeKey)
            defaults.removeObject(forKey: "StoppedSessionIDV1")
            defaults.synchronize()
            return
        }
        
        // Use the session's title (which is cached) instead of accessing session.goal.title
        // This avoids potential crashes if the goal was deleted
        let sessionTitle = session.title
        
        // We need the goal ID to create the historical session
        // To avoid crashes from accessing deleted goals, we'll fetch the goal separately
        let goalDescriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { goal in
                goal.goalSessions.contains { $0.id == sessionUUID }
            }
        )
        
        guard let goal = try? context.fetch(goalDescriptor).first else {
            print("⚠️ SessionTimerManager: Goal was deleted, cannot create historical session")
            defaults.removeObject(forKey: activeSessionElapsedTimeKey)
            defaults.removeObject(forKey: "StoppedSessionIDV1")
            defaults.synchronize()
            return
        }
        
        let goalID = goal.id.uuidString
        
        print("🔍 handleStoppedSession: Found session for goal '\(sessionTitle)'")
        
        // Create historical session from accumulated time
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-elapsedTime)
        let historicalSession = HistoricalSession(
            title: sessionTitle,
            start: startDate,
            end: endDate,
            healthKitType: nil,
            needsHealthKitRecord: false
        )
        historicalSession.goalIDs = [goalID]
        
        print("🔍 handleStoppedSession: Creating historical session from \(startDate) to \(endDate)")
        
        session.day.add(historicalSession: historicalSession)
        context.insert(historicalSession)
        
        // Clear elapsed time and stopped flag
        defaults.removeObject(forKey: activeSessionElapsedTimeKey)
        defaults.removeObject(forKey: "StoppedSessionIDV1")
        defaults.synchronize()
        
        do {
            try context.save()
            print("✅ SessionTimerManager: Created historical session for stopped session (elapsed: \(elapsedTime)s)")
        } catch {
            print("❌ SessionTimerManager: Failed to save historical session: \(error)")
        }
    }
    
    /// Syncs a session started from the widget to the main app
    @MainActor
    private func syncExternalSessionToApp(sessionID: String) async {
        print("🔄 syncExternalSessionToApp: Syncing session \(sessionID) from widget to app")
        
        guard let defaults = sharedDefaults else {
            print("❌ syncExternalSessionToApp: No shared defaults")
            return
        }
        
        // Find the session in the model context
        guard let sessionUUID = UUID(uuidString: sessionID) else {
            print("❌ syncExternalSessionToApp: Invalid session UUID")
            return
        }
        
        let fetchDescriptor = FetchDescriptor<GoalSession>(
            predicate: #Predicate { $0.id == sessionUUID }
        )
        
        guard let session = try? modelContext.fetch(fetchDescriptor).first else {
            print("❌ syncExternalSessionToApp: Could not find session")
            return
        }
        
        // Get elapsed time and start date from UserDefaults
        let elapsedTime = defaults.double(forKey: activeSessionElapsedTimeKey)
        let startDateInterval = defaults.double(forKey: activeSessionStartDateKey)
        let startDate = startDateInterval > 0 ? Date(timeIntervalSince1970: startDateInterval) : Date()
        
        print("🔍 syncExternalSessionToApp: Creating ActiveSessionDetails with elapsed=\(elapsedTime)s, start=\(startDate)")
        
        // Create ActiveSessionDetails
        let newActiveSession = ActiveSessionDetails(
            id: session.id,
            startDate: startDate,
            elapsedTime: elapsedTime,
            dailyTarget: session.dailyTarget
        ) {
            // Callback when target is reached
            self.onTargetReached(for: session)
        }
        
        activeSession = newActiveSession
        
        // Wire up the onTick callback to update Live Activity
        newActiveSession.onTick = { [weak self] in
            self?.updateFromActiveSession()
        }
        
        newActiveSession.startUITimer()
        
        // Start Live Activity (widget extensions cannot create Live Activities, only the main app can)
        #if canImport(ActivityKit)
        print("🎬 syncExternalSessionToApp: Creating Live Activity from main app")
        startLiveActivity(for: session, activeSession: newActiveSession)
        
        // Clear the flag now that we've created the Live Activity
        defaults.removeObject(forKey: "ShouldStartLiveActivity")
        defaults.synchronize()
        #else
        startLiveActivity(for: session, activeSession: newActiveSession)
        #endif
        
        print("✅ syncExternalSessionToApp: Session synced successfully")
    }
    
    /// Checks if timer state was changed externally (e.g., by widget) and syncs
    public func checkForExternalChanges() {
        print("🔄 checkForExternalChanges: Called")
        
        guard let defaults = sharedDefaults else {
            print("❌ checkForExternalChanges: No shared defaults")
            return
        }
        
        let storedSessionID = defaults.string(forKey: activeSessionIDKey)
        let pausedSessionID = defaults.string(forKey: "PausedSessionIDV1")
        let stoppedSessionID = defaults.string(forKey: "StoppedSessionIDV1")
        let currentSessionID = activeSession?.id.uuidString
        
        print("🔍 checkForExternalChanges: stored=\(storedSessionID ?? "nil"), paused=\(pausedSessionID ?? "nil"), stopped=\(stoppedSessionID ?? "nil"), current=\(currentSessionID ?? "nil")")
        
        // Check if a session was stopped externally and needs to be saved
        if let stoppedSessionID = stoppedSessionID {
            print("🔄 SessionTimerManager: Found stopped session \(stoppedSessionID), creating historical session")
            Task { @MainActor in
                await self.handleStoppedSession(sessionID: stoppedSessionID)
            }
            // Don't clear the flag here - let handleStoppedSession do it after creating the session
        }
        
        #if canImport(ActivityKit)
        // Check if Live Activity needs to be ended (stopped but not paused)
        if let activity = liveActivity {
            let activitySessionID = activity.attributes.sessionID
            // If the activity's session is not active and not paused, end it
            if storedSessionID != activitySessionID && pausedSessionID != activitySessionID {
                print("🔄 SessionTimerManager: Live Activity session is stopped, ending it")
                endLiveActivity()
            }
        }
        #endif
        
        // Check if a paused session was resumed (storedSessionID matches and pausedSessionID is cleared)
        if let activeSession, activeSession.isPaused {
            // If the session is marked as paused but storedSessionID now matches (resumed)
            if storedSessionID == activeSession.id.uuidString {
                print("🔄 SessionTimerManager: Session resumed")
                activeSession.isPaused = false
                activeSession.startUITimer()
                
                // Notify that external change occurred so UI can refresh
                DispatchQueue.main.async {
                    self.onExternalChange?()
                }
            }
        }
        
        // If states don't match, something changed externally
        if storedSessionID != currentSessionID {
            print("🔄 SessionTimerManager: Detected external state change")
            print("   Current: \(currentSessionID ?? "none"), Stored: \(storedSessionID ?? "none"), Paused: \(pausedSessionID ?? "none")")
            
            // Stop current timer if we have one but it's not active (and not paused)
            if let activeSession, storedSessionID == nil {
                // Check if it's paused instead of stopped
                if pausedSessionID == activeSession.id.uuidString {
                    print("   → Timer is paused (keeping session visible)")
                    activeSession.stopUITimer()
                    activeSession.isPaused = true
                    // Keep the session in activeSession so it remains visible in UI
                    // Don't end Live Activity - it's just paused
                    // The Live Activity will continue showing the paused state
                } else {
                    print("   → Stopping timer (was stopped externally)")
                    activeSession.stopUITimer()
                    self.activeSession = nil
                    // Live Activity already ended above if needed
                }
            }
            // Or if the session ID changed
            else if let activeSession, let storedID = storedSessionID, storedID != activeSession.id.uuidString {
                print("   → Stopping timer (different session started externally)")
                activeSession.stopUITimer()
                self.activeSession = nil
            }
            // New session started from widget (no current session, but stored session exists)
            else if activeSession == nil, let storedID = storedSessionID {
                print("   → New session started from widget, syncing to app")
                Task { @MainActor in
                    await self.syncExternalSessionToApp(sessionID: storedID)
                }
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
                // Check if paused - if so, resume
                if activeSession.isPaused {
                    resumeTimer()
                } else {
                    // Stop the timer
                    stopTimer(for: session, in: day)
                }
            } else {
                // Start the timer
                startTimer(for: session)
            }
        }
    }
    
    /// Resumes a paused timer
    public func resumeTimer() {
        guard let activeSession, activeSession.isPaused else { return }
        
        print("▶️ Resuming paused session")
        
        // Clear paused flag
        activeSession.isPaused = false
        
        // Restart the UI timer
        activeSession.startUITimer()
        
        // Update UserDefaults to mark as active
        guard let defaults = sharedDefaults else { return }
        defaults.set(activeSession.id.uuidString, forKey: activeSessionIDKey)
        defaults.removeObject(forKey: "PausedSessionIDV1")
        defaults.synchronize()
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        #if os(iOS)
        // Success haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
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
    
    /// Clears the active session without creating a historical entry (for forced cleanup)
    public func clearActiveSession() {
        if let activeSession {
            activeSession.stopUITimer()
            self.activeSession = nil
            saveTimerState()
            endLiveActivity()
        }
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
                title: session.title,
                start: now,
                end: now.addingTimeInterval(timeNeeded),
                healthKitType: nil,
                needsHealthKitRecord: false
            )
            historicalSession.goalIDs = [session.goalID]

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
        if session.goal.completionNotificationsEnabled {
            Task { @MainActor in
                let notificationManager = GoalNotificationManager()
                await notificationManager.sendCompletionNotification(
                    for: session.goal,
                    elapsedTime: totalElapsed
                )
            }
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
        if session.goal.completionNotificationsEnabled {
            Task { @MainActor in
                let notificationManager = GoalNotificationManager()
                await notificationManager.sendCompletionNotification(
                    for: session.goal,
                    elapsedTime: session.elapsedTime
                )
            }
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
        
        let theme = session.goal.primaryTag.theme
        let attributes = MomentumWidgetAttributes(
            sessionID: session.id.uuidString,
            dayID: session.day.id,
            goalTitle: session.title,
            dailyTarget: session.dailyTarget,
            themeLight: theme.light.toHex(),
            themeDark: theme.dark.toHex(),
            themeNeon: theme.neon.toHex()
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
            print("✅ Live Activity started: \(session.title)")
            
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
