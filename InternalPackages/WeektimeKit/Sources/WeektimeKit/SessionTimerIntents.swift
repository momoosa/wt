//
//  SessionTimerIntents.swift
//  MomentumKit
//
//  Created by Assistant on 02/02/2026.
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

// MARK: - Live Activity Attributes

public struct MomentumWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties
        public var elapsedTime: TimeInterval
        public var startDate: Date
        public var isActive: Bool
        
        public init(elapsedTime: TimeInterval, startDate: Date, isActive: Bool) {
            self.elapsedTime = elapsedTime
            self.startDate = startDate
            self.isActive = isActive
        }
    }

    // Fixed non-changing properties
    public var sessionID: String
    public var dayID: String
    public var goalTitle: String
    public var dailyTarget: TimeInterval
    public var themeLight: String  // Store as hex string
    public var themeDark: String   // Store as hex string
    public var themeNeon: String   // Store as hex string
    
    public init(sessionID: String, dayID: String, goalTitle: String, dailyTarget: TimeInterval, themeLight: String, themeDark: String, themeNeon: String) {
        self.sessionID = sessionID
        self.dayID = dayID
        self.goalTitle = goalTitle
        self.dailyTarget = dailyTarget
        self.themeLight = themeLight
        self.themeDark = themeDark
        self.themeNeon = themeNeon
    }
}
#endif

/// App Intent to toggle (start/stop) a timer for a goal session from widgets
public struct ToggleTimerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Timer"
    public static let description = IntentDescription("Start or stop tracking time for a goal")
    
    @Parameter(title: "Session ID")
    var sessionID: String
    
    @Parameter(title: "Day ID")
    var dayID: String
    
    public init() {}
    
    public init(sessionID: String, dayID: String) {
        self.sessionID = sessionID
        self.dayID = dayID
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        print("🎯 ToggleTimerIntent: Starting for session \(sessionID)")
        
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        // Check if timer is currently running by reading from UserDefaults
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Intent: Failed to access UserDefaults for app group")
            throw IntentError.containerError
        }
        
        let activeSessionIDKey = "ActiveSessionIDV1"
        let activeSessionStartDateKey = "ActiveSessionStartDateV1"
        let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
        let pausedSessionIDKey = "PausedSessionIDV1"
        
        let currentActiveSessionID = defaults.string(forKey: activeSessionIDKey)
        let pausedSessionID = defaults.string(forKey: pausedSessionIDKey)
        let isCurrentlyActive = currentActiveSessionID == sessionID
        let isCurrentlyPaused = pausedSessionID == sessionID
        
        print("📊 Intent: Current active session: \(currentActiveSessionID ?? "none"), paused: \(pausedSessionID ?? "none"), target: \(sessionID)")
        
        if isCurrentlyActive || isCurrentlyPaused {
            // Mark session as stopped - the app will handle creating the historical session
            print("⏹️ Intent: Marking session as stopped (app will create historical session)")
            
            // Get the current elapsed time before clearing anything
            let currentElapsed = defaults.double(forKey: activeSessionElapsedTimeKey)
            print("🔍 Intent: Current elapsed time in UserDefaults: \(currentElapsed)s")
            
            // If currently active (not paused), calculate and update the elapsed time
            if isCurrentlyActive {
                let startTimeInterval = defaults.double(forKey: activeSessionStartDateKey)
                if startTimeInterval > 0 {
                    let startDate = Date(timeIntervalSince1970: startTimeInterval)
                    let duration = Date().timeIntervalSince(startDate)
                    let totalElapsed = currentElapsed + duration
                    defaults.set(totalElapsed, forKey: activeSessionElapsedTimeKey)
                    print("🔍 Intent: Updated elapsed time to \(totalElapsed)s (was \(currentElapsed)s)")
                }
            }
            
            // Set a flag indicating the session should be stopped and saved
            defaults.set(sessionID, forKey: "StoppedSessionIDV1")
            
            // Clear timer state (including paused state)
            defaults.removeObject(forKey: activeSessionIDKey)
            defaults.removeObject(forKey: activeSessionStartDateKey)
            defaults.removeObject(forKey: pausedSessionIDKey)
            // Keep elapsed time so app can create historical session
            
            // Force synchronization of UserDefaults
            defaults.synchronize()
            
            print("✅ Intent: Session marked as stopped with elapsed time \(defaults.double(forKey: activeSessionElapsedTimeKey))s, app will finalize")
            
            // End Live Activity
            #if canImport(ActivityKit)
            await endLiveActivity(sessionID: sessionID)
            #endif
            
            // Notify the app to check for external changes
            NotificationCenter.default.post(name: NSNotification.Name("SessionTimerExternalChange"), object: nil)
            
        } else {
            // Start the timer
            print("▶️ Intent: Starting timer for session \(sessionID)")
            
            // Stop any existing timer first
            if let existingSessionID = currentActiveSessionID {
                print("⚠️ Intent: Stopping existing timer for session \(existingSessionID)")
                defaults.removeObject(forKey: activeSessionIDKey)
                defaults.removeObject(forKey: activeSessionStartDateKey)
                defaults.removeObject(forKey: activeSessionElapsedTimeKey)
            }
            
            // Start new timer - get elapsed time from UserDefaults or default to 0
            let elapsedTime = defaults.double(forKey: activeSessionElapsedTimeKey)
            let startDate = Date()
            defaults.set(sessionID, forKey: activeSessionIDKey)
            defaults.set(startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            defaults.set(elapsedTime, forKey: activeSessionElapsedTimeKey)
            
            // Force synchronization of UserDefaults
            defaults.synchronize()
            
            print("✅ Intent: Timer started at \(startDate)")
            
            // Start Live Activity (App Intents CAN create Live Activities)
            #if canImport(ActivityKit)
            await startLiveActivity(sessionID: sessionID, dayID: dayID, elapsedTime: elapsedTime, appGroupIdentifier: appGroupIdentifier)
            #endif
            
            // Notify the app (if it's running) to sync the session
            NotificationCenter.default.post(name: NSNotification.Name("SessionTimerExternalChange"), object: nil)
            
            print("🔔 Intent: Notified main app of timer start")
        }
        
        // Give UserDefaults a moment to sync, then reload widgets
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
    
    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case containerError
        case invalidTimerState
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .containerError:
                return "Failed to access shared data"
            case .invalidTimerState:
                return "Timer state is invalid"
            }
        }
    }

}

/// App Intent to start a timer for a goal session
public struct StartSessionTimerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Timer"
    public static let description = IntentDescription("Start tracking time for a goal")
    
    @Parameter(title: "Session ID")
    public var sessionID: String
    
    @Parameter(title: "Day ID")
    public var dayID: String
    
    public init() {}
    
    public init(sessionID: String, dayID: String) {
        self.sessionID = sessionID
        self.dayID = dayID
    }
    
    public func perform() async throws -> some IntentResult {
        // Delegate to ToggleTimerIntent
        let toggle = ToggleTimerIntent(sessionID: sessionID, dayID: dayID)
        return try await toggle.perform()
    }
}

/// App Intent to stop a timer for a goal session
public struct StopTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Stop Timer"
    public static let description = IntentDescription("Stop tracking time for a goal")
    
    @Parameter(title: "Session ID")
    public var sessionID: String
    
    @Parameter(title: "Day ID")
    public var dayID: String
    
    public init() {}
    
    public init(sessionID: String, dayID: String) {
        self.sessionID = sessionID
        self.dayID = dayID
    }
    
    public func perform() async throws -> some IntentResult {
        // Delegate to ToggleTimerIntent
        let toggle = ToggleTimerIntent(sessionID: sessionID, dayID: dayID)
        return try await toggle.perform()
    }
}

/// App Intent to pause/resume a timer for a goal session (for Live Activities)
public struct PauseResumeTimerIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pause/Resume Timer"
    public static let description = IntentDescription("Pause or resume tracking time for a goal")
    
    @Parameter(title: "Session ID")
    public var sessionID: String
    
    @Parameter(title: "Day ID")
    public var dayID: String
    
    public init() {}
    
    public init(sessionID: String, dayID: String) {
        self.sessionID = sessionID
        self.dayID = dayID
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        print("⏸️ PauseResumeTimerIntent: Starting for session \(sessionID)")
        
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Intent: Failed to access UserDefaults for app group")
            throw ToggleTimerIntent.IntentError.containerError
        }
        
        let activeSessionIDKey = "ActiveSessionIDV1"
        let activeSessionStartDateKey = "ActiveSessionStartDateV1"
        let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
        let pausedSessionIDKey = "PausedSessionIDV1"
        
        let currentActiveSessionID = defaults.string(forKey: activeSessionIDKey)
        let pausedSessionID = defaults.string(forKey: pausedSessionIDKey)
        let isCurrentlyActive = currentActiveSessionID == sessionID
        let isCurrentlyPaused = pausedSessionID == sessionID
        
        if isCurrentlyActive {
            // Pause the timer
            print("⏸️ Intent: Pausing timer")
            
            let startTimeInterval = defaults.double(forKey: activeSessionStartDateKey)
            guard startTimeInterval > 0 else {
                print("⚠️ Intent: No valid start time found")
                throw ToggleTimerIntent.IntentError.invalidTimerState
            }
            
            let startDate = Date(timeIntervalSince1970: startTimeInterval)
            let initialElapsed = defaults.double(forKey: activeSessionElapsedTimeKey)
            let duration = Date().timeIntervalSince(startDate)
            let totalElapsed = initialElapsed + duration
            
            // Mark as paused and keep the session ID
            defaults.set(sessionID, forKey: pausedSessionIDKey)
            defaults.removeObject(forKey: activeSessionIDKey)
            defaults.removeObject(forKey: activeSessionStartDateKey)
            defaults.set(totalElapsed, forKey: activeSessionElapsedTimeKey)
            
            defaults.synchronize()
            
            print("✅ Intent: Timer paused (elapsed: \(totalElapsed)s)")
            
            #if canImport(ActivityKit)
            // Update Live Activity to show paused state
            await updateLiveActivity(sessionID: sessionID, isActive: false, elapsedTime: totalElapsed)
            #endif
        } else if isCurrentlyPaused {
            // Resume the timer
            print("▶️ Intent: Resuming timer")
            
            let elapsedTime = defaults.double(forKey: activeSessionElapsedTimeKey)
            let startDate = Date()
            
            defaults.set(sessionID, forKey: activeSessionIDKey)
            defaults.set(startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            defaults.set(elapsedTime, forKey: activeSessionElapsedTimeKey)
            defaults.removeObject(forKey: pausedSessionIDKey)
            
            defaults.synchronize()
            
            print("✅ Intent: Timer resumed at \(startDate)")
            
            #if canImport(ActivityKit)
            // Update Live Activity to show active state
            await updateLiveActivity(sessionID: sessionID, isActive: true, elapsedTime: elapsedTime)
            #endif
        } else {
            print("⚠️ Intent: Session is neither active nor paused")
        }
        
        // Reload widgets
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
    
    #if canImport(ActivityKit)
    @MainActor
    private func updateLiveActivity(sessionID: String, isActive: Bool, elapsedTime: TimeInterval) async {
        let activities = Activity<MomentumWidgetAttributes>.activities
        for activity in activities {
            if activity.attributes.sessionID == sessionID {
                let updatedState = MomentumWidgetAttributes.ContentState(
                    elapsedTime: elapsedTime,
                    startDate: Date(),
                    isActive: isActive
                )
                await activity.update(using: updatedState)
                print("✅ Updated Live Activity state: isActive=\(isActive), elapsed=\(elapsedTime)")
            }
        }
    }
    #endif
}

// MARK: - ToggleTimerIntent Live Activity Helpers

extension ToggleTimerIntent {
    #if canImport(ActivityKit)
    /// Start a Live Activity for the session
    @MainActor
    fileprivate func startLiveActivity(sessionID: String, dayID: String, elapsedTime: TimeInterval, appGroupIdentifier: String) async {
        print("🎬 Intent: Starting Live Activity for session \(sessionID)")
        
        // First, end any existing activities to avoid duplicates
        let existingActivities = Activity<MomentumWidgetAttributes>.activities
        for activity in existingActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("🔚 Ended existing Live Activity: \(activity.id)")
        }
        
        // Fetch session data from SwiftData
        let schema = Schema([
            Goal.self,
            GoalTag.self,
            GoalSession.self,
            Day.self,
            HistoricalSession.self,
        ])
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Intent: Failed to get container URL for app group")
            return
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        
        guard let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(url: storeURL)]) else {
            print("❌ Intent: Failed to create model container for Live Activity")
            return
        }
        
        let context = container.mainContext
        
        // Fetch the session
        guard let sessionUUID = UUID(uuidString: sessionID) else {
            print("❌ Intent: Invalid session ID")
            return
        }
        
        let sessionPredicate = #Predicate<GoalSession> { session in
            session.id == sessionUUID
        }
        let sessionDescriptor = FetchDescriptor<GoalSession>(predicate: sessionPredicate)
        
        guard let session = try? context.fetch(sessionDescriptor).first else {
            print("❌ Intent: Failed to fetch session \(sessionID)")
            return
        }
        
        print("✅ Intent: Found session '\(session.title)'")
        
        // Create activity attributes
        let primaryTag = session.goal.primaryTag
        let theme = primaryTag.theme
        
        let attributes = MomentumWidgetAttributes(
            sessionID: sessionID,
            dayID: dayID,
            goalTitle: session.title,
            dailyTarget: session.dailyTarget,
            themeLight: "#\(theme.light.toHex() ?? "007AFF")",
            themeDark: "#\(theme.dark.toHex() ?? "0051D5")",
            themeNeon: "#\(theme.neon.toHex() ?? "00D4FF")"
        )
        
        let contentState = MomentumWidgetAttributes.ContentState(
            elapsedTime: elapsedTime,
            startDate: Date(),
            isActive: true
        )
        
        // Start the Live Activity
        do {
            let activity = try Activity<MomentumWidgetAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("✅ Intent: Started Live Activity \(activity.id)")
        } catch {
            print("❌ Intent: Failed to start Live Activity: \(error)")
        }
    }
    
    /// End the Live Activity for a session
    @MainActor
    fileprivate func endLiveActivity(sessionID: String) async {
        let activities = Activity<MomentumWidgetAttributes>.activities
        for activity in activities {
            if activity.attributes.sessionID == sessionID {
                await activity.end(nil, dismissalPolicy: .immediate)
                print("🔚 Intent: Ended Live Activity \(activity.id)")
            }
        }
    }
    #endif
}
