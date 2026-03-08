//
//  MomentumAppIntents.swift
//  Momentum
//
//  Created by Assistant on 07/03/2026.
//

import Foundation
import AppIntents
import MomentumKit
import SwiftData
import SwiftUI

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Start Goal Timer

struct StartGoalTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Goal Timer"
    static var description = IntentDescription("Start tracking time for a goal")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Goal")
    var goal: GoalEntity
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("🎯 StartGoalTimerIntent: Starting timer for goal \(goal.id)")
        
        // Access SwiftData directly using the app group
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        // Find the goal
        let goalDescriptor = FetchDescriptor<Goal>()
        let goals = try context.fetch(goalDescriptor)
        guard let selectedGoal = goals.first(where: { $0.id.uuidString == goal.id }) else {
            throw IntentError.goalNotFound
        }
        
        // Get or create today's session
        let calendar = Calendar.current
        let todayID = Date().yearMonthDayID(with: calendar)
        
        // Fetch or create today's day
        let dayDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate<Day> { $0.id == todayID }
        )
        
        let day: Day
        if let existingDay = try? context.fetch(dayDescriptor).first {
            day = existingDay
        } else {
            // Create new day
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            day = Day(start: startOfDay, end: endOfDay, calendar: calendar)
            context.insert(day)
            try context.save()
        }
        
        // Find or create session for this goal today
        let sessionDescriptor = FetchDescriptor<GoalSession>()
        let sessions = try context.fetch(sessionDescriptor)
        
        let session: GoalSession
        if let existingSession = sessions.first(where: { $0.goalID == selectedGoal.id.uuidString && $0.day?.id == todayID }) {
            session = existingSession
        } else {
            // Create new session
            session = GoalSession(title: selectedGoal.title, goal: selectedGoal, day: day)
            context.insert(session)
            try context.save()
        }
        
        print("✅ StartGoalTimerIntent: Found/created session \(session.id)")
        
        // Use UserDefaults to communicate with the app
        let appGroupIdentifier = "group.com.moosa.momentum.ios"
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ StartGoalTimerIntent: Failed to access UserDefaults")
            throw IntentError.sessionNotFound
        }
        
        let activeSessionIDKey = "ActiveSessionIDV1"
        let activeSessionStartDateKey = "ActiveSessionStartDateV1"
        let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
        
        // Stop any existing timer first
        if let existingSessionID = defaults.string(forKey: activeSessionIDKey) {
            print("⚠️ StartGoalTimerIntent: Stopping existing timer for session \(existingSessionID)")
            defaults.removeObject(forKey: activeSessionIDKey)
            defaults.removeObject(forKey: activeSessionStartDateKey)
            defaults.removeObject(forKey: activeSessionElapsedTimeKey)
        }
        
        // Start the new timer
        let startDate = Date()
        let sessionID = session.id.uuidString
        let elapsedTime = session.elapsedTime
        
        defaults.set(sessionID, forKey: activeSessionIDKey)
        defaults.set(startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
        defaults.set(elapsedTime, forKey: activeSessionElapsedTimeKey)
        defaults.synchronize()
        
        print("✅ StartGoalTimerIntent: Timer started at \(startDate)")
        
        // Notify the main app to sync the session
        NotificationCenter.default.post(name: NSNotification.Name("SessionTimerExternalChange"), object: nil)
        
        // Reload widgets
        #if canImport(WidgetKit)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        return .result(dialog: "Started timer for \(goal.title)")
    }
}

// MARK: - Stop Goal Timer

struct StopGoalTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Goal Timer"
    static var description = IntentDescription("Stop tracking time for the active goal")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // This intent stops the active timer from widgets/shortcuts
        // The actual timer state is managed in SessionTimerManager via UserDefaults
        
        return .result(dialog: IntentDialog("Timer stopped. Open Momentum to see your progress."))
    }
}

// MARK: - Get Today's Goals

struct GetTodaysGoalsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Goals"
    static var description = IntentDescription("Show goals scheduled for today")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())
        
        // Access SwiftData directly using the app group
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Goal>()
        
        let fetchedGoals = try context.fetch(descriptor)
        let allGoals = fetchedGoals.filter { $0.status == .active }
        
        // Debug: Log what we found
        print("📱 Siri Intent: Found \(fetchedGoals.count) total goals, \(allGoals.count) active")
        
        // If no active goals at all, return early
        if allGoals.isEmpty {
            return .result(dialog: "No active goals found") {
                TodaysGoalsView(goals: [])
            }
        }
        
        // Filter goals scheduled for today
        // If a goal has NO schedule set, it's available every day
        let todaysGoals = allGoals.filter { goal in
            let scheduledTimes = goal.timesForWeekday(todayWeekday)
            let hasSchedule = goal.hasSchedule
            
            print("📱 Goal '\(goal.title)': hasSchedule=\(hasSchedule), times for today=\(scheduledTimes.count)")
            
            // Show if: has schedule AND scheduled for today, OR no schedule (available anytime)
            return !hasSchedule || !scheduledTimes.isEmpty
        }
        
        print("📱 Final result: \(todaysGoals.count) goals for today")
        
        if todaysGoals.isEmpty {
            return .result(dialog: "No goals available for today (weekday \(todayWeekday))") {
                TodaysGoalsView(goals: [])
            }
        }
        
        let goalTitles = todaysGoals.map { $0.title }.joined(separator: ", ")
        let count = todaysGoals.count
        
        return .result(dialog: "You have \(count) goal\(count == 1 ? "" : "s") today: \(goalTitles)") {
            TodaysGoalsView(goals: todaysGoals.map { GoalSummary(from: $0, context: context) })
        }
    }
}

// MARK: - Get Weather-Based Recommendations

struct GetWeatherRecommendationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Weather-Based Recommendations"
    static var description = IntentDescription("Show goals that match current weather")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let weatherManager = WeatherManager.shared
        
        // Refresh weather
        weatherManager.refreshWeatherIfNeeded()
        
        // Access SwiftData directly
        let container = try ModelContainer(for: Goal.self, Day.self, GoalSession.self)
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Goal>()
        
        let fetchedGoals = try context.fetch(descriptor)
        let allGoals = fetchedGoals.filter { $0.status == .active }
        
        // Find goals with weather triggers
        let weatherGoals = allGoals.filter { goal in
            goal.hasWeatherTriggers
        }
        
        if weatherGoals.isEmpty {
            return .result(dialog: "No goals have weather-based triggers set up")
        }
        
        // Filter by current weather
        let matchingGoals = weatherGoals.filter { goal in
            SessionFilterService.meetsWeatherRequirements(goal, weatherManager: weatherManager)
        }
        
        if matchingGoals.isEmpty {
            let weatherDesc = weatherManager.weatherDisplayString
            return .result(dialog: "Current weather: \(weatherDesc). No matching goals found.")
        }
        
        let goalTitles = matchingGoals.map { $0.title }.joined(separator: ", ")
        let weatherDesc = weatherManager.weatherDisplayString
        
        return .result(dialog: "Current weather: \(weatherDesc). Recommended: \(goalTitles)")
    }
}

// MARK: - Check Goal Progress

struct CheckGoalProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Goal Progress"
    static var description = IntentDescription("Check your progress on a goal")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Goal")
    var goal: GoalEntity
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Access SwiftData directly using the app group
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        let goalDescriptor = FetchDescriptor<Goal>()
        
        let goals = try context.fetch(goalDescriptor)
        guard let selectedGoal = goals.first(where: { $0.id.uuidString == goal.id }) else {
            throw IntentError.goalNotFound
        }
        
        // Calculate weekly progress
        var totalTime: TimeInterval = 0
        let calendar = Calendar.current
        
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            throw IntentError.sessionNotFound
        }
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            let dayID = date.yearMonthDayID(with: calendar)
            
            let sessionDescriptor = FetchDescriptor<GoalSession>()
            
            let sessions = try? context.fetch(sessionDescriptor)
            if let session = sessions?.first(where: { $0.goalID == selectedGoal.id.uuidString && $0.day?.id == dayID }) {
                totalTime += session.elapsedTime
                totalTime += session.healthKitTime
            }
        }
        
        let weeklyMinutes = Int(totalTime / 60)
        let targetMinutes = Int(selectedGoal.weeklyTarget / 60)
        let percentage = targetMinutes > 0 ? Int((Double(weeklyMinutes) / Double(targetMinutes)) * 100) : 0
        
        let dialogText = "\(goal.title): \(weeklyMinutes) of \(targetMinutes) minutes this week (\(percentage)%)"
        
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - Log Time Manually

struct LogTimeManuallyIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Time for Goal"
    static var description = IntentDescription("Manually log time spent on a goal")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Goal")
    var goal: GoalEntity
    
    @Parameter(title: "Minutes", default: 30)
    var minutes: Int
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Access SwiftData directly using the app group
        let container = try createSharedModelContainer()
        let context = ModelContext(container)
        
        let goalDescriptor = FetchDescriptor<Goal>()
        
        let goals = try context.fetch(goalDescriptor)
        guard goals.first(where: { $0.id.uuidString == goal.id }) != nil else {
            throw IntentError.goalNotFound
        }
        
        // Manual time logging requires opening the app
        return .result(dialog: IntentDialog("Opening Momentum to log \(minutes) minutes for \(goal.title)"))
    }
}

// MARK: - App Shortcuts Provider

struct MomentumAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodaysGoalsIntent(),
            phrases: [
                "Show my goals for today in \(.applicationName)",
                "What are my \(.applicationName) goals today",
                "My goals in \(.applicationName)"
            ],
            shortTitle: "Today's Goals",
            systemImageName: "list.bullet.circle"
        )
        
        AppShortcut(
            intent: GetWeatherRecommendationsIntent(),
            phrases: [
                "Show weather goals in \(.applicationName)",
                "What goals match the weather in \(.applicationName)"
            ],
            shortTitle: "Weather Recommendations",
            systemImageName: "cloud.sun"
        )
        
        AppShortcut(
            intent: StartGoalTimerIntent(),
            phrases: [
                "Start \(\.$goal) in \(.applicationName)",
                "Begin tracking \(\.$goal) in \(.applicationName)",
                "Start timer for \(\.$goal) in \(.applicationName)"
            ],
            shortTitle: "Start Goal",
            systemImageName: "play.circle"
        )
        
        AppShortcut(
            intent: StopGoalTimerIntent(),
            phrases: [
                "Stop my timer in \(.applicationName)",
                "Stop tracking in \(.applicationName)"
            ],
            shortTitle: "Stop Timer",
            systemImageName: "stop.circle"
        )
    }
}

// MARK: - Supporting Types

struct GoalSummary: Codable {
    let title: String
    let iconName: String?
    let progress: Double
    
    init(from goal: Goal, context: ModelContext) {
        self.title = goal.title
        self.iconName = goal.iconName
        
        // Calculate today's progress
        let todayID = Date().yearMonthDayID(with: Calendar.current)
        let descriptor = FetchDescriptor<GoalSession>()
        
        let sessions = try? context.fetch(descriptor)
        if let session = sessions?.first(where: { $0.goalID == goal.id.uuidString && $0.day?.id == todayID }) {
            let dailyTarget = session.dailyTarget
            let elapsed = session.elapsedTime + session.healthKitTime
            self.progress = dailyTarget > 0 ? Double(elapsed / dailyTarget) : 0.0
        } else {
            self.progress = 0
        }
    }
}

struct TodaysGoalsView: View {
    let goals: [GoalSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if goals.isEmpty {
                Text("No goals scheduled for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goals, id: \.title) { goal in
                    HStack {
                        if let icon = goal.iconName {
                            Image(systemName: icon)
                                .foregroundStyle(.blue)
                        }
                        Text(goal.title)
                            .font(.body)
                        Spacer()
                        Text("\(Int(goal.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Intent Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case goalNotFound
    case sessionNotFound
    case noActiveSession
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .goalNotFound:
            return "Goal not found"
        case .sessionNotFound:
            return "No session found for today"
        case .noActiveSession:
            return "No active timer running"
        }
    }
}

// MARK: - Shared Model Container

/// Creates a model container that accesses the shared app group database
func createSharedModelContainer() throws -> ModelContainer {
    let schema = Schema([
        Goal.self,
        Day.self,
        GoalSession.self,
        GoalTag.self,
        HistoricalSession.self,
        ChecklistItem.self,
        ChecklistItemSession.self,
        IntervalList.self,
        IntervalListSession.self,
        IntervalSection.self,
        IntervalSectionSession.self,
        Interval.self,
        IntervalSession.self
    ])
    
    let groupContainerIdentifier = "group.com.moosa.momentum.ios"
    
    guard let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupContainerIdentifier) else {
        throw IntentError.sessionNotFound // Reusing this error
    }
    
    let storeURL = groupContainer.appendingPathComponent("default.store")
    
    // CloudKit sync enabled (same as main app)
    let cloudKitIdentifier = "iCloud.com.moosa.ios.momentum"
    let modelConfiguration = ModelConfiguration(
        url: storeURL,
        cloudKitDatabase: .private(cloudKitIdentifier)
    )
    
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
}
