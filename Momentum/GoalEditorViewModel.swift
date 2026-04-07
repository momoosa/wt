//
//  GoalEditorViewModel.swift
//  Momentum
//
//  Created by Assistant on 28/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit
import FoundationModels

@Observable
class GoalEditorViewModel {
    
    // MARK: - Dependencies
    
    private let themeHelper = GoalEditorThemeHelper()
    private let iconHelper = GoalEditorIconHelper()
    private let validator = GoalEditorValidator()
    private let calculator = GoalEditorCalculator()
    
    // MARK: - Core State
    var existingGoal: Goal?
    var userInput: String = ""
    var durationInMinutes: Int = 30
    var dailyMinimumMinutes: Int?
    var hasDailyMinimum: Bool = false
    var currentStage: EditorStage = .name
    var result: GoalEditorSuggestionsResult.PartiallyGenerated? // TODO: PRivate
    var errorMessage: String? // TODO: Private
    var selectedSuggestion: GoalSuggestion.PartiallyGenerated?
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
            self.existingGoal = goal
            loadFromExistingGoal(goal)
        }
    }
    
    // MARK: - Business Logic
    
    func inferIconFromInput() {
        guard selectedIcon == nil, !userInput.isEmpty else { return }
        selectedIcon = iconHelper.inferIcon(from: userInput)
    }
    
    func inferIcon(from title: String) -> String? {
        return iconHelper.inferIcon(from: title)
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
    
    func matchesSuggestion(_ suggestion: GoalTemplateSuggestion, with input: String, aliases: [String: [String]]) -> Bool {
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
        loadGoalData(from: goal)
    }
    
    func loadGoalData(from goal: Goal) {
        userInput = goal.title
        durationInMinutes = Int(goal.weeklyTarget / 60) // Convert weekly seconds to minutes (legacy)
        
        // Load daily minimum (this is now the primary daily target)
        if let dailyMin = goal.dailyMinimum {
            dailyMinimumMinutes = Int(dailyMin / 60)
        } else {
            // Default to 10 minutes if not set
            dailyMinimumMinutes = 10
        }
        
        // Infer active days from schedule - days with any time preferences are "active"
        activeDays.removeAll()
        dailyTargets.removeAll()
        
        for weekday in 1...7 {
            let times = goal.timesForWeekday(weekday)
            if !times.isEmpty {
                activeDays.insert(weekday)
                // Check if there's a custom daily target for this day
                if let customTarget = goal.dailyTargets[String(weekday)] {
                    dailyTargets[weekday] = Int(customTarget / 60) // Convert seconds to minutes
                } else {
                    // Fall back to dailyMinimum or default
                    dailyTargets[weekday] = dailyMinimumMinutes ?? 10
                }
            }
        }
        
        // If no active days found, default to weekdays with default targets
        if activeDays.isEmpty {
            activeDays = Set(2...6) // Monday-Friday
            for weekday in 2...6 {
                dailyTargets[weekday] = dailyMinimumMinutes ?? 10
            }
        }
        
        scheduleNotificationsEnabled = goal.scheduleNotificationsEnabled
        completionNotificationsEnabled = goal.completionNotificationsEnabled
        selectedCompletionBehaviors = goal.completionBehaviors
        selectedGoalType = goal.goalType
        selectedHealthKitMetric = goal.healthKitMetric
        healthKitSyncEnabled = goal.healthKitSyncEnabled

        // Load or set default primary metric target
        if goal.primaryMetricDailyTarget > 0 {
            primaryMetricTarget = goal.primaryMetricDailyTarget
        } else {
            // Set defaults based on goal type for migrated goals
            switch goal.goalType {
            case .time:
                primaryMetricTarget = 0
            case .count:
                primaryMetricTarget = 10000 // Default: 10,000 steps
            case .calories:
                primaryMetricTarget = 500 // Default: 500 calories
            }
        }

        goalNotes = goal.notes ?? ""
        goalLink = goal.link ?? ""
        
        // Load checklist items
        checklistItems = goal.checklistItems?.map { ChecklistItemData(id: UUID(uuidString: $0.id) ?? UUID(), title: $0.title, notes: $0.notes ?? "") } ?? []
        
        // Load tag/theme
        selectedGoalTheme = goal.primaryTag
        
        // Add to selected themes
        if let primaryTag = goal.primaryTag, !selectedTags.contains(where: { $0.id == primaryTag.id }) {
            selectedTags.append(primaryTag)
        }
        
        selectedIcon = goal.iconName
        
        // Load schedule
        for weekday in 1...7 {
            let times = goal.timesForWeekday(weekday)
            if !times.isEmpty {
                dayTimePreferences[weekday] = times
            }
        }
        
        // Load weather settings
        weatherEnabled = goal.weatherEnabled
        if let conditions = goal.weatherConditionsTyped {
            selectedWeatherConditions = Set(conditions)
        }
        if let minTemp = goal.minTemperature {
            hasMinTemperature = true
            minTemperature = minTemp
        }
        if let maxTemp = goal.maxTemperature {
            hasMaxTemperature = true
            maxTemperature = maxTemp
        }
        
        // Go straight to duration stage when editing
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
    
    func handleGoalTypeChange(_ newType: Goal.GoalType) {
        switch newType {
        case .time:
            selectedHealthKitMetric = nil
            healthKitSyncEnabled = false
        case .count:
            selectedHealthKitMetric = .stepCount
            healthKitSyncEnabled = true
            primaryMetricTarget = 10000
        case .calories:
            selectedHealthKitMetric = .activeEnergyBurned
            healthKitSyncEnabled = true
            primaryMetricTarget = 500
        }
    }
    
    func applyTemplate(_ template: GoalTemplateSuggestion, allTags: [GoalTag]) {
        // Set the title
        userInput = template.title
        
        // Set duration
        durationInMinutes = template.duration
        
        // Distribute the template duration across active days
        // If dailyGoal is true, use all 7 days; otherwise default to weekdays (Monday-Friday)
        let defaultDays: Set<Int> = (template.dailyGoal == true) ? Set(1...7) : Set(2...6)
        let targetDays = activeDays.isEmpty ? defaultDays : activeDays
        let dailyMinutes = targetDays.isEmpty ? template.duration : template.duration / targetDays.count
        
        for weekday in targetDays {
            dailyTargets[weekday] = dailyMinutes
        }
        
        // Infer and set icon from template
        selectedIcon = inferIcon(from: template.title)
        
        // Find the category for this template
        guard let category = suggestionsData.categories.first(where: { category in
            category.suggestions.contains(where: { $0.id == template.id })
        }) else {
            print("⚠️ Could not find category for template: \(template.id)")
            return
        }
        
        let categoryName = category.name
        
        // Create GoalTheme based on category's color
        let matchedTheme = matchTheme(named: category.color)
        
        // Check if a tag with the category name already exists in the database
        let existingTag = allTags.first(where: { $0.title == categoryName })
        
        let goalTheme: GoalTag
        if let existing = existingTag {
            // Use the existing tag
            goalTheme = existing
            print("♻️ Using existing tag: \(existing.title)")
        } else {
            // Create new tag with the category name (e.g., "Fitness") not theme color (e.g., "Green")
            goalTheme = GoalTag(title: categoryName, themeID: matchedTheme.id)
            print("✨ Created new tag: \(categoryName) with theme \(matchedTheme.title)")
        }
        
        selectedGoalTheme = goalTheme
        
        // Add to selected themes if not already there
        if !selectedTags.contains(where: { $0.title == goalTheme.title }) {
            selectedTags.append(goalTheme)
        }
        
        // Set HealthKit metric if available
        if let metricRawValue = template.healthKitMetric,
           let metric = HealthKitMetric(rawValue: metricRawValue) {
            selectedHealthKitMetric = metric
            healthKitSyncEnabled = true
        } else {
            selectedHealthKitMetric = nil
            healthKitSyncEnabled = false
        }

        // Set goal type if specified in template
        if let goalTypeString = template.goalType,
           let goalType = Goal.GoalType(rawValue: goalTypeString) {
            selectedGoalType = goalType
        } else {
            selectedGoalType = .time
        }

        // Set primary metric target if specified
        if let target = template.primaryMetricTarget {
            primaryMetricTarget = target
        }

        print("✨ Template Applied:")
        print("   Title: \(template.title)")
        print("   Duration: \(template.duration) min")
        print("   Daily Minutes: \(dailyMinutes) min per day")
        print("   Goal Type: \(selectedGoalType.rawValue)")
        print("   Primary Target: \(primaryMetricTarget)")
        print("   Theme: \(template.theme)")
        print("   HealthKit: \(template.healthKitMetric ?? "none")")
    }
    
    // MARK: - Schedule & Day Management
    
    func toggleActiveDay(_ weekday: Int) {
        if activeDays.contains(weekday) {
            activeDays.remove(weekday)
            dailyTargets.removeValue(forKey: weekday)
        } else {
            activeDays.insert(weekday)
            // Set default target when activating a day
            dailyTargets[weekday] = dailyMinimumMinutes ?? 10
        }
    }
    
    func isDayActive(_ weekday: Int) -> Bool {
        activeDays.contains(weekday)
    }
    
    func updateDailyTarget(for weekday: Int, minutes: Int) {
        dailyTargets[weekday] = minutes
    }
    
    func shouldShowApplyToAll(for weekday: Int) -> Bool {
        guard let currentDuration = dailyTargets[weekday] else { return false }
        
        // Check if any other active day has a different duration
        for otherWeekday in activeDays where otherWeekday != weekday {
            if dailyTargets[otherWeekday] != currentDuration {
                return true
            }
        }
        
        return false
    }
    
    func applyDurationToAllDays(from sourceWeekday: Int) {
        guard let sourceDuration = dailyTargets[sourceWeekday] else { return }
        
        // Apply the duration to all active days
        for weekday in activeDays {
            dailyTargets[weekday] = sourceDuration
        }
    }
    
    enum SchedulePreset {
        case weekdayMornings
        case everyEvening
        case weekends
        case everyDay
    }
    
    func applyPreset(_ preset: SchedulePreset) {
        dayTimePreferences.removeAll()
        
        switch preset {
        case .weekdayMornings:
            // Monday-Friday mornings
            for weekday in 2...6 {
                dayTimePreferences[weekday] = [.morning]
            }
        case .everyEvening:
            // All days, evenings
            for weekday in 1...7 {
                dayTimePreferences[weekday] = [.evening]
            }
        case .weekends:
            // Saturday and Sunday, all times
            dayTimePreferences[7] = Set(TimeOfDay.allCases)
            dayTimePreferences[1] = Set(TimeOfDay.allCases)
        case .everyDay:
            // All days, all times
            for weekday in 1...7 {
                dayTimePreferences[weekday] = Set(TimeOfDay.allCases)
            }
        }
    }
    
    // MARK: - Theme Management
    
    func removeGoalTheme(_ goalTheme: GoalTag) {
        selectedTags.removeAll(where: { $0.title == goalTheme.title })
        
        // If we removed the currently selected theme, select the first available
        if selectedGoalTheme?.title == goalTheme.title {
            selectedGoalTheme = selectedTags.first
        }
    }
    
    // MARK: - Button Actions
    
    func handleButtonTap(allTags: [GoalTag]) {
        switch currentStage {
        case .name:
            if let template = selectedTemplate {
                // Prefill from template and go to duration without AI
                applyTemplate(template, allTags: allTags)
                currentStage = .duration
            } else {
                // New goal: go to duration immediately, then start generating suggestions in background
                currentStage = .duration
            }
        case .duration:
            // This will be handled by the View's saveGoal function
            break
        }
    }
    
    // MARK: - Checklist Generation
    
    func generateChecklist(for input: String) {
        errorMessage = nil

        Task {
            do {
                let response = try await generateTasksWithLLM(prompt: input)
                
                try await generateStreamedSuggestions()
                await MainActor.run {
                    let wrapped = GoalEditorSuggestionsResult(suggestions: response)
                    self.result = wrapped.asPartiallyGenerated()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func generateTasksWithLLM(prompt: String) async throws -> [GoalSuggestion] {
        let session = LanguageModelSession()
        let goalsResult = try await session.respond(
            to: Prompt("Come up with up to three separate goals for the user to add based on their input, including how long to spend on each goal. Return the goals as a list of dictionaries with the short title and duration (no more than 30 minutes) in the separate property, not the title. Be specific, e.g. 'Cardio' instea of 'Exercise routine'. Include things like gardening, reading a book, or learning a new skill, playing a musical instrument."),
            generating: [GoalSuggestion].self,
            includeSchemaInPrompt: false,
            options: GenerationOptions(temperature: 0.5)
        )
        return goalsResult.content
    }
    
    func generateStreamedSuggestions() async throws {
        
        let session = LanguageModelSession()

        let stream = session.streamResponse(generating: GoalEditorSuggestionsResult.self) {
            

            "Come up with up to 10 separate goals for the user to add based on their input, including how long to spend on each goal. Return the goals as a list of dictionaries with the short title, subtitle, description and duration (no more than 30 minutes) in the separate property, not the title. Be specific, e.g. 'Cardio' instead of 'Exercise routine'. Include things like gardening, reading a book, or learning a new skill, playing a musical instrument. Make it 100% relevant to: \(userInput)"
        }
        
        for try await partialResponse in stream {
            // Handle each partial response here
            await MainActor.run {
                self.result = partialResponse.content
            }
        }
    }
}
