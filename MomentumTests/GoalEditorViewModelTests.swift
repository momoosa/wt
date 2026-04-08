//
//  GoalEditorViewModelTests.swift
//  MomentumTests
//
//  Created by Assistant on 08/04/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Momentum
@testable import MomentumKit

@Suite("Goal Editor ViewModel Tests")
struct GoalEditorViewModelTests {
    
    // MARK: - Test Helpers
    
    private func createTestViewModel() -> GoalEditorViewModel {
        return GoalEditorViewModel(existingGoal: nil)
    }
    
    private func createMockSuggestionsData() -> GoalSuggestionsData {
        let category = GoalCategory(
            id: "test-category",
            name: "Fitness",
            icon: "figure.run",
            color: "blue",
            suggestions: [
                GoalTemplateSuggestion(
                    id: "test-1",
                    title: "Meditation",
                    subtitle: "Daily mindfulness practice",
                    duration: 30,
                    dailyGoal: true,
                    theme: "blue",
                    healthKitMetric: nil,
                    icon: "brain.head.profile",
                    goalType: "time",
                    primaryMetricTarget: nil
                ),
                GoalTemplateSuggestion(
                    id: "test-2",
                    title: "Run",
                    subtitle: "Cardio workout",
                    duration: 45,
                    dailyGoal: false,
                    theme: "green",
                    healthKitMetric: nil,
                    icon: "figure.run",
                    goalType: "time",
                    primaryMetricTarget: nil
                )
            ]
        )
        return GoalSuggestionsData(categories: [category])
    }
    
    // MARK: - Validation Tests
    
    @Test("isValid returns false when userInput is empty")
    func testIsValidWithEmptyInput() {
        let viewModel = createTestViewModel()
        viewModel.userInput = ""
        
        #expect(!viewModel.isValid())
    }
    
    @Test("isValid returns false when userInput is whitespace only")
    func testIsValidWithWhitespaceInput() {
        let viewModel = createTestViewModel()
        viewModel.userInput = "   "
        
        #expect(!viewModel.isValid())
    }
    
    @Test("isValid returns true when userInput has valid content")
    func testIsValidWithValidInput() {
        let viewModel = createTestViewModel()
        viewModel.userInput = "Morning Exercise"
        
        #expect(viewModel.isValid())
    }
    
    // MARK: - Calculation Tests
    
    @Test("calculateWeeklyTarget with 30 minutes and 5 active days")
    func testCalculateWeeklyTarget() {
        let viewModel = createTestViewModel()
        viewModel.durationInMinutes = 30
        viewModel.activeDays = Set(2...6) // Monday-Friday
        
        let weeklyTarget = viewModel.calculateWeeklyTarget()
        #expect(weeklyTarget == 150) // 30 * 5
    }
    
    @Test("calculateWeeklyTarget with all days active")
    func testCalculateWeeklyTargetAllDays() {
        let viewModel = createTestViewModel()
        viewModel.durationInMinutes = 20
        viewModel.activeDays = Set(1...7)
        
        let weeklyTarget = viewModel.calculateWeeklyTarget()
        #expect(weeklyTarget == 140) // 20 * 7
    }
    
    @Test("calculateWeeklyTarget with single active day")
    func testCalculateWeeklyTargetSingleDay() {
        let viewModel = createTestViewModel()
        viewModel.durationInMinutes = 60
        viewModel.activeDays = Set([3]) // Only Wednesday
        
        let weeklyTarget = viewModel.calculateWeeklyTarget()
        #expect(weeklyTarget == 60)
    }
    
    @Test("calculateDailyTarget distributes weekly minutes evenly")
    func testCalculateDailyTarget() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set(2...6) // 5 days
        
        let dailyTarget = viewModel.calculateDailyTarget(weeklyMinutes: 150)
        #expect(dailyTarget == 30) // 150 / 5
    }
    
    @Test("calculatedWeeklyTarget sums daily targets for time-based goals")
    func testCalculatedWeeklyTargetTimeGoals() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .time
        viewModel.activeDays = Set([2, 4, 6]) // Mon, Wed, Fri
        viewModel.dailyTargets = [2: 30, 4: 45, 6: 60]
        
        let weeklyTarget = viewModel.calculatedWeeklyTarget
        #expect(weeklyTarget == 135) // 30 + 45 + 60
    }
    
    @Test("calculatedWeeklyTarget multiplies daily target by active days for count goals")
    func testCalculatedWeeklyTargetCountGoals() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .count
        viewModel.primaryMetricTarget = 10000
        viewModel.activeDays = Set(2...6) // 5 days
        
        let weeklyTarget = viewModel.calculatedWeeklyTarget
        #expect(weeklyTarget == 50000) // 10000 * 5
    }
    
    // MARK: - Active Days Management Tests
    
    @Test("toggleActiveDay adds day when not active")
    func testToggleActiveDayAdd() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 3, 4])
        
        viewModel.toggleActiveDay(5)
        
        #expect(viewModel.activeDays.contains(5))
        #expect(viewModel.activeDays.count == 4)
    }
    
    @Test("toggleActiveDay removes day when active")
    func testToggleActiveDayRemove() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 3, 4, 5])
        viewModel.dailyTargets = [2: 30, 3: 30, 4: 30, 5: 30]
        
        viewModel.toggleActiveDay(4)
        
        #expect(!viewModel.activeDays.contains(4))
        #expect(viewModel.activeDays.count == 3)
        #expect(viewModel.dailyTargets[4] == nil)
    }
    
    @Test("toggleActiveDay sets default target when activating")
    func testToggleActiveDayDefaultTarget() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 3])
        viewModel.dailyMinimumMinutes = 25
        
        viewModel.toggleActiveDay(5)
        
        #expect(viewModel.dailyTargets[5] == 25)
    }
    
    @Test("isDayActive returns correct status")
    func testIsDayActive() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 4, 6])
        
        #expect(viewModel.isDayActive(2))
        #expect(!viewModel.isDayActive(3))
        #expect(viewModel.isDayActive(4))
        #expect(!viewModel.isDayActive(5))
        #expect(viewModel.isDayActive(6))
    }
    
    @Test("updateDailyTarget updates the correct day")
    func testUpdateDailyTarget() {
        let viewModel = createTestViewModel()
        viewModel.dailyTargets = [2: 30, 3: 45, 4: 60]
        
        viewModel.updateDailyTarget(for: 3, minutes: 90)
        
        #expect(viewModel.dailyTargets[3] == 90)
        #expect(viewModel.dailyTargets[2] == 30)
        #expect(viewModel.dailyTargets[4] == 60)
    }
    
    @Test("shouldShowApplyToAll returns true when durations differ")
    func testShouldShowApplyToAllWithDifference() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 3, 4, 5])
        viewModel.dailyTargets = [2: 30, 3: 30, 4: 45, 5: 30]
        
        // Day 4 has different duration
        #expect(viewModel.shouldShowApplyToAll(for: 4))
    }
    
    @Test("shouldShowApplyToAll returns false when all durations match")
    func testShouldShowApplyToAllWithoutDifference() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 3, 4, 5])
        viewModel.dailyTargets = [2: 30, 3: 30, 4: 30, 5: 30]
        
        #expect(!viewModel.shouldShowApplyToAll(for: 3))
    }
    
    @Test("applyDurationToAllDays copies duration to all active days")
    func testApplyDurationToAllDays() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2, 3, 4, 5, 6])
        viewModel.dailyTargets = [2: 30, 3: 45, 4: 60, 5: 30, 6: 90]
        
        viewModel.applyDurationToAllDays(from: 4)
        
        #expect(viewModel.dailyTargets[2] == 60)
        #expect(viewModel.dailyTargets[3] == 60)
        #expect(viewModel.dailyTargets[4] == 60)
        #expect(viewModel.dailyTargets[5] == 60)
        #expect(viewModel.dailyTargets[6] == 60)
    }
    
    // MARK: - Template Matching Tests
    
    @Test("matchesSuggestion returns true for exact title match")
    func testMatchesSuggestionExactMatch() {
        let viewModel = createTestViewModel()
        let suggestion = GoalTemplateSuggestion(
            id: "1",
            title: "Meditation",
            subtitle: "Daily practice",
            duration: 30,
            dailyGoal: true,
            theme: "blue",
            healthKitMetric: nil,
            icon: "brain.head.profile",
            goalType: "time",
            primaryMetricTarget: nil
        )
        
        #expect(viewModel.matchesSuggestion(suggestion, with: "Meditation", aliases: [:]))
    }
    
    @Test("matchesSuggestion is case-insensitive")
    func testMatchesSuggestionCaseInsensitive() {
        let viewModel = createTestViewModel()
        let suggestion = GoalTemplateSuggestion(
            id: "1",
            title: "Meditation",
            subtitle: "Daily practice",
            duration: 30,
            dailyGoal: true,
            theme: "blue",
            healthKitMetric: nil,
            icon: "brain.head.profile",
            goalType: "time",
            primaryMetricTarget: nil
        )
        
        #expect(viewModel.matchesSuggestion(suggestion, with: "meditation", aliases: [:]))
        #expect(viewModel.matchesSuggestion(suggestion, with: "MEDITATION", aliases: [:]))
        #expect(viewModel.matchesSuggestion(suggestion, with: "MeDiTaTiOn", aliases: [:]))
    }
    
    @Test("matchesSuggestion returns true for alias match")
    func testMatchesSuggestionAliasMatch() {
        let viewModel = createTestViewModel()
        let suggestion = GoalTemplateSuggestion(
            id: "1",
            title: "Meditation",
            subtitle: "Daily practice",
            duration: 30,
            dailyGoal: true,
            theme: "blue",
            healthKitMetric: nil,
            icon: "brain.head.profile",
            goalType: "time",
            primaryMetricTarget: nil
        )
        let aliases = ["Meditation": ["meditate", "mindfulness"]]
        
        #expect(viewModel.matchesSuggestion(suggestion, with: "meditate", aliases: aliases))
        #expect(viewModel.matchesSuggestion(suggestion, with: "mindfulness", aliases: aliases))
    }
    
    @Test("matchesSuggestion returns false for non-match")
    func testMatchesSuggestionNoMatch() {
        let viewModel = createTestViewModel()
        let suggestion = GoalTemplateSuggestion(
            id: "1",
            title: "Meditation",
            subtitle: "Daily practice",
            duration: 30,
            dailyGoal: true,
            theme: "blue",
            healthKitMetric: nil,
            icon: "brain.head.profile",
            goalType: "time",
            primaryMetricTarget: nil
        )
        
        #expect(!viewModel.matchesSuggestion(suggestion, with: "Running", aliases: [:]))
    }
    
    @Test("matchesSuggestion returns false for empty input")
    func testMatchesSuggestionEmptyInput() {
        let viewModel = createTestViewModel()
        let suggestion = GoalTemplateSuggestion(
            id: "1",
            title: "Meditation",
            subtitle: "Daily practice",
            duration: 30,
            dailyGoal: true,
            theme: "blue",
            healthKitMetric: nil,
            icon: "brain.head.profile",
            goalType: "time",
            primaryMetricTarget: nil
        )
        
        #expect(!viewModel.matchesSuggestion(suggestion, with: "", aliases: [:]))
        #expect(!viewModel.matchesSuggestion(suggestion, with: "   ", aliases: [:]))
    }
    
    // MARK: - Time Slot Management Tests
    
    @Test("toggleTimeSlot removes time slot when present")
    func testToggleTimeSlotRemove() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([2])
        viewModel.dayTimePreferences[2] = [.morning, .afternoon, .evening]
        viewModel.dailyTargets[2] = 30
        
        viewModel.toggleTimeSlot(weekday: 2, timeOfDay: .afternoon)
        
        #expect(viewModel.dayTimePreferences[2]?.contains(.afternoon) == false)
        #expect(viewModel.dayTimePreferences[2]?.contains(.morning) == true)
        #expect(viewModel.dayTimePreferences[2]?.contains(.evening) == true)
    }
    
    @Test("toggleTimeSlot adds time slot when not present")
    func testToggleTimeSlotAdd() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([3])
        viewModel.dayTimePreferences[3] = [.morning]
        
        viewModel.toggleTimeSlot(weekday: 3, timeOfDay: .evening)
        
        #expect(viewModel.dayTimePreferences[3]?.contains(.morning) == true)
        #expect(viewModel.dayTimePreferences[3]?.contains(.evening) == true)
    }
    
    @Test("toggleTimeSlot deactivates day when last time slot removed")
    func testToggleTimeSlotDeactivatesDay() {
        let viewModel = createTestViewModel()
        viewModel.activeDays = Set([4])
        viewModel.dayTimePreferences[4] = [.morning]
        viewModel.dailyTargets[4] = 45
        
        viewModel.toggleTimeSlot(weekday: 4, timeOfDay: .morning)
        
        #expect(viewModel.dayTimePreferences[4]?.isEmpty == true)
        #expect(!viewModel.activeDays.contains(4))
        #expect(viewModel.dailyTargets[4] == nil)
    }
    
    // MARK: - Stage Management Tests
    
    @Test("proceedToNextStage succeeds with valid input")
    func testProceedToNextStageValid() {
        let viewModel = createTestViewModel()
        viewModel.userInput = "Morning Routine"
        viewModel.currentStage = .name
        
        let result = viewModel.proceedToNextStage()
        
        #expect(result == true)
        #expect(viewModel.currentStage == .duration)
    }
    
    @Test("proceedToNextStage fails with invalid input")
    func testProceedToNextStageInvalid() {
        let viewModel = createTestViewModel()
        viewModel.userInput = ""
        viewModel.currentStage = .name
        
        let result = viewModel.proceedToNextStage()
        
        #expect(result == false)
        #expect(viewModel.currentStage == .name)
    }
    
    @Test("hasUnsavedChanges returns true with user input")
    func testHasUnsavedChangesWithInput() {
        let viewModel = createTestViewModel()
        viewModel.userInput = "Exercise"
        
        #expect(viewModel.hasUnsavedChanges())
    }
    
    @Test("hasUnsavedChanges returns true with selected template")
    func testHasUnsavedChangesWithTemplate() {
        let viewModel = createTestViewModel()
        viewModel.selectedTemplate = GoalTemplateSuggestion(
            id: "1",
            title: "Run",
            subtitle: "Cardio workout",
            duration: 30,
            dailyGoal: false,
            theme: "green",
            healthKitMetric: nil,
            icon: "figure.run",
            goalType: "time",
            primaryMetricTarget: nil
        )
        
        #expect(viewModel.hasUnsavedChanges())
    }
    
    @Test("hasUnsavedChanges returns true on duration stage")
    func testHasUnsavedChangesOnDurationStage() {
        let viewModel = createTestViewModel()
        viewModel.currentStage = .duration
        
        #expect(viewModel.hasUnsavedChanges())
    }
    
    @Test("hasUnsavedChanges returns false with empty state")
    func testHasUnsavedChangesEmpty() {
        let viewModel = createTestViewModel()
        viewModel.userInput = ""
        viewModel.selectedTemplate = nil
        viewModel.currentStage = .name
        
        #expect(!viewModel.hasUnsavedChanges())
    }
    
    // MARK: - Goal Type Tests
    
    @Test("goalTypeUnit returns correct unit for time")
    func testGoalTypeUnitTime() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .time
        
        #expect(viewModel.goalTypeUnit == "min")
    }
    
    @Test("goalTypeUnit returns correct unit for count")
    func testGoalTypeUnitCount() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .count
        
        #expect(viewModel.goalTypeUnit == "steps")
    }
    
    @Test("goalTypeUnit returns correct unit for calories")
    func testGoalTypeUnitCalories() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .calories
        
        #expect(viewModel.goalTypeUnit == "cal")
    }
    
    @Test("handleGoalTypeChange to count sets defaults")
    func testHandleGoalTypeChangeToCount() {
        let viewModel = createTestViewModel()
        viewModel.handleGoalTypeChange(.count)
        
        #expect(viewModel.selectedHealthKitMetric == .stepCount)
        #expect(viewModel.healthKitSyncEnabled == true)
        #expect(viewModel.primaryMetricTarget == 10000)
    }
    
    @Test("handleGoalTypeChange to calories sets defaults")
    func testHandleGoalTypeChangeToCalories() {
        let viewModel = createTestViewModel()
        viewModel.handleGoalTypeChange(.calories)
        
        #expect(viewModel.selectedHealthKitMetric == .activeEnergyBurned)
        #expect(viewModel.healthKitSyncEnabled == true)
        #expect(viewModel.primaryMetricTarget == 500)
    }
    
    @Test("handleGoalTypeChange to time clears HealthKit")
    func testHandleGoalTypeChangeToTime() {
        let viewModel = createTestViewModel()
        viewModel.selectedHealthKitMetric = .stepCount
        viewModel.healthKitSyncEnabled = true
        
        viewModel.handleGoalTypeChange(.time)
        
        #expect(viewModel.selectedHealthKitMetric == nil)
        #expect(viewModel.healthKitSyncEnabled == false)
    }
    
    // MARK: - Primary Metric Validation Tests
    
    @Test("validatePrimaryMetricTarget clamps count goals to minimum")
    func testValidatePrimaryMetricTargetCountMinimum() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .count
        viewModel.primaryMetricTarget = 50
        
        viewModel.validatePrimaryMetricTarget()
        
        #expect(viewModel.primaryMetricTarget == 100)
        #expect(viewModel.showingValidationAlert == true)
    }
    
    @Test("validatePrimaryMetricTarget clamps count goals to maximum")
    func testValidatePrimaryMetricTargetCountMaximum() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .count
        viewModel.primaryMetricTarget = 150000
        
        viewModel.validatePrimaryMetricTarget()
        
        #expect(viewModel.primaryMetricTarget == 100000)
        #expect(viewModel.showingValidationAlert == true)
    }
    
    @Test("validatePrimaryMetricTarget clamps calorie goals to minimum")
    func testValidatePrimaryMetricTargetCaloriesMinimum() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .calories
        viewModel.primaryMetricTarget = 25
        
        viewModel.validatePrimaryMetricTarget()
        
        #expect(viewModel.primaryMetricTarget == 50)
        #expect(viewModel.showingValidationAlert == true)
    }
    
    @Test("validatePrimaryMetricTarget clamps calorie goals to maximum")
    func testValidatePrimaryMetricTargetCaloriesMaximum() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .calories
        viewModel.primaryMetricTarget = 15000
        
        viewModel.validatePrimaryMetricTarget()
        
        #expect(viewModel.primaryMetricTarget == 10000)
        #expect(viewModel.showingValidationAlert == true)
    }
    
    @Test("validatePrimaryMetricTarget accepts valid count values")
    func testValidatePrimaryMetricTargetCountValid() {
        let viewModel = createTestViewModel()
        viewModel.selectedGoalType = .count
        viewModel.primaryMetricTarget = 8000
        
        viewModel.validatePrimaryMetricTarget()
        
        #expect(viewModel.primaryMetricTarget == 8000)
        #expect(viewModel.showingValidationAlert == false)
    }
    
    // MARK: - Schedule Preset Tests
    
    @Test("applyPreset weekdayMornings sets correct schedule")
    func testApplyPresetWeekdayMornings() {
        let viewModel = createTestViewModel()
        viewModel.applyPreset(.weekdayMornings)
        
        // Check weekdays (Mon-Fri) have morning
        for weekday in 2...6 {
            #expect(viewModel.dayTimePreferences[weekday] == [.morning])
        }
        
        // Check weekend is not set
        #expect(viewModel.dayTimePreferences[7] == nil)
        #expect(viewModel.dayTimePreferences[1] == nil)
    }
    
    @Test("applyPreset everyEvening sets all days to evening")
    func testApplyPresetEveryEvening() {
        let viewModel = createTestViewModel()
        viewModel.applyPreset(.everyEvening)
        
        for weekday in 1...7 {
            #expect(viewModel.dayTimePreferences[weekday] == [.evening])
        }
    }
    
    @Test("applyPreset weekends sets only weekend with all times")
    func testApplyPresetWeekends() {
        let viewModel = createTestViewModel()
        viewModel.applyPreset(.weekends)
        
        // Check weekend days have all times
        #expect(viewModel.dayTimePreferences[7] == Set(TimeOfDay.allCases))
        #expect(viewModel.dayTimePreferences[1] == Set(TimeOfDay.allCases))
        
        // Check weekdays are not set
        for weekday in 2...6 {
            #expect(viewModel.dayTimePreferences[weekday] == nil)
        }
    }
    
    @Test("applyPreset everyDay sets all days with all times")
    func testApplyPresetEveryDay() {
        let viewModel = createTestViewModel()
        viewModel.applyPreset(.everyDay)
        
        for weekday in 1...7 {
            #expect(viewModel.dayTimePreferences[weekday] == Set(TimeOfDay.allCases))
        }
    }
    
    // MARK: - Theme Management Tests
    
    @Test("removeGoalTheme removes theme from selectedTags")
    func testRemoveGoalTheme() {
        let viewModel = createTestViewModel()
        let theme1 = GoalTag(title: "Fitness", themeID: "blue")
        let theme2 = GoalTag(title: "Work", themeID: "green")
        viewModel.selectedTags = [theme1, theme2]
        
        viewModel.removeGoalTheme(theme1)
        
        #expect(viewModel.selectedTags.count == 1)
        #expect(viewModel.selectedTags.first?.title == "Work")
    }
    
    @Test("removeGoalTheme updates selectedGoalTheme if it was removed")
    func testRemoveGoalThemeUpdatesSelected() {
        let viewModel = createTestViewModel()
        let theme1 = GoalTag(title: "Fitness", themeID: "blue")
        let theme2 = GoalTag(title: "Work", themeID: "green")
        viewModel.selectedTags = [theme1, theme2]
        viewModel.selectedGoalTheme = theme1
        
        viewModel.removeGoalTheme(theme1)
        
        #expect(viewModel.selectedGoalTheme?.title == "Work")
    }
    
    @Test("removeGoalTheme does not affect selectedGoalTheme if different")
    func testRemoveGoalThemeKeepsSelected() {
        let viewModel = createTestViewModel()
        let theme1 = GoalTag(title: "Fitness", themeID: "blue")
        let theme2 = GoalTag(title: "Work", themeID: "green")
        viewModel.selectedTags = [theme1, theme2]
        viewModel.selectedGoalTheme = theme2
        
        viewModel.removeGoalTheme(theme1)
        
        #expect(viewModel.selectedGoalTheme?.title == "Work")
    }
}
