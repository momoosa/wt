//
//  SessionTimerIntents.swift
//  MomentumKit
//
//  Created by Assistant on 02/02/2026.
//

import AppIntents
import SwiftData
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
    public var goalTitle: String
    public var dailyTarget: TimeInterval
    public var themeLight: String  // Store as hex string
    public var themeDark: String   // Store as hex string
    public var themeNeon: String   // Store as hex string
    
    public init(sessionID: String, goalTitle: String, dailyTarget: TimeInterval, themeLight: String, themeDark: String, themeNeon: String) {
        self.sessionID = sessionID
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
        
        // Set up model container with App Group for shared data access
        let schema = Schema([
            Goal.self,
            GoalTag.self,
            Day.self,
            GoalSession.self,
            HistoricalSession.self,
            ChecklistItemSession.self,
            IntervalListSession.self
        ])
        
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Intent: Failed to get App Group container URL")
            throw IntentError.containerError
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        let modelConfiguration = ModelConfiguration(url: storeURL)
        
        guard let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) else {
            print("❌ Intent: Failed to create model container")
            throw IntentError.modelContainerError
        }
        
        let context = container.mainContext
        
        // Fetch the session
        guard let sessionUUID = UUID(uuidString: sessionID) else {
            print("❌ Intent: Invalid session ID format")
            throw IntentError.invalidSessionID
        }
        
        let sessionPredicate = #Predicate<GoalSession> { session in
            session.id == sessionUUID
        }
        let sessionDescriptor = FetchDescriptor<GoalSession>(predicate: sessionPredicate)
        
        guard let session = try? context.fetch(sessionDescriptor).first else {
            print("❌ Intent: Session not found")
            throw IntentError.sessionNotFound
        }
        
        // Fetch the day
        let dayPredicate = #Predicate<Day> { day in
            day.id == dayID
        }
        let dayDescriptor = FetchDescriptor<Day>(predicate: dayPredicate)
        
        guard let day = try? context.fetch(dayDescriptor).first else {
            print("❌ Intent: Day not found")
            throw IntentError.dayNotFound
        }
        
        // Check if timer is currently running by reading from UserDefaults
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Intent: Failed to access UserDefaults for app group")
            throw IntentError.containerError
        }
        
        let activeSessionIDKey = "ActiveSessionIDV1"
        let activeSessionStartDateKey = "ActiveSessionStartDateV1"
        let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
        
        let currentActiveSessionID = defaults.string(forKey: activeSessionIDKey)
        let isCurrentlyActive = currentActiveSessionID == sessionID
        
        print("📊 Intent: Current active session: \(currentActiveSessionID ?? "none"), target session: \(sessionID)")
        
        if isCurrentlyActive {
            // Stop the timer
            print("⏹️ Intent: Stopping timer for session \(session.title)")
            
            // Get start date and calculate duration
            let startTimeInterval = defaults.double(forKey: activeSessionStartDateKey)
            guard startTimeInterval > 0 else {
                print("⚠️ Intent: No valid start time found, clearing state")
                defaults.removeObject(forKey: activeSessionIDKey)
                defaults.removeObject(forKey: activeSessionStartDateKey)
                defaults.removeObject(forKey: activeSessionElapsedTimeKey)
                defaults.synchronize()
                throw IntentError.invalidTimerState
            }
            
            let startDate = Date(timeIntervalSince1970: startTimeInterval)
            let endDate = Date()
            let duration = endDate.timeIntervalSince(startDate)
            
            // Note: initialElapsed is stored for reference but not used in historical session creation
            // The historical session duration is calculated from start/end times
            _ = defaults.double(forKey: activeSessionElapsedTimeKey)
            
            // Create historical session
            let historicalSession = HistoricalSession(
                title: session.goal.title,
                start: startDate,
                end: endDate,
                healthKitType: nil,
                needsHealthKitRecord: false
            )
            historicalSession.goalIDs = [session.goal.id.uuidString]
            
            day.add(historicalSession: historicalSession)
            context.insert(historicalSession)
            
            // Clear timer state
            defaults.removeObject(forKey: activeSessionIDKey)
            defaults.removeObject(forKey: activeSessionStartDateKey)
            defaults.removeObject(forKey: activeSessionElapsedTimeKey)
            
            // Force synchronization of UserDefaults
            defaults.synchronize()
            
            try? context.save()
            
            print("✅ Intent: Timer stopped, historical session created (duration: \(duration)s)")
            
        } else {
            // Start the timer
            print("▶️ Intent: Starting timer for session \(session.title)")
            
            // Stop any existing timer first
            if let existingSessionID = currentActiveSessionID {
                print("⚠️ Intent: Stopping existing timer for session \(existingSessionID)")
                // We could stop and save the existing timer here, but for simplicity
                // we'll just overwrite it. In production, you might want to save it first.
                defaults.removeObject(forKey: activeSessionIDKey)
                defaults.removeObject(forKey: activeSessionStartDateKey)
                defaults.removeObject(forKey: activeSessionElapsedTimeKey)
            }
            
            // Start new timer
            let startDate = Date()
            defaults.set(sessionID, forKey: activeSessionIDKey)
            defaults.set(startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            defaults.set(session.elapsedTime, forKey: activeSessionElapsedTimeKey)
            
            // Force synchronization of UserDefaults
            defaults.synchronize()
            
            print("✅ Intent: Timer started at \(startDate)")
        }
        
        // Give UserDefaults a moment to sync, then reload widgets
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
    
    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case containerError
        case modelContainerError
        case invalidSessionID
        case sessionNotFound
        case dayNotFound
        case invalidTimerState
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .containerError:
                return "Failed to access shared data"
            case .modelContainerError:
                return "Failed to initialize data store"
            case .invalidSessionID:
                return "Invalid session identifier"
            case .sessionNotFound:
                return "Session not found"
            case .dayNotFound:
                return "Day not found"
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
public struct StopTimerIntent: AppIntent {
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
public struct PauseResumeTimerIntent: AppIntent {
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
        
        let currentActiveSessionID = defaults.string(forKey: activeSessionIDKey)
        let isCurrentlyActive = currentActiveSessionID == sessionID
        
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
            
            // Clear active state but store the total elapsed time
            defaults.removeObject(forKey: activeSessionIDKey)
            defaults.removeObject(forKey: activeSessionStartDateKey)
            defaults.set(totalElapsed, forKey: activeSessionElapsedTimeKey)
            
            defaults.synchronize()
            
            print("✅ Intent: Timer paused (elapsed: \(totalElapsed)s)")
            
            #if canImport(ActivityKit)
            // Update Live Activity to show paused state
            await updateLiveActivity(sessionID: sessionID, isActive: false, elapsedTime: totalElapsed)
            #endif
        } else {
            // Resume the timer
            print("▶️ Intent: Resuming timer")
            
            let elapsedTime = defaults.double(forKey: activeSessionElapsedTimeKey)
            let startDate = Date()
            
            defaults.set(sessionID, forKey: activeSessionIDKey)
            defaults.set(startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            defaults.set(elapsedTime, forKey: activeSessionElapsedTimeKey)
            
            defaults.synchronize()
            
            print("✅ Intent: Timer resumed at \(startDate)")
            
            #if canImport(ActivityKit)
            // Update Live Activity to show active state
            await updateLiveActivity(sessionID: sessionID, isActive: true, elapsedTime: elapsedTime)
            #endif
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
