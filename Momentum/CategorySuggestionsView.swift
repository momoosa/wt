//
//  CategorySuggestionsView.swift
//  Momentum
//
//  Created by Mo Moosa on 07/04/2026.
//

import MomentumKit
import SwiftUI

struct CategorySuggestionsView: View {
    let category: GoalCategory
    @Binding var selectedTemplate: GoalTemplateSuggestion?
    @Binding var userInput: String
    
    // Helper to get category theme colors
    // Use the category's defined color to ensure consistency across all suggestions
    private var categoryThemeColor: Color {
        return category.colorValue
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestions List
            List {
                ForEach(category.suggestions) { suggestion in
                    SuggestionRow(
                        suggestion: suggestion,
                        isSelected: selectedTemplate?.id == suggestion.id,
                        categoryColor: categoryThemeColor
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        withAnimation(AnimationPresets.quickSpring) {
                            selectedTemplate = suggestion
                            userInput = suggestion.title // Prefill textfield
                        }
                        
                        // Haptic feedback
                        HapticFeedbackManager.trigger(.light)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

