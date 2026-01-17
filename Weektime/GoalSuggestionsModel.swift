//
//  GoalSuggestionsModel.swift
//  Weektime
//
//  Created by Assistant on 17/01/2026.
//

import Foundation
import SwiftUI

// MARK: - Root Model

struct GoalSuggestionsData: Codable {
    let categories: [GoalCategory]
}

// MARK: - Category Model

struct GoalCategory: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let suggestions: [GoalTemplateSuggestion]
    
    var colorValue: Color {
        switch color.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "indigo": return .indigo
        case "pink": return .pink
        case "teal": return .teal
        default: return .blue
        }
    }
}

// MARK: - Suggestion Model

struct GoalTemplateSuggestion: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let duration: Int // in minutes
    let theme: String
    let healthKitMetric: String? // raw value of HealthKitMetric or null
    let icon: String
}

// MARK: - Loader

class GoalSuggestionsLoader {
    static let shared = GoalSuggestionsLoader()
    
    private var cachedData: GoalSuggestionsData?
    
    func loadSuggestions() -> GoalSuggestionsData {
        // Return cached data if available
        if let cached = cachedData {
            return cached
        }
        
        // Load from bundle
        guard let url = Bundle.main.url(forResource: "GoalSuggestions", withExtension: "json") else {
            print("❌ Could not find GoalSuggestions.json")
            return GoalSuggestionsData(categories: [])
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let suggestionsData = try decoder.decode(GoalSuggestionsData.self, from: data)
            cachedData = suggestionsData
            print("✅ Loaded \(suggestionsData.categories.count) goal categories")
            return suggestionsData
        } catch {
            print("❌ Failed to decode GoalSuggestions.json: \(error)")
            return GoalSuggestionsData(categories: [])
        }
    }
    
    // For remote loading in the future
    func loadRemoteSuggestions(from url: URL) async throws -> GoalSuggestionsData {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let suggestionsData = try decoder.decode(GoalSuggestionsData.self, from: data)
        cachedData = suggestionsData
        return suggestionsData
    }
}
