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
                        ContentUnavailableView(
                            "No Tags",
                            systemImage: "tag.slash",
                            description: Text("Tags will appear here once you add goals.")
                        )
                        .padding(.top, 40)
                    } else {
                        // Tags grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Tags")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            TagFlowLayout(spacing: 8) {
                                ForEach(allTags, id: \.id) { tag in
                                    ThemeTagButton(
                                        tag: tag,
                                        isSelected: selectedTags.contains(where: { $0.id == tag.id }),
                                        action: {
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
