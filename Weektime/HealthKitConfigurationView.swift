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
    @State private var showingAuthorizationAlert = false
    @State private var authorizationError: Error?
    
    var body: some View {
        Section {
            Toggle("Sync with HealthKit", isOn: $syncEnabled)
            
            if syncEnabled {
                Picker("Health Metric", selection: $selectedMetric) {
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
                    
                    // Show authorize button only if this specific metric isn't authorized
                    if healthKitManager.isHealthKitAvailable && !healthKitManager.isAuthorized(for: selectedMetric) {
                        Button {
                            requestHealthKitAuthorization()
                        } label: {
                            Label("Authorize HealthKit", systemImage: "heart.text.square.fill")
                        }
                    } else if healthKitManager.isAuthorized(for: selectedMetric) {
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
        .alert("HealthKit Authorization", isPresented: $showingAuthorizationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = authorizationError {
                Text(error.localizedDescription)
            } else {
                Text("HealthKit access granted successfully!")
            }
        }
    }
    
    private func requestHealthKitAuthorization() {
        guard let selectedMetric else { return }
        
        Task {
            do {
                try await healthKitManager.requestAuthorization(for: [selectedMetric])
                await MainActor.run {
                    // Force a refresh by creating a new manager instance
                    // This will trigger the UI to re-evaluate authorization status
                    healthKitManager = HealthKitManager()
                    showingAuthorizationAlert = true
                }
            } catch {
                await MainActor.run {
                    authorizationError = error
                    showingAuthorizationAlert = true
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
