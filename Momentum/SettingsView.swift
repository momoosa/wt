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
    
    private func addDebugGoals() {
        for debugGoal in DebugGoals.allCases {
            addDebugGoal(debugGoal)
        }
    }
    
    private func addDebugGoal(_ debugGoal: DebugGoals) {
        let theme = GoalTag(title: debugGoal.themeTitle, color: debugGoal.theme)
        let goal = Goal(
            title: debugGoal.title,
            primaryTag: theme,
            weeklyTarget: TimeInterval(debugGoal.weeklyTargetMinutes * 60),
            notificationsEnabled: debugGoal.notificationsEnabled,
            healthKitMetric: debugGoal.healthKitMetric,
            healthKitSyncEnabled: debugGoal.healthKitSyncEnabled
        )
        withAnimation {
            modelContext.insert(goal)
        }
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
    
    var theme: Theme {
        switch self {
        case .reading: return themePresets.first(where: { $0.id == "blue" })!.toTheme()
        case .exercise: return themePresets.first(where: { $0.id == "red" })!.toTheme()
        case .meditation: return themePresets.first(where: { $0.id == "purple" })!.toTheme()
        case .coding: return themePresets.first(where: { $0.id == "green" })!.toTheme()
        case .music: return themePresets.first(where: { $0.id == "orange" })!.toTheme()
        case .cooking: return themePresets.first(where: { $0.id == "yellow" })!.toTheme()
        case .learning: return themePresets.first(where: { $0.id == "purple" })!.toTheme()
        case .writing: return themePresets.first(where: { $0.id == "teal" })!.toTheme()
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


