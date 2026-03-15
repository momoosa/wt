//
//  HealthKitMetricsBrowserView.swift
//  Momentum
//
//  Created by Mo Moosa on 15/03/2026.
//

import SwiftUI
import MomentumKit

/// A dedicated browser for exploring and selecting HealthKit metrics
struct HealthKitMetricsBrowserView: View {
    @Binding var selectedMetric: HealthKitMetric?
    var currentGoal: Goal? // The goal being edited (to exclude from "in use" check)
    
    @Environment(\.dismiss) private var dismiss
    @Environment(GoalStore.self) private var goalStore
    @State private var healthKitManager = HealthKitManager()
    @State private var searchText = ""
    
    private var filteredMetrics: [HealthKitMetric] {
        if searchText.isEmpty {
            return HealthKitMetric.allCases
        }
        return HealthKitMetric.allCases.filter { metric in
            metric.displayName.localizedCaseInsensitiveContains(searchText) ||
            metric.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var readWriteMetrics: [HealthKitMetric] {
        filteredMetrics.filter { $0.supportsWrite }
    }
    
    private var readOnlyMetrics: [HealthKitMetric] {
        filteredMetrics.filter { !$0.supportsWrite }
    }
    
    /// Find the goal using this metric (excluding the current goal being edited)
    private func goalUsing(_ metric: HealthKitMetric) -> Goal? {
        goalStore.goals.first { goal in
            goal.id != currentGoal?.id &&
            goal.healthKitSyncEnabled &&
            goal.healthKitMetric == metric
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !readWriteMetrics.isEmpty {
                    Section {
                        ForEach(readWriteMetrics) { metric in
                            MetricRow(
                                metric: metric,
                                isSelected: selectedMetric == metric,
                                isAuthorized: healthKitManager.isAuthorized(for: metric),
                                usedByGoal: goalUsing(metric)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMetric = metric
                                dismiss()
                            }
                        }
                    } header: {
                        Label("Read & Write", systemImage: "arrow.left.arrow.right")
                    } footer: {
                        Text("These metrics can be tracked directly in Momentum and saved to Health.")
                    }
                }
                
                if !readOnlyMetrics.isEmpty {
                    Section {
                        ForEach(readOnlyMetrics) { metric in
                            MetricRow(
                                metric: metric,
                                isSelected: selectedMetric == metric,
                                isAuthorized: healthKitManager.isAuthorized(for: metric),
                                usedByGoal: goalUsing(metric)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMetric = metric
                                dismiss()
                            }
                        }
                    } header: {
                        Label("Read Only", systemImage: "eye")
                    } footer: {
                        Text("These metrics are tracked by your Apple Watch or other apps and can only be read by Momentum.")
                    }
                }
                
                if filteredMetrics.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search metrics")
            .navigationTitle("Health Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Individual metric row with detailed information
private struct MetricRow: View {
    let metric: HealthKitMetric
    let isSelected: Bool
    let isAuthorized: Bool
    let usedByGoal: Goal?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: metric.symbolName)
                .font(.title2)
                .foregroundStyle(metric.supportsWrite ? .blue : .secondary)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(metric.displayName)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                
                Text(metric.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // Capability badges
                HStack(spacing: 8) {
                    // Read/Write badge
                    if metric.supportsWrite {
                        CapabilityBadge(
                            icon: "arrow.up.doc",
                            text: "Can Write",
                            color: .blue
                        )
                    } else {
                        CapabilityBadge(
                            icon: "eye",
                            text: "Read Only",
                            color: .secondary
                        )
                    }
                    
                    // Activity goal import badge
                    if metric.supportsActivityGoalImport {
                        CapabilityBadge(
                            icon: "target",
                            text: "Activity Goal",
                            color: .green
                        )
                    }
                    
                    // Authorization badge
                    if isAuthorized {
                        CapabilityBadge(
                            icon: "checkmark.shield",
                            text: "Authorized",
                            color: .green
                        )
                    }
                    
                    // In use badge
                    if let goal = usedByGoal {
                        CapabilityBadge(
                            icon: "link",
                            text: "Used by \(goal.title)",
                            color: .orange
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Small badge for metric capabilities
private struct CapabilityBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        Label {
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        } icon: {
            Image(systemName: icon)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview("Browser") {
    HealthKitMetricsBrowserView(
        selectedMetric: .constant(.mindfulMinutes),
        currentGoal: nil
    )
    .environment(GoalStore())
}

#Preview("Browser - No Selection") {
    HealthKitMetricsBrowserView(
        selectedMetric: .constant(nil),
        currentGoal: nil
    )
    .environment(GoalStore())
}
