//
//  HealthKitConfigurationView.swift
//  Weektime
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import WeektimeKit

struct HealthKitConfigurationView: View {
    @Binding var selectedMetric: HealthKitMetric?
    @Binding var syncEnabled: Bool
    @State private var healthKitManager = HealthKitManager()
    
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
                            Text(metric.displayName)
                        } icon: {
                            Image(systemName: metric.symbolName)
                        }
                        .tag(HealthKitMetric?.some(metric))
                    }
                }
                
                if let selectedMetric {
                    Text(selectedMetric.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
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
}

#Preview {
    NavigationStack {
        Form {
            HealthKitConfigurationView(
                selectedMetric: .constant(.appleExerciseTime),
                syncEnabled: .constant(true)
            )
        }
    }
}
