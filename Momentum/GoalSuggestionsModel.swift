//
//  GoalSuggestionsModel.swift
//  Momentum
//
//  Created by Assistant on 17/01/2026.
//

import Foundation
import SwiftUI
import OSLog
import MomentumKit

// MARK: - Root Model

struct GoalSuggestionsData: Codable {
    let featured: [String]?
    let categories: [GoalCategory]
    
    var featuredSuggestions: [(suggestion: GoalTemplateSuggestion, category: GoalCategory)] {
        guard let ids = featured else { return [] }
        return ids.compactMap { id in
            for category in categories {
                if let suggestion = category.suggestions.first(where: { $0.id == id }) {
                    return (suggestion, category)
                }
            }
            return nil
        }
    }
}

// MARK: - Category Model

struct GoalCategory: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let suggestions: [GoalTemplateSuggestion]
    
    var themePreset: ThemePreset {
        ThemeStore.presets.first(where: { $0.id == color }) ?? ThemeStore.defaultPreset
    }
    
    func colorValue(for scheme: ColorScheme) -> Color {
        themePreset.color(for: scheme)
    }
}

// MARK: - Suggestion Model

struct GoalTemplateSuggestion: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let duration: Int // in minutes
    let dailyGoal: Bool? // true = distribute across all 7 days, false/nil = weekdays only (Mon-Fri)
    let healthKitMetric: String? // raw value of HealthKitMetric or null
    let icon: String
    let goalType: String? // "time", "count", "calories", or "screentime"
    let primaryMetricTarget: Double? // daily target for count/calorie goals
    let isPremium: Bool? // true = requires premium subscription
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
        
        // Load from MomentumKit bundle
        guard let url = ThemeStore.bundle.url(forResource: "GoalSuggestions", withExtension: "json") else {
            AppLogger.app.error("Could not find GoalSuggestions.json")
            return GoalSuggestionsData(featured: nil, categories: [])
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let suggestionsData = try decoder.decode(GoalSuggestionsData.self, from: data)
            cachedData = suggestionsData
            AppLogger.app.info("Loaded \(suggestionsData.categories.count) goal categories")
            return suggestionsData
        } catch {
            AppLogger.app.error("Failed to decode GoalSuggestions.json: \(error)")
            return GoalSuggestionsData(featured: nil, categories: [])
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
