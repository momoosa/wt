//
//  AllGoalsView.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct AllGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let goals: [Goal]
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var goalToDelete: Goal?
    @State private var showingDeleteConfirmation = false
    @State private var selectedGoal: Goal?
    
    var activeGoals: [Goal] {
        goals.filter { $0.status == .active }
    }
    
    var archivedGoals: [Goal] {
        goals.filter { $0.status == .archived }
    }
    
    /// Grouping key — uses the tag/theme title so goals with the same tag name
    /// (e.g. "General") merge into one section even if their palette IDs differ.
    private func effectiveGroupName(for goal: Goal) -> String {
        goal.primaryTag?.title ?? goal.resolvedTheme.title
    }
    
    /// Groups goals by their tag/theme title, returning a display-friendly tuple.
    private func groupByTheme(_ source: [Goal]) -> [(title: String, theme: ThemePreset, goals: [Goal])] {
        let grouped = Dictionary(grouping: source) { effectiveGroupName(for: $0) }
        return grouped.map { (title, goals) in
            let theme = goals.first?.resolvedTheme ?? ThemeStore.defaultPreset
            return (title, theme, goals.sorted { $0.title < $1.title })
        }
        .sorted { $0.title < $1.title }
    }
    
    // Group active goals by theme
    var activeGoalsByTheme: [(title: String, theme: ThemePreset, goals: [Goal])] {
        groupByTheme(activeGoals)
    }
    
    // Group archived goals by theme
    var archivedGoalsByTheme: [(title: String, theme: ThemePreset, goals: [Goal])] {
        groupByTheme(archivedGoals)
    }
    
    var body: some View {
        NavigationStack {
            List {
                activeGoalsSection
                archivedGoalsSection
                
                if goals.isEmpty {
                    ContentUnavailableView(
                        "No Goals",
                        systemImage: "target",
                        description: Text("Create your first goal to get started")
                    )
                }
            }
            .navigationTitle("All Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete Goal",
                isPresented: $showingDeleteConfirmation,
                presenting: goalToDelete
            ) { goal in
                Button("Delete \"\(goal.title)\"", role: .destructive) {
                    deleteGoal(goal)
                }
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
            } message: { goal in
                Text("Are you sure you want to delete \"\(goal.title)\"? This action cannot be undone.")
            }
            .navigationDestination(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal)
            }
        }
    }
    
    @ViewBuilder
    private var activeGoalsSection: some View {
        if !activeGoals.isEmpty {
            ForEach(activeGoalsByTheme, id: \.title) { themeGroup in
                Section {
                    ForEach(themeGroup.goals) { goal in
                        Button {
                            selectedGoal = goal
                        } label: {
                            GoalRow(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                goalToDelete = goal
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(themeGroup.theme.color(for: colorScheme))
                            .frame(width: 8, height: 8)
                        Text(themeGroup.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var archivedGoalsSection: some View {
        if !archivedGoals.isEmpty {
            ForEach(archivedGoalsByTheme, id: \.title) { themeGroup in
                Section {
                    ForEach(themeGroup.goals) { goal in
                        Button {
                            selectedGoal = goal
                        } label: {
                            GoalRow(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                goalToDelete = goal
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(themeGroup.theme.color(for: colorScheme).opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text("\(themeGroup.title) (Archived)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func deleteGoal(_ goal: Goal) {
        withAnimation {
            // Use GoalManager for proper deletion
            GoalManager.delete(goal, from: modelContext)
            goalToDelete = nil
        }
    }
}
