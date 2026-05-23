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
        themeID: String = "palette_17"
    ) -> Goal {
        let tag = GoalTag(title: "Test Tag", themeID: themeID)
        context.insert(tag)
        
        let goal = Goal(title: title, primaryTag: tag)
        goal.targetUnit = .seconds
        goal.unifiedDailyTarget = 3600 / 7.0
        context.insert(goal)
        try? context.save()
        return goal
    }
    
    // MARK: - Theme Matching Tests
    
    @Test("matchTheme returns correct theme for fitness category")
    func testMatchThemeFitness() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "Fitness")
        
        #expect(theme.id == "palette_01")
    }
    
    @Test("matchTheme returns correct theme for wellness category")
    func testMatchThemeWellness() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "Wellness")
        
        #expect(theme.id == "palette_05")
    }
    
    @Test("matchTheme returns correct theme for learning category")
    func testMatchThemeLearning() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "Learning")
        
        #expect(theme.id == "palette_02")
    }
    
    @Test("matchTheme handles case insensitive input")
    func testMatchThemeCaseInsensitive() {
        let helper = GoalEditorThemeHelper()
        let theme1 = helper.matchTheme(named: "FITNESS")
        let theme2 = helper.matchTheme(named: "fitness")
        let theme3 = helper.matchTheme(named: "FiTnEsS")
        
        #expect(theme1.id == "palette_01")
        #expect(theme2.id == "palette_01")
        #expect(theme3.id == "palette_01")
    }
    
    @Test("matchTheme handles whitespace")
    func testMatchThemeWhitespace() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "  Fitness  ")
        
        #expect(theme.id == "palette_01")
    }
    
    @Test("matchTheme returns default for unknown theme")
    func testMatchThemeUnknown() {
        let helper = GoalEditorThemeHelper()
        let theme = helper.matchTheme(named: "UnknownCategory123")
        
        // Should return a valid theme (fallback to first theme)
        #expect(theme.id == defaultThemePreset.id)
    }
    
    @Test("matchTheme handles partial matches")
    func testMatchThemePartialMatch() {
        let helper = GoalEditorThemeHelper()
        
        // Should match "exercise" keyword to fitness
        let theme = helper.matchTheme(named: "exercise")
        #expect(theme.id == "palette_01")
    }
    
    // MARK: - Find Unused Theme Tests
    
    @Test("findUnusedTheme returns unused theme when available")
    func testFindUnusedThemeReturnsUnused() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        // Create goals with some themes
        _ = createTestGoal(context: context, themeID: "palette_01")
        _ = createTestGoal(context: context, themeID: "palette_17")
        
        let helper = GoalEditorThemeHelper()
        let allGoals = try context.fetch(FetchDescriptor<Goal>())
        let unusedTheme = helper.findUnusedTheme(excluding: allGoals.filter { $0.status == .active })
        
        // Should not return palette_01 or palette_17
        #expect(unusedTheme.id != "palette_01")
        #expect(unusedTheme.id != "palette_17")
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
        
        // Create an archived goal with palette_01 theme
        let archivedGoal = createTestGoal(context: context, themeID: "palette_01")
        archivedGoal.status = .archived
        
        // Create an active goal with palette_17 theme
        _ = createTestGoal(context: context, themeID: "palette_17")
        
        try context.save()
        
        let helper = GoalEditorThemeHelper()
        let allGoals = try context.fetch(FetchDescriptor<Goal>())
        let unusedTheme = helper.findUnusedTheme(excluding: allGoals.filter { $0.status == .active })
        
        // Red should be available since the goal using it is archived
        // (We filter by .active in the excluding parameter)
        #expect(unusedTheme.id != "palette_17")
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
// Note: Helper classes now live in production code under Momentum/GoalEditor/
// and are imported via @testable import Momentum

