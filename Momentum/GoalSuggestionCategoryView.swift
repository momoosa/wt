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
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(category.suggestions) { suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isSelected: selectedTemplate?.id == suggestion.id,
                    themePreset: category.themePreset
                )
                .onTapGesture {
                    withAnimation(AnimationPresets.quickSpring) {
                        selectedTemplate = suggestion
                        userInput = suggestion.title
                    }
                    HapticFeedbackManager.trigger(.light)
                }
            }
        }
    }
}


