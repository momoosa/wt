//
//  GoalSuggestion.swift
//  Weektime
//
//  Created by Mo Moosa on 10/08/2025.
//

import Foundation
import FoundationModels

@Generable struct GoalSuggestion: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let title: String
    let description: String
    let recommendedDurationInMinutes: Int
}
