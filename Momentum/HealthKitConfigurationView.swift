//
//  HealthKitConfigurationView.swift
//  Momentum
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import MomentumKit
import HealthKit

struct HealthKitConfigurationView: View {
    @Binding var selectedMetric: HealthKitMetric?
    @Binding var syncEnabled: Bool
    @Binding var dailyTargetMinutes: Int?
    var currentGoal: Goal? = nil
    
    @State private var healthKitManager = HealthKitManager()
    @State private var isLoadingGoals = false
    @State private var showingGoalImportSuccess = false
    @State private var lastSyncDate: Date?
    @State private var isSyncing = false
    
    var body: some View {
        Group {
        Section {
            NavigationLink {
                HealthKitMetricsBrowserView(
                    selectedMetric: Binding(
                        get: { selectedMetric },
                        set: { newMetric in
                            handleMetricSelection(newMetric)
                        }
                    ),
                    currentGoal: currentGoal
                )
            } label: {
                HStack {
                    Text("Health Metric")
                    Spacer()
                    if let metric = selectedMetric {
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
            
            if let selectedMetric {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedMetric.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if syncEnabled {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Syncing...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if let lastSync = lastSyncDate {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("Last synced: \(lastSync, style: .relative)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("Waiting for first sync")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }                    
                }
        } header: {
            Text("HealthKit Integration")
        } footer: {
            if selectedMetric != nil {
                Text("Time tracked in HealthKit will be automatically added to your goal progress.")
            } else {
                Text("Link this goal to a HealthKit metric to automatically sync your health data.")
            }
        }
        }
        .task(id: currentGoal?.id) {
            // Check last sync date for the current goal
            if let goal = currentGoal, goal.healthKitSyncEnabled {
                lastSyncDate = goal.lastHealthKitSyncDate
            }
        }
    }

    private func handleMetricSelection(_ newMetric: HealthKitMetric?) {
        // Set the metric
        selectedMetric = newMetric
        
        // Enable sync if metric is selected, disable if cleared
        syncEnabled = newMetric != nil
        
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
    
    private func importActivityGoal() {
        guard let selectedMetric else { return }
        
        isLoadingGoals = true
        showingGoalImportSuccess = false
        
        Task {
            let manager = HealthKitManager()
            if let goals = await manager.fetchActivityGoals() {
                await MainActor.run {
                    // Map the appropriate goal to the daily target
                    switch selectedMetric {
                    case .appleExerciseTime:
                        dailyTargetMinutes = goals.exerciseMinutes
                    case .appleStandTime:
                        dailyTargetMinutes = goals.standHours
                    default:
                        break
                    }
                    
                    isLoadingGoals = false
                    showingGoalImportSuccess = true
                    
                    // Hide success message after 3 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        await MainActor.run {
                            showingGoalImportSuccess = false
                        }
                    }
                }
            } else {
                await MainActor.run {
                    isLoadingGoals = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            HealthKitConfigurationView(
                selectedMetric: .constant(.appleExerciseTime),
                syncEnabled: .constant(true),
                dailyTargetMinutes: .constant(30)
            )
        }
    }
}
