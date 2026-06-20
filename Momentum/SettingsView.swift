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
    
    @State private var showingWeeklyRecap = false
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section {
                    Button {
                        showingWeeklyRecap = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weekly Recap")
                                Text("Review your progress this week")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Label("Review", systemImage: "chart.xyaxis.line")
                }
                
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
                    NavigationLink {
                        AppPermissionsView()
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Permissions")
                                Text("Location, Calendar, Notifications")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Permissions", systemImage: "lock.shield")
                } footer: {
                    Text("Manage the system permissions Momentum uses for weather, scheduling, and reminders.")
                }
                
                Section {
                    NavigationLink {
                        TagManagementView()
                    } label: {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage Tags")
                                Text("Rename or delete goal tags")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Tags", systemImage: "tag")
                } footer: {
                    Text("Tags categorise your goals. Deleting a tag removes it from all goals that use it.")
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
                    NavigationLink {
                        DebugScoreView()
                    } label: {
                        Label("Score Breakdown", systemImage: "chart.bar.fill")
                    }
                    
                    Button {
                        addDebugGoals()
                    } label: {
                        Label("Add Debug Goals (All Types)", systemImage: "plus.circle")
                    }
                    
                    Button {
                        addDebugHistoricalSessions()
                    } label: {
                        Label("Add Historical Sessions", systemImage: "clock.arrow.circlepath")
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
            .sheet(isPresented: $showingWeeklyRecap) {
                WeeklyRecapView()
            }
        }
    }
    
#if DEBUG
    private func addDebugGoals() {
        for spec in DebugGoalSpec.allSpecs {
            let tag = GoalTag(title: spec.tagTitle, themeID: spec.themeID)
            let goal = Goal(
                title: spec.title,
                primaryTag: tag,
                healthKitMetric: spec.healthKitMetric,
                healthKitSyncEnabled: spec.healthKitMetric != nil
            )
            goal.iconName = spec.iconName
            goal.targetUnit = spec.targetUnit
            goal.unifiedDailyTarget = spec.dailyTarget
            
            // Set schedule if provided (weekdays only, etc.)
            for (weekday, times) in spec.schedule {
                goal.setTimes(times, forWeekday: weekday)
            }
            
            // Set weather triggers
            if let conditions = spec.weatherConditions {
                goal.weatherEnabled = true
                goal.weatherConditionsTyped = conditions
            }
            
            modelContext.insert(goal)
            
            // Add checklist items
            for itemTitle in spec.checklistItems {
                let item = ChecklistItem(title: itemTitle, goal: goal)
                modelContext.insert(item)
            }
            
            // Add interval lists
            for intervalSpec in spec.intervalLists {
                let intervals = intervalSpec.intervals.enumerated().map { index, iv in
                    Interval(name: iv.name, durationSeconds: iv.seconds, orderIndex: index, kind: iv.kind)
                }
                let list = IntervalList(name: intervalSpec.name, goal: goal, intervals: intervals)
                modelContext.insert(list)
                for interval in intervals {
                    modelContext.insert(interval)
                }
            }
        }
        
        addDebugHistoricalSessions()
    }
#endif
    
    private func addDebugHistoricalSessions() {
        let calendar = Calendar.current
        let today = Date()
        
        let descriptor = FetchDescriptor<Goal>()
        guard let goals = try? modelContext.fetch(descriptor), !goals.isEmpty else { return }
        
        // Create sessions for the last 14 days (including recent days for visible progress)
        for dayOffset in 1...14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let dayID = startOfDay.yearMonthDayID(with: calendar)
            
            // Fetch existing day or create a new one
            var dayDescriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })
            dayDescriptor.fetchLimit = 1
            let day: Day
            if let existingDay = try? modelContext.fetch(dayDescriptor).first {
                day = existingDay
            } else {
                day = Day(start: startOfDay, end: endOfDay, calendar: calendar)
                modelContext.insert(day)
            }
            
            // Pick a random subset of goals for this day (not every goal every day)
            let goalCount = Int.random(in: max(1, goals.count / 2)...goals.count)
            let dailyGoals = Array(goals.shuffled().prefix(goalCount))
            
            for goal in dailyGoals {
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                modelContext.insert(session)
                
                // Vary session patterns based on how recent the day is
                let isRecent = dayOffset <= 3
                let sessionCount = isRecent ? Int.random(in: 1...2) : Int.random(in: 1...3)
                
                for sessionIndex in 0..<sessionCount {
                    // Spread sessions across the day: morning, afternoon, evening
                    let baseHour: Double
                    switch sessionIndex {
                    case 0: baseHour = Double.random(in: 7...10)    // Morning
                    case 1: baseHour = Double.random(in: 13...16)   // Afternoon
                    default: baseHour = Double.random(in: 18...21)  // Evening
                    }
                    
                    let startOffset = baseHour * 3600
                    let sessionStart = startOfDay.addingTimeInterval(startOffset)
                    
                    // Duration based on goal type
                    let duration: TimeInterval
                    switch goal.targetUnit {
                    case .seconds:
                        // Aim for partial to full daily target completion
                        let targetPortion = Double.random(in: 0.3...0.8)
                        duration = min(goal.unifiedDailyTarget * targetPortion, 3600)
                    case .steps, .kilocalories:
                        duration = TimeInterval.random(in: 600...1800) // 10-30 min
                    case .screenTime:
                        duration = TimeInterval.random(in: 300...1200) // 5-20 min
                    }
                    
                    let sessionEnd = sessionStart.addingTimeInterval(max(duration, 120))
                    
                    let historicalSession = HistoricalSession(
                        title: goal.title,
                        start: sessionStart,
                        end: sessionEnd,
                        needsHealthKitRecord: false
                    )
                    historicalSession.goalIDs = [session.goalID]
                    modelContext.insert(historicalSession)
                    day.add(historicalSession: historicalSession)
                }
                
                // Sync currentValue for time-based goals so progress is visible
                if goal.targetUnit.isTimeBased {
                    session.syncCurrentValueFromElapsedTime()
                }
            }
        }
        
        modelContext.safeSave()
    }
}

#Preview {
    SettingsView()
}

// MARK: - Debug Goal Specifications

#if DEBUG

/// Interval specification for debug goals
private struct DebugIntervalSpec {
    let name: String
    let intervals: [(name: String, seconds: Int, kind: Interval.Kind)]
}

/// Specification for a debug goal
private struct DebugGoalSpec {
    let title: String
    let iconName: String?
    let tagTitle: String
    let themeID: String
    let targetUnit: Goal.TargetUnit
    let dailyTarget: Double
    let healthKitMetric: HealthKitMetric?
    let schedule: [Int: Set<TimeOfDay>] // weekday -> times
    let weatherConditions: [WeatherCondition]?
    let checklistItems: [String]
    let intervalLists: [DebugIntervalSpec]
    
    static let allSpecs: [DebugGoalSpec] = [
        // 1. Simple time-based goal
        DebugGoalSpec(
            title: "Reading",
            iconName: "book.fill",
            tagTitle: "Learning",
            themeID: "palette_17",
            targetUnit: .seconds,
            dailyTarget: 1800, // 30 min
            healthKitMetric: nil,
            schedule: [2: [.morning], 3: [.morning], 4: [.morning], 5: [.morning], 6: [.morning]], // Mon-Fri mornings
            weatherConditions: nil,
            checklistItems: [],
            intervalLists: []
        ),
        // 2. Exercise with HealthKit
        DebugGoalSpec(
            title: "Exercise",
            iconName: "figure.run",
            tagTitle: "Health",
            themeID: "palette_01",
            targetUnit: .seconds,
            dailyTarget: 1500, // 25 min
            healthKitMetric: .appleExerciseTime,
            schedule: [1: [.morning], 2: [.morning], 4: [.morning], 6: [.morning], 7: [.morning]], // Sun, Mon, Wed, Fri, Sat
            weatherConditions: [.clear, .partlyCloudy],
            checklistItems: [],
            intervalLists: []
        ),
        // 3. Meditation with HealthKit
        DebugGoalSpec(
            title: "Meditation",
            iconName: "brain.head.profile",
            tagTitle: "Wellness",
            themeID: "palette_16",
            targetUnit: .seconds,
            dailyTarget: 600, // 10 min
            healthKitMetric: .mindfulMinutes,
            schedule: [:], // Any day
            weatherConditions: nil,
            checklistItems: [],
            intervalLists: []
        ),
        // 4. Step count goal (non-time metric)
        DebugGoalSpec(
            title: "Daily Walk",
            iconName: "figure.walk",
            tagTitle: "Movement",
            themeID: "palette_04",
            targetUnit: .steps,
            dailyTarget: 10000,
            healthKitMetric: .stepCount,
            schedule: [:],
            weatherConditions: [.clear, .partlyCloudy, .cloudy],
            checklistItems: [],
            intervalLists: []
        ),
        // 5. Calorie burn goal
        DebugGoalSpec(
            title: "Active Calories",
            iconName: "flame.fill",
            tagTitle: "Fitness",
            themeID: "palette_01",
            targetUnit: .kilocalories,
            dailyTarget: 500,
            healthKitMetric: .activeEnergyBurned,
            schedule: [:],
            weatherConditions: nil,
            checklistItems: [],
            intervalLists: []
        ),
        // 6. Goal with checklist items
        DebugGoalSpec(
            title: "Morning Routine",
            iconName: "sunrise.fill",
            tagTitle: "Wellbeing",
            themeID: "palette_03",
            targetUnit: .seconds,
            dailyTarget: 2700, // 45 min
            healthKitMetric: nil,
            schedule: [1: [.morning], 2: [.morning], 3: [.morning], 4: [.morning], 5: [.morning], 6: [.morning], 7: [.morning]],
            weatherConditions: nil,
            checklistItems: [
                "Make bed",
                "Stretch for 5 minutes",
                "Drink water",
                "Journal",
                "Review today's plan"
            ],
            intervalLists: []
        ),
        // 7. Goal with Pomodoro interval list
        DebugGoalSpec(
            title: "Deep Work",
            iconName: "desktopcomputer",
            tagTitle: "Deep Work",
            themeID: "palette_19",
            targetUnit: .seconds,
            dailyTarget: 5400, // 90 min
            healthKitMetric: nil,
            schedule: [2: [.morning, .afternoon], 3: [.morning, .afternoon], 4: [.morning, .afternoon], 5: [.morning, .afternoon], 6: [.morning]],
            weatherConditions: nil,
            checklistItems: [],
            intervalLists: [
                DebugIntervalSpec(
                    name: "Pomodoro",
                    intervals: [
                        (name: "Focus 1", seconds: 1500, kind: .work),
                        (name: "Break 1", seconds: 300, kind: .breakTime),
                        (name: "Focus 2", seconds: 1500, kind: .work),
                        (name: "Break 2", seconds: 300, kind: .breakTime),
                        (name: "Focus 3", seconds: 1500, kind: .work),
                        (name: "Long Break", seconds: 900, kind: .breakTime),
                    ]
                )
            ]
        ),
        // 8. Goal with custom interval (HIIT workout)
        DebugGoalSpec(
            title: "HIIT Workout",
            iconName: "bolt.heart.fill",
            tagTitle: "Health",
            themeID: "palette_01",
            targetUnit: .seconds,
            dailyTarget: 1200, // 20 min
            healthKitMetric: nil,
            schedule: [2: [.morning], 4: [.morning], 6: [.morning]], // Mon, Wed, Fri
            weatherConditions: nil,
            checklistItems: [],
            intervalLists: [
                DebugIntervalSpec(
                    name: "HIIT Circuit",
                    intervals: [
                        (name: "Warm Up", seconds: 120, kind: .breakTime),
                        (name: "Sprint 1", seconds: 30, kind: .work),
                        (name: "Rest", seconds: 30, kind: .breakTime),
                        (name: "Sprint 2", seconds: 30, kind: .work),
                        (name: "Rest", seconds: 30, kind: .breakTime),
                        (name: "Sprint 3", seconds: 30, kind: .work),
                        (name: "Rest", seconds: 30, kind: .breakTime),
                        (name: "Sprint 4", seconds: 30, kind: .work),
                        (name: "Rest", seconds: 30, kind: .breakTime),
                        (name: "Sprint 5", seconds: 30, kind: .work),
                        (name: "Cool Down", seconds: 120, kind: .breakTime),
                    ]
                )
            ]
        ),
        // 9. Writing with checklist + weather preference
        DebugGoalSpec(
            title: "Creative Writing",
            iconName: "pencil.line",
            tagTitle: "Creative",
            themeID: "palette_04",
            targetUnit: .seconds,
            dailyTarget: 1800, // 30 min
            healthKitMetric: nil,
            schedule: [1: [.afternoon], 7: [.afternoon]], // Weekends
            weatherConditions: [.rainy, .cloudy], // Write when it's rainy
            checklistItems: [
                "Outline scene",
                "Write first draft",
                "Review and revise"
            ],
            intervalLists: []
        ),
        // 10. Unscheduled / flexible goal
        DebugGoalSpec(
            title: "Guitar Practice",
            iconName: "guitars.fill",
            tagTitle: "Creative",
            themeID: "palette_04",
            targetUnit: .seconds,
            dailyTarget: 1200, // 20 min
            healthKitMetric: nil,
            schedule: [:], // Anytime
            weatherConditions: nil,
            checklistItems: [],
            intervalLists: [
                DebugIntervalSpec(
                    name: "Practice Session",
                    intervals: [
                        (name: "Scales", seconds: 300, kind: .work),
                        (name: "Break", seconds: 60, kind: .breakTime),
                        (name: "Chords", seconds: 300, kind: .work),
                        (name: "Break", seconds: 60, kind: .breakTime),
                        (name: "Song Practice", seconds: 480, kind: .work),
                    ]
                )
            ]
        ),
    ]
}

#endif


