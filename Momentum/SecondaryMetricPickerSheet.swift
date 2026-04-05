//
//  SecondaryMetricPickerSheet.swift
//  Momentum
//
//  Created by Claude Code on 31/03/2026.
//

import SwiftUI
import MomentumKit

struct SecondaryMetricPickerSheet: View {
    @Binding var secondaryMetrics: [HealthKitMetric]
    @Binding var secondaryMetricTargets: [String: Double]
    @Binding var isPresented: Bool
    
    @State private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            List {
                // Only show count and calorie-based metrics for goal tracking
                let countMetrics: [HealthKitMetric] = [.stepCount, .activeEnergyBurned]
                
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
                        toggleMetric(metric)
                    }
                }
            }
            .navigationTitle("Add Secondary Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func toggleMetric(_ metric: HealthKitMetric) {
        if let index = secondaryMetrics.firstIndex(of: metric) {
            // Remove if already added
            secondaryMetrics.remove(at: index)
            secondaryMetricTargets.removeValue(forKey: metric.rawValue)
        } else {
            // Add the metric
            secondaryMetrics.append(metric)
            
            // Set default target based on metric
            switch metric {
            case .stepCount:
                secondaryMetricTargets[metric.rawValue] = 10000
            case .activeEnergyBurned:
                secondaryMetricTargets[metric.rawValue] = 500
            default:
                secondaryMetricTargets[metric.rawValue] = 100
            }
            
            // Request authorization
            Task { @MainActor in
                try? await healthKitManager.requestAuthorization(for: [metric])
            }
        }
    }
}
