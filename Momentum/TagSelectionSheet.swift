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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isCreatingNewTag = false
    @State private var newTagName = ""
    @State private var selectedThemePreset: ThemePreset? = nil
    @FocusState private var isNewTagNameFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Create new tag section
                    if isCreatingNewTag {
                        newTagCreationSection
                    }
                    
                    if allTags.isEmpty && !isCreatingNewTag {
                        ContentUnavailableView(
                            "No Tags",
                            systemImage: "tag.slash",
                            description: Text("Create a new tag to get started.")
                        )
                        .padding(.top, 40)
                    } else if !allTags.isEmpty {
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
                ToolbarItem(placement: .cancellationAction) {
                    if !isCreatingNewTag {
                        Button("New Tag") {
                            withAnimation(AnimationPresets.quickSpring) {
                                isCreatingNewTag = true
                                selectedThemePreset = ThemeStore.presets.first
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isNewTagNameFocused = true
                            }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - New Tag Creation
    
    private var newTagCreationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Tag")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(AnimationPresets.quickSpring) {
                        isCreatingNewTag = false
                        newTagName = ""
                        selectedThemePreset = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .focused($isNewTagNameFocused)
                .padding(.horizontal)
                .onSubmit {
                    createNewTag()
                }
            
            // Theme color grid
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(ThemeStore.presets, id: \.id) { preset in
                        let isSelected = selectedThemePreset?.id == preset.id
                        Button {
                            selectedThemePreset = preset
                            HapticFeedbackManager.trigger(.light)
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: preset.colors(for: colorScheme),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(isSelected ? preset.color(for: colorScheme) : .clear, lineWidth: 2.5)
                                        .padding(-3)
                                )
                                .scaleEffect(isSelected ? 1.15 : 1.0)
                                .animation(AnimationPresets.quickSpring, value: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            Button {
                createNewTag()
            } label: {
                HStack {
                    Spacer()
                    Label("Create Tag", systemImage: "plus.circle.fill")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(canCreateTag ? (selectedThemePreset?.color(for: colorScheme) ?? .accentColor) : Color(.systemGray4))
                )
                .foregroundStyle(canCreateTag ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canCreateTag)
            .padding(.horizontal)
            
            Divider()
                .padding(.top, 4)
        }
        .padding(.top)
    }
    
    private var canCreateTag: Bool {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && selectedThemePreset != nil
    }
    
    private func createNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let preset = selectedThemePreset else { return }
        
        // Reuse existing tag with same name if one exists
        if let existing = allTags.first(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            withAnimation(AnimationPresets.quickSpring) {
                if !selectedTags.contains(where: { $0.id == existing.id }) {
                    selectedTags.append(existing)
                }
                if selectedGoalTheme == nil {
                    selectedGoalTheme = existing
                }
                newTagName = ""
                selectedThemePreset = ThemeStore.presets.first
                isCreatingNewTag = false
            }
            HapticFeedbackManager.trigger(.success)
            return
        }
        
        let newTag = GoalTag(title: trimmed, themeID: preset.id)
        modelContext.insert(newTag)
        
        // Auto-select the newly created tag
        withAnimation(AnimationPresets.quickSpring) {
            selectedTags.append(newTag)
            if selectedGoalTheme == nil {
                selectedGoalTheme = newTag
            }
            
            // Reset creation state
            newTagName = ""
            selectedThemePreset = ThemeStore.presets.first
            isCreatingNewTag = false
        }
        
        HapticFeedbackManager.trigger(.success)
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
