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
    @Binding var secondaryMetrics: [HealthKitMetric]
    @Binding var secondaryMetricTargets: [String: Double]
    var currentGoal: Goal? = nil
    
    @State private var healthKitManager = HealthKitManager()
    @State private var isLoadingGoals = false
    @State private var showingGoalImportSuccess = false
    @State private var showingSecondaryMetricPicker = false
    
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
        
        // Secondary Metrics Section
        if selectedMetric != nil {
            Section {
                ForEach(secondaryMetrics, id: \.rawValue) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label {
                                Text(metric.displayName)
                            } icon: {
                                Image(systemName: metric.symbolName)
                            }
                            
                            Spacer()
                            
                            Button {
                                removeSecondaryMetric(metric)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Daily Target:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("Target", value: Binding(
                                get: { secondaryMetricTargets[metric.rawValue] ?? 10000 },
                                set: { secondaryMetricTargets[metric.rawValue] = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            
                            Text(metric.unit == .count() ? "count" : "min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Button {
                    showingSecondaryMetricPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Secondary Metric")
                    }
                }
            } header: {
                Text("Secondary Metrics")
            } footer: {
                Text("Track additional metrics alongside your primary time-based goal (e.g., steps during a walk).")
            }
        }
        }
        .sheet(isPresented: $showingSecondaryMetricPicker) {
            secondaryMetricPickerSheet
        }
    }
    
    private func removeSecondaryMetric(_ metric: HealthKitMetric) {
        secondaryMetrics.removeAll { $0 == metric }
        secondaryMetricTargets.removeValue(forKey: metric.rawValue)
    }
    
    private var secondaryMetricPickerSheet: some View {
        NavigationStack {
            List {
                // Only show count-based metrics for secondary tracking
                let countMetrics: [HealthKitMetric] = [.stepCount]
                
                ForEach(countMetrics, id: \.rawValue) { metric in
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.displayName)
                                Text(metric.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: metric.symbolName)
                        }
                        
                        Spacer()
                        
                        if secondaryMetrics.contains(metric) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !secondaryMetrics.contains(metric) {
                            secondaryMetrics.append(metric)
                            // Set default target based on metric
                            switch metric {
                            case .stepCount:
                                secondaryMetricTargets[metric.rawValue] = 10000
                            default:
                                secondaryMetricTargets[metric.rawValue] = 100
                            }
                            
                            // Request authorization
                            Task {
                                try? await healthKitManager.requestAuthorization(for: [metric])
                            }
                            
                            // Don't dismiss - allow adding multiple metrics
                        }
                    }
                }
            }
            .navigationTitle("Add Secondary Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSecondaryMetricPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingSecondaryMetricPicker = false
                    }
                    .fontWeight(.semibold)
                }
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
                dailyTargetMinutes: .constant(30),
                secondaryMetrics: .constant([]),
                secondaryMetricTargets: .constant([:])
            )
        }
    }
}
