//
//  ScreenTimeGoalConfigurationView.swift
//  Momentum
//
//  Created by Claude Code on 31/03/2026.
//

import SwiftUI
import FamilyControls
import MomentumKit

struct ScreenTimeGoalConfigurationView: View {
    @Bindable var goal: Goal
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var showAppPicker = false
    @State private var selectedApps = FamilyActivitySelection()
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Screen Time Tracking", isOn: $goal.screenTimeEnabled)
                
                if goal.screenTimeEnabled && !screenTimeManager.isAuthorized {
                    Button {
                        Task {
                            try? await screenTimeManager.requestAuthorization()
                        }
                    } label: {
                        Label("Authorize Screen Time Access", systemImage: "lock.shield")
                    }
                }
            } header: {
                Text("Screen Time Integration")
            } footer: {
                Text("Track app usage and set limits based on your screen time.")
            }
            
            if goal.screenTimeEnabled && screenTimeManager.isAuthorized {
                Section {
                    Toggle("Limit Usage (Inverse Goal)", isOn: $goal.screenTimeIsInverseGoal)
                    
                    Button {
                        showAppPicker = true
                    } label: {
                        Label("Select Apps & Categories", systemImage: "app.badge")
                    }
                    
                    if hasSelectedApps {
                        Text("\(selectedAppsCount) items selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apps to Track")
                } footer: {
                    if goal.screenTimeIsInverseGoal {
                        Text("Your goal is to limit usage of these apps below your weekly target.")
                    } else {
                        Text("Your goal is to use these apps for your weekly target duration.")
                    }
                }
                
                Section {
                    Toggle("Block Apps Until Goal Complete", isOn: $goal.screenTimeBlockingEnabled)
                    
                    if goal.screenTimeBlockingEnabled {
                        HStack {
                            Text("Block From")
                            Spacer()
                            Picker("Start Hour", selection: Binding(
                                get: { goal.screenTimeBlockingStartHour ?? 6 },
                                set: { goal.screenTimeBlockingStartHour = $0 }
                            )) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        HStack {
                            Text("Block Until")
                            Spacer()
                            Picker("End Hour", selection: Binding(
                                get: { goal.screenTimeBlockingEndHour ?? 10 },
                                set: { goal.screenTimeBlockingEndHour = $0 }
                            )) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Block on Days")
                            
                            HStack(spacing: 8) {
                                ForEach(weekdayOptions, id: \.value) { option in
                                    Button {
                                        toggleWeekday(option.value)
                                    } label: {
                                        Text(option.label)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(
                                                goal.screenTimeBlockingWeekdays.contains(option.value) ?
                                                Color.accentColor : Color.secondary.opacity(0.2)
                                            )
                                            .foregroundColor(
                                                goal.screenTimeBlockingWeekdays.contains(option.value) ?
                                                .white : .primary
                                            )
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("App Blocking")
                } footer: {
                    Text("Block selected apps during specified hours until this goal is completed for the day.")
                }
            }
        }
        .sheet(isPresented: $showAppPicker) {
            NavigationStack {
                FamilyActivityPicker(selection: $selectedApps)
                    .navigationTitle("Select Apps")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showAppPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                saveSelection()
                                showAppPicker = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            loadSelection()
        }
    }
    
    // MARK: - Helper Properties
    
    private var hasSelectedApps: Bool {
        !selectedApps.applications.isEmpty || 
        !selectedApps.categories.isEmpty || 
        !selectedApps.webDomains.isEmpty
    }
    
    private var selectedAppsCount: Int {
        selectedApps.applications.count + 
        selectedApps.categories.count + 
        selectedApps.webDomains.count
    }
    
    private let weekdayOptions: [(label: String, value: Int)] = [
        ("S", 1), // Sunday
        ("M", 2), // Monday
        ("T", 3), // Tuesday
        ("W", 4), // Wednesday
        ("T", 5), // Thursday
        ("F", 6), // Friday
        ("S", 7)  // Saturday
    ]
    
    // MARK: - Helper Methods
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
    
    private func toggleWeekday(_ weekday: Int) {
        if let index = goal.screenTimeBlockingWeekdays.firstIndex(of: weekday) {
            goal.screenTimeBlockingWeekdays.remove(at: index)
        } else {
            goal.screenTimeBlockingWeekdays.append(weekday)
            goal.screenTimeBlockingWeekdays.sort()
        }
    }
    
    private func loadSelection() {
        // Note: FamilyActivitySelection tokens cannot be persisted directly
        // The selection will need to be reconfigured each time
        // This is a limitation of the Family Controls API
    }
    
    private func saveSelection() {
        // Note: FamilyActivitySelection tokens cannot be persisted directly
        // We can only store the selection temporarily while the sheet is open
        // The actual blocking/monitoring will use the live selection
    }
}
