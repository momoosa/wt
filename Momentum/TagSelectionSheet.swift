//
//  TagSelectionSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 07/04/2026.
//

import SwiftData
import SwiftUI
import MomentumKit

struct TagSelectionSheet: View {
    let allTags: [GoalTag]
    @Binding var selectedTags: [GoalTag]
    @Binding var selectedGoalTheme: GoalTag?
    let modelContext: ModelContext
    @Binding var editingTag: GoalTag?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if allTags.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "tag.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No Tags Available")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Load predefined tags or create your own")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                let predefined = GoalTag.predefinedSmartTags()
                                for tag in predefined {
                                    if !allTags.contains(where: { $0.title == tag.title }) {
                                        modelContext.insert(tag)
                                    }
                                }
                            } label: {
                                Label("Load Predefined Smart Tags", systemImage: "square.and.arrow.down")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        // Tags grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Tags")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            TagFlowLayout(spacing: 8) {
                                ForEach(allTags, id: \.id) { tag in
                                    TagButton(
                                        tag: tag,
                                        isSelected: selectedTags.contains(where: { $0.id == tag.id }),
                                        onSelect: {
                                            toggleTagSelection(tag)
                                        },
                                        onEdit: {
                                            editingTag = tag
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                let predefined = GoalTag.predefinedSmartTags()
                                for tag in predefined {
                                    if !allTags.contains(where: { $0.title == tag.title }) {
                                        modelContext.insert(tag)
                                    }
                                }
                            } label: {
                                Label("Load Predefined Smart Tags", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            // Future: Add custom tag creation button
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Add Theme")
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
    
    private func toggleTagSelection(_ tag: GoalTag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            // Deselect
            withAnimation(AnimationPresets.quickSpring) {
                selectedTags.remove(at: index)
                
                // If this was the selected theme, update it
                if selectedGoalTheme?.id == tag.id {
                    selectedGoalTheme = selectedTags.first
                }
            }
        } else {
            // Select
            withAnimation(AnimationPresets.quickSpring) {
                selectedTags.append(tag)
                
                // If no theme is selected, make this the selected theme
                if selectedGoalTheme == nil {
                    selectedGoalTheme = tag
                }
            }
        }
        
        HapticFeedbackManager.trigger(.light)
    }
}
