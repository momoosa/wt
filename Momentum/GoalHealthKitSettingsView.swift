//
//  GoalHealthKitSettingsView.swift
//  Momentum
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import MomentumKit

/// A view for managing HealthKit settings for an existing goal
struct GoalHealthKitSettingsView: View {
    @Bindable var goal: Goal
    @State private var healthKitManager = HealthKitManager()
    
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    HealthKitMetricsBrowserView(
                        selectedMetric: Binding(
                            get: { goal.healthKitMetric },
                            set: { newMetric in
                                handleMetricSelection(newMetric)
                            }
                        ),
                        currentGoal: goal
                    )
                } label: {
                    HStack {
                        Text("Health Metric")
                        Spacer()
                        if let metric = goal.healthKitMetric {
                            Label {
                                Text(metric.displayName)
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: metric.symbolName)
                                    .foregroundStyle(.secondary)
                            }
                            .labelStyle(.titleAndIcon)
                        } else {
                            Text("None")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let metric = goal.healthKitMetric {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: metric.symbolName)
                                    .foregroundStyle(goal.primaryTag?.theme.dark ?? themePresets[0].dark)
                                Text(metric.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Show read/write capability
                            if metric.supportsWrite {
                                Label {
                                    Text("Tracked sessions will be saved to Health")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } icon: {
                                    Image(systemName: "arrow.up.doc")
                                        .foregroundStyle(.blue)
                                }
                            } else {
                                Label {
                                    Text("Read-only metric")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } icon: {
                                    Image(systemName: "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Show authorization status
                        if healthKitManager.isHealthKitAvailable && healthKitManager.isAuthorized(for: metric) {
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
            } header: {
                Text("HealthKit Integration")
            } footer: {
                if let metric = goal.healthKitMetric {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time tracked in HealthKit will be automatically added to this goal's daily progress.")
                        Text("This goal will track: **\(metric.displayName)**")
                    }
                } else {
                    Text("Link this goal to a HealthKit metric to automatically sync your health data.")
                }
            }
            
            if goal.healthKitMetric != nil {
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
    }
    
    private func handleMetricSelection(_ newMetric: HealthKitMetric?) {
        // Set the metric
        goal.healthKitMetric = newMetric
        
        // Enable sync if metric is selected, disable if cleared
        goal.healthKitSyncEnabled = newMetric != nil
        
        guard let newMetric else { return }
        
        // Request authorization if not already authorized
        if !healthKitManager.isAuthorized(for: newMetric) {
            Task {
                try? await healthKitManager.requestAuthorization(for: [newMetric])
                
                // Refresh the manager to update authorization status
                await MainActor.run {
                    healthKitManager = HealthKitManager()
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
                        Text("Read & Write Access")
                            .fontWeight(.semibold)
                        Text("Some metrics support writing sessions back to HealthKit. Sessions you track will be saved to your Health app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.blue)
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
                            Text("Select **Momentum**")
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
        let theme = GoalTag(title: "Health", themeID: themePresets.first!.id)
        let goal = Goal(
            title: "Exercise",
            primaryTag: theme,
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
