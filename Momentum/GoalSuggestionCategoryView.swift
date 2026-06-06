//
//  CategorySuggestionsView.swift
//  Momentum
//
//  Created by Mo Moosa on 07/04/2026.
//

import MomentumKit
import SwiftUI

struct GoalSuggestionCategoryView: View {
    let category: GoalCategory
    @Binding var selectedTemplate: GoalTemplateSuggestion?
    @Binding var userInput: String
    
    var body: some View {
            // Suggestions List
        ScrollView(.vertical) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]) {
                ForEach(category.suggestions) { suggestion in
                    SuggestionRow(
                        suggestion: suggestion,
                        isSelected: selectedTemplate?.id == suggestion.id,
                        themePreset: category.themePreset
                    )
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
        }
    }
}


