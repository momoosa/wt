//
//  HealthKitConfigurationView.swift
//  Momentum
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import MomentumKit

struct HealthKitConfigurationView: View {
    @Binding var selectedMetric: HealthKitMetric?
    @Binding var syncEnabled: Bool
    @Binding var dailyTargetMinutes: Int?
    @State private var healthKitManager = HealthKitManager()
    @State private var isLoadingGoals = false
    @State private var showingGoalImportSuccess = false
    
    var body: some View {
        Section {
            Toggle("Sync with HealthKit", isOn: $syncEnabled)
            
            if syncEnabled {
                Picker("Health Metric", selection: Binding(
                    get: { selectedMetric },
                    set: { newMetric in
                        handleMetricSelection(newMetric)
                    }
                )) {
                    Text("None").tag(HealthKitMetric?.none)
                    ForEach(HealthKitMetric.allCases) { metric in
                        Label {
                            HStack {
                                Text(metric.displayName)
                                Spacer()
                                if metric.supportsWrite {
                                    Text("Read & Write")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Read")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: metric.symbolName)
                        }
                        .tag(HealthKitMetric?.some(metric))
                    }
                }
                
                if let selectedMetric {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedMetric.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Show read/write capability
                        if selectedMetric.supportsWrite {
                            Label {
                                Text("Sessions will be saved to Health")
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
                    
                    // Show authorization status
                    if healthKitManager.isHealthKitAvailable && healthKitManager.isAuthorized(for: selectedMetric) {
                        Label {
                            Text("HealthKit Authorized")
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .font(.caption)
                        
                        // Show import goal button for Activity Ring metrics
                        if selectedMetric.supportsActivityGoalImport {
                            Button(action: importActivityGoal) {
                                HStack {
                                    if isLoadingGoals {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    Text("Import Daily Goal from Health")
                                }
                            }
                            .disabled(isLoadingGoals)
                            .buttonStyle(.bordered)
                            
                            if showingGoalImportSuccess {
                                Label("Goal imported successfully", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("HealthKit Integration")
        } footer: {
            if syncEnabled {
                Text("Time tracked in HealthKit will be automatically added to your goal progress.")
            }
        }
    }
    
    private func handleMetricSelection(_ newMetric: HealthKitMetric?) {
        // Simply set the metric
        selectedMetric = newMetric
        
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
