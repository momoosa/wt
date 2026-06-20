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
    @State private var showingPremiumPaywall = false
    
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
                    if suggestion.isPremium == true && !SubscriptionManager.shared.isSubscribed {
                        showingPremiumPaywall = true
                    } else {
                        withAnimation(AnimationPresets.quickSpring) {
                            selectedTemplate = suggestion
                            userInput = suggestion.title
                        }
                        HapticFeedbackManager.trigger(.light)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallSheet()
        }
    }
}


