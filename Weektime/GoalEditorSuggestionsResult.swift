//
//  GoalEditorSuggestionsResult.swift
//  Weektime
//
//  Created by Mo Moosa on 10/08/2025.
//

import Foundation
import FoundationModels

@Generable struct GoalEditorSuggestionsResult: Equatable {
    let id: String = UUID().uuidString
    let suggestions: [GoalSuggestion]
}
