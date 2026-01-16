//
//  GoalHealthKitSettingsView.swift
//  Weektime
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import WeektimeKit

/// A view for managing HealthKit settings for an existing goal
struct GoalHealthKitSettingsView: View {
    @Bindable var goal: Goal
    @State private var healthKitManager = HealthKitManager()
    @State private var showingAuthAlert = false
    @State private var authError: Error?
    
    var body: some View {
        Form {
            Section {
                Toggle("Sync with HealthKit", isOn: $goal.healthKitSyncEnabled)
                
                if goal.healthKitSyncEnabled {
                    Picker("Health Metric", selection: Binding(
                        get: { goal.healthKitMetric },
                        set: { goal.healthKitMetric = $0 }
                    )) {
                        Text("Select Metric").tag(HealthKitMetric?.none)
                        ForEach(HealthKitMetric.allCases) { metric in
                            Label {
                                Text(metric.displayName)
                            } icon: {
                                Image(systemName: metric.symbolName)
                            }
                            .tag(HealthKitMetric?.some(metric))
                        }
                    }
                    
                    if let metric = goal.healthKitMetric {
                        HStack {
                            Image(systemName: metric.symbolName)
                                .foregroundStyle(goal.primaryTheme.theme.dark)
                            Text(metric.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        // Show authorize button only if this specific metric isn't authorized
                        if healthKitManager.isHealthKitAvailable && !healthKitManager.isAuthorized(for: metric) {
                            Button {
                                requestAuthorization()
                            } label: {
                                Label("Authorize HealthKit Access", systemImage: "heart.text.square.fill")
                                    .foregroundStyle(.red)
                            }
                        } else if healthKitManager.isAuthorized(for: metric) {
                            Label {
                                Text("HealthKit Authorized")
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .font(.caption)
                        }
                    }
                }
            } header: {
                Text("HealthKit Integration")
            } footer: {
                if goal.healthKitSyncEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time tracked in HealthKit will be automatically added to this goal's daily progress.")
                        
                        if let metric = goal.healthKitMetric {
                            Text("This goal will track: **\(metric.displayName)**")
                        }
                    }
                } else {
                    Text("Enable HealthKit to automatically sync health data with this goal.")
                }
            }
            
            if goal.healthKitSyncEnabled {
                Section {
                    NavigationLink {
                        HealthKitPrivacyInfoView()
                    } label: {
                        Label("Privacy & Permissions", systemImage: "hand.raised.fill")
                    }
                } footer: {
                    Text("Your health data never leaves your device. You can manage permissions in the Health app.")
                        .font(.caption2)
                }
            }
        }
        .navigationTitle("HealthKit Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("HealthKit Authorization", isPresented: $showingAuthAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = authError {
                Text(error.localizedDescription)
            } else {
                Text("HealthKit access has been granted!")
            }
        }
    }
    
    private func requestAuthorization() {
        guard let metric = goal.healthKitMetric else { return }
        
        Task {
            do {
                try await healthKitManager.requestAuthorization(for: [metric])
                await MainActor.run {
                    // Force a refresh by creating a new manager instance
                    healthKitManager = HealthKitManager()
                    showingAuthAlert = true
                    authError = nil
                }
            } catch {
                await MainActor.run {
                    authError = error
                    showingAuthAlert = true
                }
            }
        }
    }
}

/// Information view about HealthKit privacy
struct HealthKitPrivacyInfoView: View {
    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data Stays on Device")
                            .fontWeight(.semibold)
                        Text("Your health data never leaves your device and is not synced to any cloud service.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.blue)
                }
                
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read-Only Access")
                            .fontWeight(.semibold)
                        Text("Weektime only reads data from HealthKit. It does not modify or add data to your Health app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.green)
                }
                
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You're in Control")
                            .fontWeight(.semibold)
                        Text("You can revoke permissions at any time in the Health app settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Privacy Guarantees")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To manage permissions:")
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Open the **Health** app")
                        }
                        
                        HStack {
                            Text("2.")
                                .fontWeight(.bold)
                            Text("Tap your profile icon")
                        }
                        
                        HStack {
                            Text("3.")
                                .fontWeight(.bold)
                            Text("Go to **Privacy** → **Apps**")
                        }
                        
                        HStack {
                            Text("4.")
                                .fontWeight(.bold)
                            Text("Select **Weektime**")
                        }
                        
                        HStack {
                            Text("5.")
                                .fontWeight(.bold)
                            Text("Toggle individual permissions")
                        }
                    }
                    .font(.callout)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Managing Permissions")
            }
        }
        .navigationTitle("Privacy & Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Settings View") {
    NavigationStack {
        let theme = GoalTheme(title: "Health", color: themes.first!)
        let goal = Goal(
            title: "Exercise",
            primaryTheme: theme,
            weeklyTarget: 210 * 60,
            healthKitMetric: .appleExerciseTime,
            healthKitSyncEnabled: true
        )
        
        GoalHealthKitSettingsView(goal: goal)
    }
}

#Preview("Privacy Info") {
    NavigationStack {
        HealthKitPrivacyInfoView()
    }
}
