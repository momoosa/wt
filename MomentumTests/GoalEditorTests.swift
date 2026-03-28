//
//  GoalEditorTests.swift
//  MomentumTests
//
//  Created by Assistant on 28/03/2026.
//

import Testing
import Foundation
import SwiftData
@testable import Momentum
@testable import MomentumKit

@Suite("Goal Editor Tests")
struct GoalEditorTests {
    
    // MARK: - Helper Methods
    
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Day.self,
            GoalSession.self,
            HistoricalSession.self,
            Goal.self,
            GoalTag.self,
            ChecklistItemSession.self,
            IntervalListSession.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    private func createTestGoal(
        context: ModelContext,
        title: String = "Test Goal",
        themeID: String = "blue",
        weeklyTarget: TimeInterval = 3600
    ) -> Goal {
        let tag = GoalTag(title: "Test Tag", themeID: themeID)
        context.insert(tag)
        
        let goal = Goal(title: title, primaryTag: tag, weeklyTarget: weeklyTarget)
        context.insert(goal)
        try? context.save()
        return goal
    }
    
    // MARK: - Theme Matching Tests
    
    @Test("matchTheme returns correct theme for fitness category")
    func testMatchThemeFitness() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "Fitness")
        
        #expect(theme.id == "red")
    }
    
    @Test("matchTheme returns correct theme for wellness category")
    func testMatchThemeWellness() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "Wellness")
        
        #expect(theme.id == "purple")
    }
    
    @Test("matchTheme returns correct theme for learning category")
    func testMatchThemeLearning() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "Learning")
        
        #expect(theme.id == "blue")
    }
    
    @Test("matchTheme handles case insensitive input")
    func testMatchThemeCaseInsensitive() {
        let helper = GoalEditorThemeHelper()
        let theme1 = helper.matchTheme(named: "FITNESS")
        let theme2 = helper.matchTheme(named: "fitness")
        let theme3 = helper.matchTheme(named: "FiTnEsS")
        
        #expect(theme1.id == "red")
        #expect(theme2.id == "red")
        #expect(theme3.id == "red")
    }
    
    @Test("matchTheme handles whitespace")
    func testMatchThemeWhitespace() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "  Fitness  ")
        
        #expect(theme.id == "red")
    }
    
    @Test("matchTheme returns default for unknown theme")
    func testMatchThemeUnknown() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "UnknownCategory123")
        
        // Should return a valid theme (fallback to first theme which is "red")
        #expect(theme.id == themePresets[0].id)
    }
    
    @Test("matchTheme handles partial matches")
    func testMatchThemePartialMatch() {
        let helper = GoalEditorThemeHelper()
        
        // Should match "exercise" keyword to fitness/red
        let theme = helper.matchTheme(named: "exercise")
        #expect(theme.id == "red")
    }
    
    // MARK: - Find Unused Theme Tests
    
    @Test("findUnusedTheme returns unused theme when available")
    func testFindUnusedThemeReturnsUnused() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        // Create goals with some themes
        _ = createTestGoal(context: context, themeID: "red")
        _ = createTestGoal(context: context, themeID: "blue")
        
        let helper = GoalEditorThemeHelper()
        let allGoals = try context.fetch(FetchDescriptor<Goal>())
        let unusedTheme = helper.findUnusedTheme(excluding: allGoals.filter { $0.status == .active })
        
        // Should not return red or blue
        #expect(unusedTheme.id != "red")
        #expect(unusedTheme.id != "blue")
    }
    
    @Test("findUnusedTheme returns random when all themes used")
    func testFindUnusedThemeAllUsed() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        // Create goals with all possible themes
        for preset in themePresets {
            _ = createTestGoal(context: context, themeID: preset.id)
        }
        
        let helper = GoalEditorThemeHelper()
        let allGoals = try context.fetch(FetchDescriptor<Goal>())
        let theme = helper.findUnusedTheme(excluding: allGoals.filter { $0.status == .active })
        
        // Should return a valid theme even when all are used
        #expect(themePresets.contains(where: { $0.id == theme.id }))
    }
    
    @Test("findUnusedTheme ignores archived goals")
    func testFindUnusedThemeIgnoresArchived() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        // Create an archived goal with red theme
        let archivedGoal = createTestGoal(context: context, themeID: "red")
        archivedGoal.status = .archived
        
        // Create an active goal with blue theme
        _ = createTestGoal(context: context, themeID: "blue")
        
        try context.save()
        
        let helper = GoalEditorThemeHelper()
        let allGoals = try context.fetch(FetchDescriptor<Goal>())
        let unusedTheme = helper.findUnusedTheme(excluding: allGoals.filter { $0.status == .active })
        
        // Red should be available since the goal using it is archived
        // (We filter by .active in the excluding parameter)
        #expect(unusedTheme.id != "blue")
    }
    
    // MARK: - Goal Validation Tests
    
    @Test("isValidGoal returns false for empty title")
    func testValidationEmptyTitle() {
        let validator = GoalEditorValidator()
        let isValid = validator.isValidGoal(title: "", weeklyTargetMinutes: 30)
        
        #expect(isValid == false)
    }
    
    @Test("isValidGoal returns false for whitespace-only title")
    func testValidationWhitespaceTitle() {
        let validator = GoalEditorValidator()
        let isValid = validator.isValidGoal(title: "   ", weeklyTargetMinutes: 30)
        
        #expect(isValid == false)
    }
    
    @Test("isValidGoal returns false for zero weekly target")
    func testValidationZeroWeeklyTarget() {
        let validator = GoalEditorValidator()
        let isValid = validator.isValidGoal(title: "Valid Title", weeklyTargetMinutes: 0)
        
        #expect(isValid == false)
    }
    
    @Test("isValidGoal returns false for negative weekly target")
    func testValidationNegativeWeeklyTarget() {
        let validator = GoalEditorValidator()
        let isValid = validator.isValidGoal(title: "Valid Title", weeklyTargetMinutes: -10)
        
        #expect(isValid == false)
    }
    
    @Test("isValidGoal returns true for valid input")
    func testValidationValidInput() {
        let validator = GoalEditorValidator()
        let isValid = validator.isValidGoal(title: "Reading", weeklyTargetMinutes: 210)
        
        #expect(isValid == true)
    }
    
    @Test("isValidGoal trims whitespace when checking title")
    func testValidationTrimsWhitespace() {
        let validator = GoalEditorValidator()
        let isValid = validator.isValidGoal(title: "  Reading  ", weeklyTargetMinutes: 30)
        
        #expect(isValid == true)
    }
    
    // MARK: - Weekly Target Calculation Tests
    
    @Test("calculateWeeklyTarget from daily duration")
    func testCalculateWeeklyTargetFromDaily() {
        let calculator = GoalEditorCalculator()
        
        // 30 minutes per day for 7 days = 210 minutes
        let weeklyMinutes = calculator.calculateWeeklyTarget(
            dailyMinutes: 30,
            activeDaysCount: 7
        )
        
        #expect(weeklyMinutes == 210)
    }
    
    @Test("calculateWeeklyTarget for partial week")
    func testCalculateWeeklyTargetPartialWeek() {
        let calculator = GoalEditorCalculator()
        
        // 30 minutes per day for 5 days (weekdays) = 150 minutes
        let weeklyMinutes = calculator.calculateWeeklyTarget(
            dailyMinutes: 30,
            activeDaysCount: 5
        )
        
        #expect(weeklyMinutes == 150)
    }
    
    @Test("calculateDailyTarget from weekly target")
    func testCalculateDailyTargetFromWeekly() {
        let calculator = GoalEditorCalculator()
        
        // 210 minutes per week / 7 days = 30 minutes per day
        let dailyMinutes = calculator.calculateDailyTarget(
            weeklyMinutes: 210,
            activeDaysCount: 7
        )
        
        #expect(dailyMinutes == 30)
    }
    
    @Test("calculateDailyTarget rounds correctly")
    func testCalculateDailyTargetRounding() {
        let calculator = GoalEditorCalculator()
        
        // 100 minutes per week / 7 days = 14.28... should round to 14
        let dailyMinutes = calculator.calculateDailyTarget(
            weeklyMinutes: 100,
            activeDaysCount: 7
        )
        
        #expect(dailyMinutes == 14)
    }
    
    @Test("calculateDailyTarget handles zero active days")
    func testCalculateDailyTargetZeroActiveDays() {
        let calculator = GoalEditorCalculator()
        
        let dailyMinutes = calculator.calculateDailyTarget(
            weeklyMinutes: 210,
            activeDaysCount: 0
        )
        
        // Should return 0 or some sensible default when no active days
        #expect(dailyMinutes == 0)
    }
    
    // MARK: - Icon Inference Tests
    
    @Test("inferIcon returns correct icon for meditation")
    func testInferIconMeditation() {
        let helper = GoalEditorIconHelper()
        let icon = helper.inferIcon(from: "Meditation")
        
        #expect(icon == "figure.mind.and.body")
    }
    
    @Test("inferIcon returns correct icon for running")
    func testInferIconRunning() {
        let helper = GoalEditorIconHelper()
        let icon = helper.inferIcon(from: "Running")
        
        #expect(icon == "figure.run")
    }
    
    @Test("inferIcon returns correct icon for reading")
    func testInferIconReading() {
        let helper = GoalEditorIconHelper()
        let icon = helper.inferIcon(from: "Reading")
        
        #expect(icon == "book.fill")
    }
    
    @Test("inferIcon handles case insensitive input")
    func testInferIconCaseInsensitive() {
        let helper = GoalEditorIconHelper()
        let icon1 = helper.inferIcon(from: "MEDITATION")
        let icon2 = helper.inferIcon(from: "meditation")
        
        #expect(icon1 == "figure.mind.and.body")
        #expect(icon2 == "figure.mind.and.body")
    }
    
    @Test("inferIcon returns nil for unknown activity")
    func testInferIconUnknown() {
        let helper = GoalEditorIconHelper()
        let icon = helper.inferIcon(from: "UnknownActivity123")
        
        #expect(icon == nil)
    }
    
    @Test("inferIcon handles partial matches")
    func testInferIconPartialMatch() {
        let helper = GoalEditorIconHelper()
        let icon = helper.inferIcon(from: "I want to meditate daily")
        
        #expect(icon == "figure.mind.and.body")
    }
}

// MARK: - Helper Classes for Testing

/// Helper class for theme matching logic
struct GoalEditorThemeHelper {
    func matchTheme(named themeName: String) -> ThemePreset {
        let normalizedThemeName = themeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct mapping for suggestion themes to theme preset IDs
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
        
        // Check if this is a known theme name
        if let presetId = themeMapping[normalizedThemeName] {
            if let match = themePresets.first(where: { $0.id == presetId }) {
                return match
            }
        }
        
        // Try exact match first
        if let exactMatch = themePresets.first(where: { $0.title.lowercased() == normalizedThemeName }) {
            return exactMatch
        }
        
        // Try partial match
        if let partialMatch = themePresets.first(where: { $0.title.lowercased().contains(normalizedThemeName) }) {
            return partialMatch
        }
        
        // Try reverse match (theme name contains the search term)
        if let reverseMatch = themePresets.first(where: { normalizedThemeName.contains($0.title.lowercased()) }) {
            return reverseMatch
        }
        
        // Keyword-based matching for common activities
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
        
        // Default fallback - use first theme
        return themePresets[0]
    }
    
    func findUnusedTheme(excluding goals: [Goal]) -> ThemePreset {
        // Get all theme IDs currently in use by active goals
        let usedThemeIDs = Set(goals.filter { $0.status == .active }.compactMap { $0.primaryTag?.themeID })
        
        // Find first unused theme
        if let unusedPreset = themePresets.first(where: { !usedThemeIDs.contains($0.id) }) {
            return unusedPreset
        }
        
        // If all themes are used, return a random one
        return (themePresets.randomElement() ?? themePresets[0])
    }
}

/// Helper class for goal validation logic
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

/// Helper class for calculation logic
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

/// Helper class for icon inference logic
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
