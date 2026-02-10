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
    
    @State private var goalToDelete: Goal?
    @State private var showingDeleteConfirmation = false
    
    var activeGoals: [Goal] {
        goals.filter { $0.status == .active }
    }
    
    var archivedGoals: [Goal] {
        goals.filter { $0.status == .archived }
    }
    
    // Group active goals by theme
    var activeGoalsByTheme: [(theme: GoalTag, goals: [Goal])] {
        let grouped = Dictionary(grouping: activeGoals) { $0.primaryTag.themeID }
        return grouped.map { (themeID, goals) in
            // Use the first goal's tag as representative
            let theme = goals.first!.primaryTag
            return (theme, goals.sorted { $0.title < $1.title })
        }
        .sorted { $0.theme.title < $1.theme.title }
    }
    
    // Group archived goals by theme
    var archivedGoalsByTheme: [(theme: GoalTag, goals: [Goal])] {
        let grouped = Dictionary(grouping: archivedGoals) { $0.primaryTag.themeID }
        return grouped.map { (themeID, goals) in
            let theme = goals.first!.primaryTag
            return (theme, goals.sorted { $0.title < $1.title })
        }
        .sorted { $0.theme.title < $1.theme.title }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !activeGoals.isEmpty {
                    ForEach(activeGoalsByTheme, id: \.theme.themeID) { themeGroup in
                        Section {
                            ForEach(themeGroup.goals) { goal in
                                GoalRow(goal: goal)
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
                                    .fill(themeGroup.theme.themePreset.light)
                                    .frame(width: 8, height: 8)
                                Text(themeGroup.theme.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                if !archivedGoals.isEmpty {
                    ForEach(archivedGoalsByTheme, id: \.theme.themeID) { themeGroup in
                        Section {
                            ForEach(themeGroup.goals) { goal in
                                GoalRow(goal: goal)
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
                                    .fill(themeGroup.theme.themePreset.light.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                Text("\(themeGroup.theme.title) (Archived)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
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
