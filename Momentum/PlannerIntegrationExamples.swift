//
//  PlannerIntegrationExamples.swift
//  MomentumKit
//
//  Created by Mo Moosa on 17/01/2026.
//

import SwiftUI
import SwiftData
import MomentumKit
// MARK: - Example 1: Simple Planner Integration

/// Shows how to integrate the planner into your main content view
struct MainViewWithPlanner: View {
    @Query private var goals: [Goal]
    @State private var showPlanner = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Your existing content
                Text("Your App Content Here")
                
                // Planner Button
                Button {
                    showPlanner = true
                } label: {
                    Label("Open Daily Planner", systemImage: "calendar.badge.clock")
                }
            }
            .sheet(isPresented: $showPlanner) {
                DailyPlannerView()
            }
        }
    }
}

// MARK: - Example 2: Inline Plan Summary

/// Shows a compact plan summary that can be embedded in any view
struct PlanSummaryCard: View {
    @StateObject private var planner = GoalSessionPlanner()
    let goals: [Goal]
    let goalSessions: [GoalSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Plan", systemImage: "sparkles")
                    .font(.headline)
                
                Spacer()
                
                if planner.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let plan = planner.currentPlan {
                VStack(spacing: 8) {
                    ForEach(plan.sessions.prefix(3)) { session in
                        HStack {
                            Text(session.recommendedStartTime)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            Text(session.goalTitle)
                                .font(.callout)
                            
                            Spacer()
                            
                            Text("\(session.suggestedDuration)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if plan.sessions.count > 3 {
                        Text("+\(plan.sessions.count - 3) more sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Button {
                    Task {
                        try? await planner.generateDailyPlan(
                            for: goals,
                            goalSessions: goalSessions
                        )
                    }
                } label: {
                    Label("Generate Plan", systemImage: "wand.and.stars")
                        .font(.callout)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .task {
            // Auto-generate on appear
            guard planner.currentPlan == nil else { return }
            try? await planner.generateDailyPlan(
                for: goals,
                goalSessions: goalSessions
            )
        }
    }
}

// MARK: - Example 3: Streaming Plan Generation

/// Demonstrates real-time streaming plan generation with partial updates
struct StreamingPlannerView: View {
    @StateObject private var planner = GoalSessionPlanner()
    let goals: [Goal]
    let goalSessions: [GoalSession]
    
    @State private var partialPlan: DailyPlan.PartiallyGenerated?
    @State private var isStreaming = false
    
    var body: some View {
        VStack(spacing: 16) {
            if isStreaming {
                Text("Generating plan...")
                    .font(.headline)
                
                ProgressView()
                
                // Show partial results as they stream in
                if let partial = partialPlan,
                   let sessions = partial.sessions {
                    VStack(spacing: 8) {
                        ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                            HStack {
                                Text(session.recommendedStartTime ?? "Unknown start time")
                                Text(session.goalTitle ?? "Unknown session")
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            } else {
                Button("Generate Plan with Streaming") {
                    Task {
                        await generateStreamingPlan()
                    }
                }
            }
        }
    }
    
    private func generateStreamingPlan() async {
        isStreaming = true
        defer { isStreaming = false }
        
        let stream = planner.streamDailyPlan(
            for: goals,
            goalSessions: goalSessions
        )
        
        do {
            for try await partial in stream {
                partialPlan = partial
                
                // Update UI in real-time as data streams in
                print("Received partial update: \(partial.sessions?.count ?? 0) sessions")
            }
        } catch {
            print("Streaming error: \(error)")
        }
    }
}

// MARK: - Example 4: Custom Planner with Filters

/// Shows how to create a filtered plan (e.g., only wellness goals)
struct FilteredPlannerView: View {
    @StateObject private var planner = GoalSessionPlanner()
    let allGoals: [Goal]
    let goalSessions: [GoalSession]
    
    @State private var selectedTheme: String = "Wellness"
    
    var filteredGoals: [Goal] {
        allGoals.filter { $0.primaryTag.title == selectedTheme }
    }
    
    var body: some View {
        VStack {
            Picker("Theme", selection: $selectedTheme) {
                Text("Wellness").tag("Wellness")
                Text("Fitness").tag("Fitness")
                Text("Learning").tag("Learning")
                Text("Creative").tag("Creative")
            }
            .pickerStyle(.segmented)
            .padding()
            
            if let plan = planner.currentPlan {
                List(plan.sessions) { session in
                    VStack(alignment: .leading) {
                        Text(session.goalTitle)
                            .font(.headline)
                        Text("\(session.recommendedStartTime) • \(session.suggestedDuration) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onChange(of: selectedTheme) { _, _ in
            Task { await updatePlan() }
        }
        .task {
            await updatePlan()
        }
    }
    
    private func updatePlan() async {
        try? await planner.generateDailyPlan(
            for: filteredGoals,
            goalSessions: goalSessions.filter { session in
                filteredGoals.contains { $0.id == session.goal.id }
            }
        )
    }
}

// MARK: - Example 5: Planner with Custom Preferences

/// Shows how to create a planner with specific user preferences
struct CustomPreferencePlannerView: View {
    @StateObject private var planner = GoalSessionPlanner()
    let goals: [Goal]
    let goalSessions: [GoalSession]
    
    var body: some View {
        VStack {
            Text("Morning-Focused Deep Work Plan")
                .font(.title2)
                .fontWeight(.bold)
            
            if let plan = planner.currentPlan {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(plan.sessions) { session in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.goalTitle)
                                        .font(.headline)
                                    Text(session.reasoning)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(session.recommendedStartTime)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            // Generate plan with custom preferences
            let preferences = PlannerPreferences(
                planningHorizon: .remainingDay,
                preferMorningSessions: true,
                avoidEveningSessions: true,
                maxSessionsPerDay: 3,
                minimumBreakMinutes: 30,
                focusMode: .deepWork
            )
            
            try? await planner.generateDailyPlan(
                for: goals,
                goalSessions: goalSessions,
                userPreferences: preferences
            )
        }
    }
}

// MARK: - Example 6: Widget-Ready Plan Summary

/// A compact view suitable for widgets or complications
struct CompactPlanView: View {
    let plan: DailyPlan
    
    var nextSession: PlannedSession? {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return plan.sessions.first { session in
            if let sessionTime = formatter.date(from: session.recommendedStartTime) {
                let calendar = Calendar.current
                let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
                let sessionComponents = calendar.dateComponents([.hour, .minute], from: sessionTime)
                
                if let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }),
                   let sessionMinutes = sessionComponents.hour.map({ $0 * 60 + (sessionComponents.minute ?? 0) }) {
                    return sessionMinutes >= nowMinutes
                }
            }
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if let next = nextSession {
                Text("Next: \(next.goalTitle)")
                    .font(.headline)
                Text("\(next.recommendedStartTime) • \(next.suggestedDuration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Main View with Planner") {
    MainViewWithPlanner()
        .modelContainer(for: Goal.self, inMemory: true)
}

#Preview("Streaming Planner") {
    StreamingPlannerView(goals: [], goalSessions: [])
}
