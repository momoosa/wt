//
//  HealthKitInfoRow.swift
//  Weektime
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import WeektimeKit
import SwiftData

struct HealthKitInfoRow: View {
    let session: GoalSession
    
    var body: some View {
        if session.goal.healthKitSyncEnabled, let metric = session.goal.healthKitMetric {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(.red)
                    Text("HealthKit Integration")
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Metric")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: metric.symbolName)
                                .font(.caption)
                            Text(metric.displayName)
                                .font(.subheadline)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("HealthKit Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Duration.seconds(session.healthKitTime).formatted(.time(pattern: .hourMinute)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                
                // Breakdown
                VStack(spacing: 6) {
                    HStack {
                        Text("Manual Tracking")
                        Spacer()
                        let manualTime = session.historicalSessions.reduce(0) { $0 + $1.duration }
                        Text(Duration.seconds(manualTime).formatted(.time(pattern: .hourMinute)))
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("HealthKit Data")
                        Spacer()
                        Text(Duration.seconds(session.healthKitTime).formatted(.time(pattern: .hourMinute)))
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    Divider()
                    
                    HStack {
                        Text("Total Time")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(Duration.seconds(session.elapsedTime).formatted(.time(pattern: .hourMinute)))
                            .fontWeight(.semibold)
                    }
                    .font(.callout)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Goal.self, GoalSession.self, Day.self, configurations: config)
    
    let theme = GoalTheme(title: "Health", color: themes.first!)
    let goal = Goal(
        title: "Exercise",
        primaryTheme: theme,
        weeklyTarget: 210 * 60,
        healthKitMetric: .appleExerciseTime,
        healthKitSyncEnabled: true
    )
    let day = Day(start: Date().startOfDay()!, end: Date().endOfDay()!)
    let session = GoalSession(title: "Exercise", goal: goal, day: day)
    session.updateHealthKitTime(1200) // 20 minutes from HealthKit
    
    return HealthKitInfoRow(session: session)
        .padding()
        .modelContainer(container)
}
