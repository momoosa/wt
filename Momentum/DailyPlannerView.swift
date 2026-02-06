//
//  DailyPlannerView.swift
//  MomentumKit
//
//  Created by Mo Moosa on 17/01/2026.
//

import SwiftUI
import SwiftData
import FoundationModels
import MomentumKit

struct DailyPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var planner = GoalSessionPlanner()
    
    @Query private var activeGoals: [Goal]
    
    @State private var selectedDate: Date = Date()
    @State private var preferences: PlannerPreferences = .default
    @State private var showPreferences: Bool = false
    @State private var expandedSessionIds: Set<String> = []
    @State private var errorMessage: String?
    
    init() {
        let activeStatus = Goal.Status.active
        _activeGoals = Query(
            filter: #Predicate<Goal> { goal in
                goal.status == activeStatus
            },
            sort: \.title
        )
    }
    
    var goalSessions: [GoalSession] {
        // Mock - in real app, query actual GoalSession objects for selected date
        // This would typically come from a @Query or be passed in
        return []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Picker Header
                datePickerHeader
                
                // Plan Content
                if planner.isGenerating {
                    generatingView
                } else if let errorMessage {
                    errorStateView(message: errorMessage)
                } else if let plan = planner.currentPlan {
                    planContentView(plan: plan)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Daily Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showPreferences = true
                        } label: {
                            Label("Preferences", systemImage: "slider.horizontal.3")
                        }
                        
                        Button {
                            Task { await generatePlan() }
                        } label: {
                            Label("Regenerate Plan", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showPreferences) {
                PlannerPreferencesView(preferences: $preferences)
            }
        }
        .task {
            await generatePlan()
        }
    }
    
    // MARK: - Subviews
    
    private var datePickerHeader: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                Task { await generatePlan() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                    .font(.headline)
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                Task { await generatePlan() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Planning your day...")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Analyzing goals and schedules")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(.purple.gradient)
            
            Text("No Plan Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the button below to generate an AI-powered daily plan based on your goals and preferences.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task { await generatePlan() }
            } label: {
                Label("Generate Plan", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.purple.gradient)
                    )
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange.gradient)
            
            Text("Unable to Generate Plan")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                errorMessage = nil
                Task { await generatePlan() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.orange.gradient)
                    )
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func planContentView(plan: DailyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overall Strategy
                if let strategy = plan.overallStrategy {
                    strategyCard(strategy: strategy)
                }
                
                // Session Timeline
                VStack(spacing: 12) {
                    ForEach(plan.sessions) { session in
                        PlannedSessionCard(
                            session: session,
                            isExpanded: expandedSessionIds.contains(session.id)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedSessionIds.contains(session.id) {
                                    expandedSessionIds.remove(session.id)
                                } else {
                                    expandedSessionIds.insert(session.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    private func strategyCard(strategy: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Today's Strategy", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.purple)
            
            Text(strategy)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func generatePlan() async {
        errorMessage = nil // Clear any previous errors
        
        do {
            _ = try await planner.generateDailyPlan(
                for: activeGoals,
                goalSessions: goalSessions,
                currentDate: selectedDate,
                userPreferences: preferences
            )
        } catch {
            print("Failed to generate plan: \(error)")
            
            // Handle Foundation Models availability errors gracefully
            if error.localizedDescription.contains("no underlying assets") || 
               error.localizedDescription.contains("underlying assets") {
                errorMessage = "Apple Intelligence is not available on this device or simulator. The AI planner requires a physical device with Apple Intelligence support (iPhone 15 Pro or later with iOS 18.1+)."
            } else {
                errorMessage = "An error occurred while generating your plan. Please try again."
            }
        }
    }
}

// MARK: - Planned Session Card

struct PlannedSessionCard: View {
    let session: PlannedSession
    let isExpanded: Bool
    let onTap: () -> Void
    
    var priorityColor: Color {
        switch session.priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .blue
        case 4: return .green
        case 5: return .gray
        default: return .gray
        }
    }
    
    var priorityLabel: String {
        switch session.priority {
        case 1: return "Critical"
        case 2: return "High"
        case 3: return "Medium"
        case 4: return "Low"
        case 5: return "Optional"
        default: return "Unknown"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Content
            HStack(spacing: 12) {
                // Time
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.recommendedStartTime)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text("\(session.suggestedDuration) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, alignment: .leading)
                
                // Priority Indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
                
                // Goal Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.goalTitle)
                        .font(.headline)
                    
                    HStack {
                        Text(priorityLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(priorityColor)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text("Priority \(session.priority)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Expand/Collapse Icon
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Expanded Reasoning
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why now?")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(session.reasoning)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Action Buttons
                    HStack {
                        Button {
                            // TODO: Start session action
                        } label: {
                            Label("Start Now", systemImage: "play.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor)
                                )
                        }
                        
                        Button {
                            // TODO: Adjust time action
                        } label: {
                            Label("Adjust Time", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .strokeBorder(Color.primary, lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(priorityColor.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Preferences View

struct PlannerPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var preferences: PlannerPreferences
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Planning") {
                    Picker("Planning Horizon", selection: $preferences.planningHorizon) {
                        Text("Rest of Today").tag(PlanningHorizon.remainingDay)
                        Text("Full Day").tag(PlanningHorizon.fullDay)
                        Text("Tomorrow").tag(PlanningHorizon.nextDay)
                    }
                    
                    Picker("Focus Mode", selection: $preferences.focusMode) {
                        Text("Deep Work").tag(FocusMode.deepWork)
                        Text("Balanced").tag(FocusMode.balanced)
                        Text("Flexible").tag(FocusMode.flexible)
                    }
                }
                
                Section("Time Preferences") {
                    Toggle("Prefer Morning Sessions", isOn: $preferences.preferMorningSessions)
                    Toggle("Avoid Evening Sessions", isOn: $preferences.avoidEveningSessions)
                }
                
                Section("Session Limits") {
                    Stepper("Max Sessions Per Day: \(preferences.maxSessionsPerDay)", 
                            value: $preferences.maxSessionsPerDay, 
                            in: 1...10)
                    
                    Stepper("Minimum Break: \(preferences.minimumBreakMinutes) min", 
                            value: $preferences.minimumBreakMinutes, 
                            in: 5...60, 
                            step: 5)
                }
            }
            .navigationTitle("Planner Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyPlannerView()
        .modelContainer(for: Goal.self, inMemory: true)
}
