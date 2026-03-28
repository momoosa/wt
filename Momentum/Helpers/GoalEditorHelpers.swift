//
//  GoalEditorHelpers.swift
//  Momentum
//
//  Created by Assistant on 28/03/2026.
//

import Foundation
import MomentumKit

// MARK: - Theme Helper

/// Helper class for theme matching and selection logic in the Goal Editor
struct GoalEditorThemeHelper {
    func matchTheme(named themeName: String) -> ThemePreset {
        let normalizedThemeName = themeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let themeMapping: [String: String] = [
            "fitness": "red",
            "wellness": "purple",
            "learning": "blue",
            "creative": "orange",
            "home": "green",
            "recreation": "yellow",
            "productivity": "teal",
            "social": "hot_pink"
        ]
        
        if let presetId = themeMapping[normalizedThemeName] {
            if let match = themePresets.first(where: { $0.id == presetId }) {
                return match
            }
        }
        
        if let exactMatch = themePresets.first(where: { $0.title.lowercased() == normalizedThemeName }) {
            return exactMatch
        }
        
        if let partialMatch = themePresets.first(where: { $0.title.lowercased().contains(normalizedThemeName) }) {
            return partialMatch
        }
        
        if let reverseMatch = themePresets.first(where: { normalizedThemeName.contains($0.title.lowercased()) }) {
            return reverseMatch
        }
        
        let themeKeywords: [String: String] = [
            "exercise": "red",
            "workout": "red",
            "run": "red",
            "gym": "red",
            "meditate": "purple",
            "yoga": "purple",
            "mindful": "purple",
            "read": "blue",
            "study": "blue",
            "learn": "blue",
            "paint": "orange",
            "draw": "orange",
            "music": "orange",
            "cook": "green",
            "garden": "green",
            "clean": "green"
        ]
        
        for (keyword, themeId) in themeKeywords {
            if normalizedThemeName.contains(keyword) {
                if let match = themePresets.first(where: { $0.id == themeId }) {
                    return match
                }
            }
        }
        
        return themePresets[0]
    }
    
    func findUnusedTheme(excluding goals: [Goal]) -> ThemePreset {
        let usedThemeIDs = Set(goals.filter { $0.status == .active }.compactMap { $0.primaryTag?.themeID })
        
        if let unusedPreset = themePresets.first(where: { !usedThemeIDs.contains($0.id) }) {
            return unusedPreset
        }
        
        return (themePresets.randomElement() ?? themePresets[0])
    }
}

// MARK: - Icon Helper

/// Helper class for icon inference logic in the Goal Editor
struct GoalEditorIconHelper {
    func inferIcon(from title: String) -> String? {
        let normalized = title.lowercased()
        
        let iconMapping: [String: String] = [
            "meditat": "figure.mind.and.body",
            "yoga": "figure.yoga",
            "run": "figure.run",
            "walk": "figure.walk",
            "exercise": "figure.strengthtraining.traditional",
            "workout": "figure.strengthtraining.traditional",
            "gym": "dumbbell.fill",
            "read": "book.fill",
            "book": "book.fill",
            "study": "book.fill",
            "learn": "graduationcap.fill",
            "write": "pencil",
            "journal": "book.closed.fill",
            "cook": "fork.knife",
            "music": "music.note",
            "paint": "paintpalette.fill",
            "draw": "pencil.tip.crop.circle",
            "code": "chevron.left.forwardslash.chevron.right",
            "program": "chevron.left.forwardslash.chevron.right",
            "sleep": "bed.double.fill",
            "water": "drop.fill",
            "hydrat": "drop.fill"
        ]
        
        for (keyword, icon) in iconMapping {
            if normalized.contains(keyword) {
                return icon
            }
        }
        
        return nil
    }
}

// MARK: - Validator

/// Helper class for goal validation logic in the Goal Editor
struct GoalEditorValidator {
    func isValidGoal(title: String, weeklyTargetMinutes: Int) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            return false
        }
        
        guard weeklyTargetMinutes > 0 else {
            return false
        }
        
        return true
    }
}

// MARK: - Calculator

/// Helper class for calculation logic in the Goal Editor
struct GoalEditorCalculator {
    func calculateWeeklyTarget(dailyMinutes: Int, activeDaysCount: Int) -> Int {
        return dailyMinutes * activeDaysCount
    }
    
    func calculateDailyTarget(weeklyMinutes: Int, activeDaysCount: Int) -> Int {
        guard activeDaysCount > 0 else {
            return 0
        }
        return weeklyMinutes / activeDaysCount
    }
}
