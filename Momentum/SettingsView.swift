//
//  SettingsView.swift
//  Momentum
//
//  Created by Mo Moosa on 20/01/2026.
//

import SwiftUI
import MomentumKit
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    @AppStorage("skipPlanningAnimation") private var skipPlanningAnimation: Bool = false
    @AppStorage("weekStartDay") private var weekStartDay: Int = Calendar.current.firstWeekday
    @AppStorage("useGradientOutline") private var useGradientOutline: Bool = false
    @AppStorage("showProgressTile") private var showProgressTile: Bool = true
    @AppStorage("showWeatherTile") private var showWeatherTile: Bool = true
    @AppStorage("showCalendarTile") private var showCalendarTile: Bool = true
    @State private var showingRemindersImport = false
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section {
                    Toggle("Unlimited Sessions", isOn: $unlimitedPlannedSessions)
                    
                    if !unlimitedPlannedSessions {
                        Stepper("Max Sessions: \(maxPlannedSessions)", 
                                value: $maxPlannedSessions, 
                                in: 1...20)
                        
                        Text("The AI planner will suggest up to \(maxPlannedSessions) session\(maxPlannedSessions == 1 ? "" : "s") per day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("The AI planner will suggest as many sessions as needed to meet your goals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("AI Planning", systemImage: "sparkles")
                } footer: {
                    Text("Control how many daily sessions the AI planner can suggest. Fewer sessions create more focused days, while more sessions provide comprehensive coverage of all your goals.")
                }
                
                Section {
                    Picker("Week Starts On", selection: $weekStartDay) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                    }
                    
                    let systemDefault = Calendar.current.firstWeekday
                    let systemDefaultName = systemDefault == 1 ? "Sunday" : "Monday"
                    
                    Text("System default: \(systemDefaultName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Calendar", systemImage: "calendar")
                } footer: {
                    Text("This affects weekly progress tracking and charts throughout the app. The default value is based on your region settings.")
                }
                
                Section {
                    NavigationLink {
                        CalendarSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Schedule Flexibility")
                                Text("Smart recommendations based on your availability")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Integrations", systemImage: "link")
                } footer: {
                    Text("Enable calendar access to get goal suggestions when you actually have time to work on them. Weekend goals will be suggested on weekdays if your weekend is busy.")
                }
                
                Section {
                    Toggle("Gradient Outline (Dark Mode)", isOn: $useGradientOutline)
                    
                    Text(useGradientOutline ? "Recommended sessions show gradient borders instead of filled backgrounds in dark mode." : "Recommended sessions use filled gradient backgrounds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Appearance", systemImage: "paintbrush")
                } footer: {
                    Text("Gradient outlines provide a cleaner look in dark mode while still highlighting recommended sessions.")
                }
                
                Section {
                    Toggle("Progress Ring", isOn: $showProgressTile)
                    Toggle("Weather", isOn: $showWeatherTile)
                    Toggle("Calendar", isOn: $showCalendarTile)
                    
                    if !showProgressTile && !showWeatherTile && !showCalendarTile {
                        Text("At least one tile should be enabled to see the progress card.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Label("Progress Card Tiles", systemImage: "square.grid.2x2")
                } footer: {
                    Text("Choose which tiles to show on your daily progress card. The progress card will be hidden if all tiles are disabled.")
                }
                
                Section {
                    Toggle("Skip Reveal Animation", isOn: $skipPlanningAnimation)
                    
                    Text(skipPlanningAnimation ? "Sessions will appear instantly." : "Sessions will reveal one by one with animation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Performance", systemImage: "gauge.with.dots.needle.bottom.50percent")
                } footer: {
                    Text("Skipping the animation makes planning feel faster by showing all sessions immediately.")
                }
                
                Section {
                    NavigationLink {
                        CloudKitSyncDetailView()
                    } label: {
                        CloudKitSyncStatusView()
                    }
                } header: {
                    Label("Data & Sync", systemImage: "icloud")
                }
                
                Section {
                    Button {
                        showingRemindersImport = true
                    } label: {
                        Label("Import from Reminders", systemImage: "checklist")
                    }

                    Button {
                        if let url = URL(string: "App-prefs:Focus") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Configure Focus Filters", systemImage: "moon")
                    }
                } header: {
                    Label("Integrations", systemImage: "square.and.arrow.down")
                } footer: {
                    Text("Import goals from Reminders, or set up Focus Filters in iOS Settings to show only certain goal tags during a Focus mode.")
                }
                
                #if DEBUG
                Section {
                    Button {
                        addDebugGoals()
                    } label: {
                        Text("Add Debug Goals")
                    }

                } header: {
                    Text("Debug")
                }
                #endif
                
                Section {
                    NavigationLink {
                        ConsolidatedTodayView()
                    } label: {
                        HStack {
                            Image(systemName: "flask")
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unified Today View")
                                Text("Experimental combined planner + overview")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Experimental", systemImage: "flask")
                } footer: {
                    Text("Try out a new unified view that combines day overview, quick recommendations, and AI planning in one place. Compare it with the current design and let us know what you think!")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRemindersImport) {
                RemindersImportView()
            }
        }
    }
    
#if DEBUG
    private func addDebugGoals() {
        for debugGoal in DebugGoals.allCases {
            addDebugGoal(debugGoal)
        }
        
        // Add historical sessions for the previous week to test weekly progress chart
        addDebugHistoricalSessions()
    }
    
    private func addDebugGoal(_ debugGoal: DebugGoals) {
        let theme = GoalTag(title: debugGoal.themeTitle, themeID: debugGoal.theme.id)
        let goal = Goal(
            title: debugGoal.title,
            primaryTag: theme,
            weeklyTarget: TimeInterval(debugGoal.weeklyTargetMinutes * 60),
            healthKitMetric: debugGoal.healthKitMetric,
            healthKitSyncEnabled: debugGoal.healthKitSyncEnabled
        )
        withAnimation {
            modelContext.insert(goal)
        }
    }
    
#endif

    private func addDebugHistoricalSessions() {
        let calendar = Calendar.current
        let today = Date()
        
        // Fetch all goals to add historical sessions to
        let descriptor = FetchDescriptor<Goal>()
        guard let goals = try? modelContext.fetch(descriptor) else { return }
        
        // Create historical sessions for last week (7-13 days ago)
        for dayOffset in 7...13 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            // Create or fetch the day
            let day = Day(start: startOfDay, end: endOfDay, calendar: calendar)
            modelContext.insert(day)
            
            // Add sessions for each goal with some randomness
            for goal in goals {
                // Create a session for this goal on this day
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                modelContext.insert(session)
                
                // Add 1-3 historical sessions per day for variety
                let sessionCount = Int.random(in: 1...3)
                for _ in 0..<sessionCount {
                    // Random duration between 5-45 minutes
                    let duration = TimeInterval.random(in: 300...2700)
                    // Random time during the day
                    let startOffset = TimeInterval.random(in: 3600...72000) // Between 1am and 8pm
                    let sessionStart = startOfDay.addingTimeInterval(startOffset)
                    let sessionEnd = sessionStart.addingTimeInterval(duration)
                    
                    let historicalSession = HistoricalSession(
                        title: goal.title,
                        start: sessionStart,
                        end: sessionEnd,
                        needsHealthKitRecord: false
                    )
                    historicalSession.goalIDs = [session.goalID]
                    day.add(historicalSession: historicalSession)
                }
            }
        }
        
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
}

#if DEBUG
enum DebugGoals: String, CaseIterable, Identifiable {
    case reading = "Reading"
    case exercise = "Exercise"
    case meditation = "Meditation"
    case coding = "Coding Practice"
    case music = "Music Practice"
    case cooking = "Cooking"
    case learning = "Language Learning"
    case writing = "Writing"
    
    var id: String { rawValue }
    
    var title: String {
        rawValue
    }
    
    var themeTitle: String {
        switch self {
        case .reading: return "Learning"
        case .exercise: return "Health"
        case .meditation: return "Wellness"
        case .coding: return "Tech"
        case .music: return "Creative"
        case .cooking: return "Home"
        case .learning: return "Education"
        case .writing: return "Creative"
        }
    }
    
    var theme: ThemePreset {
        switch self {
        case .reading: return themePresets.first(where: { $0.id == "blue" })!
        case .exercise: return themePresets.first(where: { $0.id == "red" })!
        case .meditation: return themePresets.first(where: { $0.id == "purple" })!
        case .coding: return themePresets.first(where: { $0.id == "green" })!
        case .music: return themePresets.first(where: { $0.id == "orange" })!
        case .cooking: return themePresets.first(where: { $0.id == "yellow" })!
        case .learning: return themePresets.first(where: { $0.id == "purple" })!
        case .writing: return themePresets.first(where: { $0.id == "teal" })!
        }
    }
    
    var weeklyTargetMinutes: Int {
        switch self {
        case .reading: return 210 // 30 min/day
        case .exercise: return 175 // 25 min/day
        case .meditation: return 70 // 10 min/day
        case .coding: return 420 // 60 min/day
        case .music: return 140 // 20 min/day
        case .cooking: return 105 // 15 min/day
        case .learning: return 210 // 30 min/day
        case .writing: return 140 // 20 min/day
        }
    }
    
    var notificationsEnabled: Bool {
        switch self {
        case .meditation, .exercise, .reading:
            return true
        default:
            return false
        }
    }
    
    var healthKitMetric: HealthKitMetric? {
        switch self {
        case .exercise: return .appleExerciseTime
        case .meditation: return .mindfulMinutes
        default: return nil
        }
    }
    
    var healthKitSyncEnabled: Bool {
        return healthKitMetric != nil
    }
}
#endif


