//
//  GoalEditorViewModel.swift
//  Momentum
//
//  Created by Assistant on 28/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

@Observable
class GoalEditorViewModel {
    
    // MARK: - Dependencies
    
    private let themeHelper = GoalEditorThemeHelper()
    private let iconHelper = GoalEditorIconHelper()
    private let validator = GoalEditorValidator()
    private let calculator = GoalEditorCalculator()
    
    // MARK: - Core State
    
    var userInput: String = ""
    var durationInMinutes: Int = 30
    var dailyMinimumMinutes: Int?
    var hasDailyMinimum: Bool = false
    var currentStage: EditorStage = .name
    
    // MARK: - Template & Suggestions
    
    var selectedTemplate: GoalTemplateSuggestion?
    var selectedCategoryIndex: Int = 0
    var suggestionsData: GoalSuggestionsData
    
    // MARK: - Theme & Appearance
    
    var selectedGoalTheme: GoalTag?
    var selectedColorPreset: ThemePreset?
    var showingColorPicker: Bool = false
    var selectedIcon: String?
    var showingIconPicker: Bool = false
    
    // MARK: - Tags
    
    var selectedTags: [GoalTag] = []
    var showingTagPicker: Bool = false
    var editingTag: GoalTag?
    var showingAddThemeSheet: Bool = false
    var customThemeName: String = ""
    var selectedBaseThemeForCustom: ThemePreset?
    var isEditingThemes: Bool = false
    
    // MARK: - Notifications
    
    var scheduleNotificationsEnabled: Bool = false
    var completionNotificationsEnabled: Bool = false
    
    // MARK: - Completion Behaviors
    
    var selectedCompletionBehaviors: Set<Goal.CompletionBehavior> = []
    
    // MARK: - HealthKit
    
    var selectedHealthKitMetric: HealthKitMetric?
    var healthKitSyncEnabled: Bool = false
    
    // MARK: - Goal Types & Metrics
    
    var selectedGoalType: Goal.GoalType = .time
    var primaryMetricTarget: Double = 0
    var dailyTargets: [Int: Int] = [:]
    
    // MARK: - Validation
    
    var validationMessage: String = ""
    var showingValidationAlert: Bool = false
    
    // MARK: - Screen Time
    
    var screenTimeEnabled: Bool = false
    var selectedScreenTimeCategories: Set<String> = []
    
    // MARK: - Additional Fields
    
    var goalNotes: String = ""
    var goalLink: String = ""
    
    // MARK: - Checklist
    
    var checklistItems: [ChecklistItemData] = []
    var newChecklistItemTitle: String = ""
    var newChecklistItemNotes: String = ""
    
    // MARK: - Weather Triggers
    
    var weatherEnabled: Bool = false
    var selectedWeatherConditions: Set<WeatherCondition> = []
    var hasMinTemperature: Bool = false
    var minTemperature: Double = 10
    var hasMaxTemperature: Bool = false
    var maxTemperature: Double = 25
    
    // MARK: - Scheduling
    
    var dayTimePreferences: [Int: Set<TimeOfDay>] = {
        var preferences: [Int: Set<TimeOfDay>] = [:]
        for weekday in 1...7 {
            preferences[weekday] = Set(TimeOfDay.allCases)
        }
        return preferences
    }()
    
    // MARK: - Active Days
    
    var activeDays: Set<Int> = Set(1...7)
    
    // MARK: - Types
    
    enum EditorStage {
        case name
        case duration
    }
    
    // MARK: - Initialization
    
    init(existingGoal: Goal? = nil, suggestionsData: GoalSuggestionsData = GoalSuggestionsLoader.shared.loadSuggestions()) {
        self.suggestionsData = suggestionsData
        
        if let goal = existingGoal {
            loadFromExistingGoal(goal)
        }
    }
    
    // MARK: - Business Logic
    
    func inferIconFromInput() {
        guard selectedIcon == nil, !userInput.isEmpty else { return }
        selectedIcon = iconHelper.inferIcon(from: userInput)
    }
    
    func matchTheme(named themeName: String) -> ThemePreset {
        themeHelper.matchTheme(named: themeName)
    }
    
    func findUnusedTheme(excluding goals: [Goal]) -> ThemePreset {
        themeHelper.findUnusedTheme(excluding: goals)
    }
    
    func isValid() -> Bool {
        let weeklyTarget = calculateWeeklyTarget()
        return validator.isValidGoal(title: userInput, weeklyTargetMinutes: weeklyTarget)
    }
    
    func calculateWeeklyTarget() -> Int {
        calculator.calculateWeeklyTarget(
            dailyMinutes: durationInMinutes,
            activeDaysCount: activeDays.count
        )
    }
    
    func calculateDailyTarget(weeklyMinutes: Int) -> Int {
        calculator.calculateDailyTarget(
            weeklyMinutes: weeklyMinutes,
            activeDaysCount: activeDays.count
        )
    }
    
    func proceedToNextStage() -> Bool {
        guard isValid() else { return false }
        currentStage = .duration
        return true
    }
    
    func hasUnsavedChanges() -> Bool {
        if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if selectedTemplate != nil {
            return true
        }
        if currentStage == .duration {
            return true
        }
        return false
    }
    
    // MARK: - Template Matching
    
    func matchTemplate(for input: String, aliases: [String: [String]]) -> (categoryIndex: Int, template: GoalTemplateSuggestion)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        for (categoryIndex, category) in suggestionsData.categories.enumerated() {
            for suggestion in category.suggestions {
                if matchesSuggestion(suggestion, with: input, aliases: aliases) {
                    return (categoryIndex, suggestion)
                }
            }
        }
        return nil
    }
    
    private func matchesSuggestion(_ suggestion: GoalTemplateSuggestion, with input: String, aliases: [String: [String]]) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        if suggestion.title.caseInsensitiveCompare(trimmed) == .orderedSame {
            return true
        }
        
        if let aliasesForSuggestion = aliases[suggestion.title] {
            return aliasesForSuggestion.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
        
        return false
    }
    
    // MARK: - Theme Selection
    
    func handleColorSelection(_ preset: ThemePreset) {
        selectedColorPreset = preset
        
        if let currentTheme = selectedGoalTheme {
            currentTheme.themeID = preset.id
        } else if !selectedTags.isEmpty {
            selectedTags[0].themeID = preset.id
            selectedGoalTheme = selectedTags[0]
        } else {
            let newTag = GoalTag(title: preset.title, themeID: preset.id)
            selectedGoalTheme = newTag
            selectedTags.append(newTag)
        }
        
        showingColorPicker = false
    }
    
    func activeThemeColor(for colorScheme: ColorScheme) -> Color {
        if let selectedPreset = selectedColorPreset {
            return selectedPreset.color(for: colorScheme)
        } else if let selectedTheme = selectedGoalTheme {
            return selectedTheme.themePreset.color(for: colorScheme)
        } else if let template = selectedTemplate,
                  let category = suggestionsData.categories.first(where: { $0.suggestions.contains(where: { $0.id == template.id }) }) {
            let matchedTheme = matchTheme(named: category.color)
            return matchedTheme.color(for: colorScheme)
        }
        return .accentColor
    }
    
    func buttonTextColor(for colorScheme: ColorScheme) -> Color {
        let themeColor = activeThemeColor(for: colorScheme)
        let luminance = themeColor.luminance ?? 0.5
        return luminance > 0.5 ? .black : .white
    }
    
    // MARK: - Load from Existing Goal
    
    private func loadFromExistingGoal(_ goal: Goal) {
        userInput = goal.title
        durationInMinutes = Int(goal.weeklyTarget / 60)
        
        if let tag = goal.primaryTag {
            selectedGoalTheme = tag
            selectedTags = [tag]
        }
        
        selectedIcon = goal.iconName
        goalNotes = goal.notes ?? ""
        goalLink = goal.link ?? ""
        
        scheduleNotificationsEnabled = goal.scheduleNotificationsEnabled
        completionNotificationsEnabled = goal.completionNotificationsEnabled
        selectedCompletionBehaviors = goal.completionBehaviors
        
        // Load goal type and metrics
        selectedGoalType = goal.goalType
        primaryMetricTarget = goal.primaryMetricDailyTarget
        
        // Load daily targets
        dailyTargets.removeAll()
        for (weekdayStr, interval) in goal.dailyTargets {
            if let weekday = Int(weekdayStr) {
                dailyTargets[weekday] = Int(interval / 60)
            }
        }
        
        if let metric = goal.healthKitMetric {
            selectedHealthKitMetric = metric
            healthKitSyncEnabled = goal.healthKitSyncEnabled
        }
        
        checklistItems = goal.checklistItems?.map { ChecklistItemData(id: UUID(uuidString: $0.id) ?? UUID(), title: $0.title, notes: $0.notes ?? "") } ?? []
        
        weatherEnabled = goal.weatherEnabled
        if let conditions = goal.weatherConditions {
            selectedWeatherConditions = Set(conditions.compactMap { WeatherCondition(rawValue: $0) })
        }
        hasMinTemperature = goal.minTemperature != nil
        minTemperature = goal.minTemperature ?? 10
        hasMaxTemperature = goal.maxTemperature != nil
        maxTemperature = goal.maxTemperature ?? 25
        
        // Load day-time schedule and convert to our format
        activeDays.removeAll()
        for (weekdayStr, times) in goal.dayTimeSchedule {
            if let weekday = Int(weekdayStr) {
                activeDays.insert(weekday)
                dayTimePreferences[weekday] = Set(times.compactMap { TimeOfDay(rawValue: $0) })
            }
        }
        
        currentStage = .duration
    }
    
    // MARK: - Goal Type Helpers
    
    var goalTypeUnit: String {
        switch selectedGoalType {
        case .time: return "min"
        case .count: return "steps"
        case .calories: return "cal"
        }
    }
    
    var calculatedWeeklyTarget: Int {
        switch selectedGoalType {
        case .time:
            return durationInMinutes * activeDays.count
        case .count, .calories:
            return Int(primaryMetricTarget * Double(activeDays.count))
        }
    }
    
    func validatePrimaryMetricTarget() {
        guard primaryMetricTarget > 0 else {
            switch selectedGoalType {
            case .time: primaryMetricTarget = 0
            case .count:
                primaryMetricTarget = 100
                validationMessage = "Target set to minimum: 100 steps"
                showingValidationAlert = true
            case .calories:
                primaryMetricTarget = 50
                validationMessage = "Target set to minimum: 50 calories"
                showingValidationAlert = true
            }
            return
        }

        switch selectedGoalType {
        case .time: break
        case .count:
            if primaryMetricTarget > 100000 {
                primaryMetricTarget = 100000
                validationMessage = "Target adjusted to maximum: 100,000 steps"
                showingValidationAlert = true
            } else if primaryMetricTarget < 100 {
                primaryMetricTarget = 100
                validationMessage = "Target adjusted to minimum: 100 steps"
                showingValidationAlert = true
            }
        case .calories:
            if primaryMetricTarget > 10000 {
                primaryMetricTarget = 10000
                validationMessage = "Target adjusted to maximum: 10,000 calories"
                showingValidationAlert = true
            } else if primaryMetricTarget < 50 {
                primaryMetricTarget = 50
                validationMessage = "Target adjusted to minimum: 50 calories"
                showingValidationAlert = true
            }
        }
    }
    
    func applyTemplate(_ template: GoalTemplateSuggestion) {
        userInput = template.title
        durationInMinutes = template.duration
        selectedTemplate = template
        
        if let goalTypeStr = template.goalType, let goalType = Goal.GoalType(rawValue: goalTypeStr) {
            selectedGoalType = goalType
        }
        
        if let target = template.primaryMetricTarget {
            primaryMetricTarget = target
        }
        
        if let healthKitMetricStr = template.healthKitMetric,
           let metric = HealthKitMetric(rawValue: healthKitMetricStr) {
            selectedHealthKitMetric = metric
            healthKitSyncEnabled = true
        }
        
        selectedIcon = template.icon
    }
}
