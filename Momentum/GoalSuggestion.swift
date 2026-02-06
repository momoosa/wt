//
//  GoalSuggestion.swift
//  Momentum
//
//  Created by Mo Moosa on 10/08/2025.
//

import Foundation
import FoundationModels

@Generable struct GoalSuggestion: Identifiable, Equatable {
    let id: String = UUID().uuidString
    @Guide(description: "Short title for the goal suggestion.")
    let title: String
    
    @Guide(description: "Short description for the goal suggestion, including benefits based on the user's input")
    let subtitle: String
    
    @Guide(description: "Detailed description for the goal suggestion.")
    let description: String
    @Guide(description: "Themes/categories you could use for this goal suggestion, e.g. 'Fitness', 'Learning', 'Leisure'.")
    let themes: [String]
    let recommendedDurationInMinutes: Int
}
