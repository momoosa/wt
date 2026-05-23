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
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestions List
            List {
                ForEach(category.suggestions) { suggestion in
                    SuggestionRow(
                        suggestion: suggestion,
                        isSelected: selectedTemplate?.id == suggestion.id,
                        themePreset: category.themePreset
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

