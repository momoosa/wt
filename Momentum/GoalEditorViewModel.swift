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
import UserNotifications
import FamilyControls
#if os(iOS)
import WidgetKit
#endif

@Observable
class GoalEditorViewModel: Identifiable {
    let id = UUID()
    
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
    var currentStage: EditorStage = .name {
        didSet {
            print("§  \(currentStage)")
        }
    }
    var result: GoalEditorSuggestionsResult.PartiallyGenerated?
    private var errorMessage: String?
    private var generationTask: Task<Void, Never>?
    var selectedSuggestion: GoalSuggestion.PartiallyGenerated?
    
    // MARK: - Theme Recommendation (on-device LLM)
    
    /// The recommended theme preset from the on-device model, ready to apply
    var recommendedTheme: ThemePreset?
    /// The recommended icon from the on-device model
    var recommendedIcon: String?
    /// Whether a recommendation is currently in flight
    var isRecommendingTheme: Bool = false
    /// Task handle for the recommendation so we can cancel on new input
    private var themeRecommendationTask: Task<Void, Never>?
    
    /// Recommended daily target in minutes, computed from historical average
    var recommendedDailyMinutes: Int?
    
    // MARK: - Template & Suggestions
    
    var selectedTemplate: GoalTemplateSuggestion?
    var selectedCategoryIndex: Int = -2
    var suggestionsData: GoalSuggestionsData
    
    // Alias map for suggestion autocomplete
    let suggestionAliases: [String: [String]] = [
        // Keyed by canonical suggestion title (case-insensitive matching will be used)
        "Meditation": ["meditate", "rest", "mindfulness", "breathing"],
        "Run": ["running", "jog", "jogging", "cardio"],
        "Reading": ["read", "book", "books"],
        "Journal": ["journaling", "write journal", "diary"],
        "Yoga": ["stretching", "stretch", "asanas"],
        "Walk": ["walking", "steps"],
    ]
    
    // MARK: - Theme & Appearance
    
    var selectedGoalTheme: GoalTag?
    var selectedColorPreset: ThemePreset?
    var showingColorPicker: Bool = false
    var selectedIcon: String?
    var showingIconPicker: Bool = false
    
    // MARK: - Tags
    
    var selectedTags: [GoalTag] = []
    var showingTagPicker: Bool = false
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
    
    var selectedGoalType: Goal.TargetUnit = .seconds
    var primaryMetricTarget: Double = 0
    var dailyTargets: [Int: Int] = [:]
    
    // MARK: - Validation
    
    var validationMessage: String = ""
    var showingValidationAlert: Bool = false
    
    // MARK: - Screen Time
    
    var screenTimeEnabled: Bool = false
    var selectedScreenTimeCategories: Set<String> = []
    var screenTimeSelection: FamilyActivitySelection = FamilyActivitySelection()
    
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
    var hasMaxWindSpeed: Bool = false
    var maxWindSpeed: Double = 30 // km/h default
    
    // MARK: - Location Triggers
    
    var locationEnabled: Bool = false
    var locationLatitude: Double?
    var locationLongitude: Double?
    var locationRadius: Double = 200 // meters
    var locationName: String = ""
    
    // MARK: - Relevance Rule
    
    var dayAvailabilities: [Int: DayAvailability] = {
        var avail: [Int: DayAvailability] = [:]
        for weekday in 1...7 {
            avail[weekday] = .open
        }
        return avail
    }()
    var signalStrengths: [SignalType: SignalStrength] = [:]
    var conditionMatchMode: ConditionMatchMode = .all
    var showingRelevanceRuleSheet: Bool = false
    
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
            let newTag = GoalTag(title: "General", themeID: preset.id)
            selectedGoalTheme = newTag
            selectedTags.append(newTag)
        }
        
        showingColorPicker = false
    }
    
    var activeThemePreset: ThemePreset? {
        if let selectedPreset = selectedColorPreset {
            return selectedPreset
        } else if let selectedTheme = selectedGoalTheme {
            return selectedTheme.theme
        } else if let template = selectedTemplate,
                  let category = suggestionsData.categories.first(where: { $0.suggestions.contains(where: { $0.id == template.id }) }) {
            return matchTheme(named: category.color)
        } else if let recommended = recommendedTheme {
            return recommended
        }
        return nil
    }
    
    func activeThemeColor(for colorScheme: ColorScheme) -> Color {
        activeThemePreset?.color(for: colorScheme) ?? .accentColor
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
        durationInMinutes = goal.targetUnit.isTimeBased ? Int(goal.unifiedWeeklyTarget / 60) : 0
        
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
                if let customTarget = goal.perDayTargets[String(weekday)], goal.targetUnit.isTimeBased {
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
        selectedGoalType = goal.targetUnit
        selectedHealthKitMetric = goal.healthKitMetric
        healthKitSyncEnabled = goal.healthKitSyncEnabled

        // Load or set default primary metric target
        if goal.targetUnit == .screenTime {
            // Screen time stores daily target in seconds, convert to minutes for display
            primaryMetricTarget = goal.unifiedDailyTarget > 0 ? goal.unifiedDailyTarget / 60 : 120
            screenTimeEnabled = goal.screenTimeEnabled
        } else if !goal.targetUnit.isTimeBased && goal.unifiedDailyTarget > 0 {
            primaryMetricTarget = goal.unifiedDailyTarget
        } else {
            // Set defaults based on goal type for migrated goals
            switch goal.targetUnit {
            case .seconds:
                primaryMetricTarget = 0
            case .steps:
                primaryMetricTarget = 10000 // Default: 10,000 steps
            case .kilocalories:
                primaryMetricTarget = 500 // Default: 500 calories
            case .screenTime:
                primaryMetricTarget = 120 // Default: 2 hours
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
        if let maxWind = goal.maxWindSpeed {
            hasMaxWindSpeed = true
            maxWindSpeed = maxWind
        }
        
        // Load location settings
        locationEnabled = goal.locationEnabled
        if let lat = goal.locationLatitude, let lon = goal.locationLongitude {
            locationLatitude = lat
            locationLongitude = lon
            locationName = goal.locationName ?? ""
            locationRadius = goal.locationRadius ?? 200
        }
        
        // Load relevance rule
        if goal.hasRelevanceRule {
            for weekday in 1...7 {
                dayAvailabilities[weekday] = goal.dayAvailability(for: weekday)
            }
        } else {
            // Migrate from legacy: active days → .preferred, inactive → .open
            for weekday in 1...7 {
                if activeDays.contains(weekday) {
                    dayAvailabilities[weekday] = .preferred
                } else {
                    dayAvailabilities[weekday] = .open
                }
            }
        }
        
        // Load signal strengths
        for signalType in SignalType.allCases {
            signalStrengths[signalType] = goal.signalStrength(for: signalType)
        }
        
        // Go straight to duration stage when editing
        currentStage = .duration
    }
    
    // MARK: - Goal Type Helpers
    
    var goalTypeUnit: String {
        selectedGoalType.label
    }
    
    /// Suggested target values based on goal type
    var targetSuggestions: [Int] {
        switch selectedGoalType {
        case .seconds:
            return []
        case .steps:
            return [5000, 7500, 10000, 12500]
        case .kilocalories:
            return [200, 300, 500, 750]
        case .screenTime:
            return [30, 60, 90, 120, 180, 240]
        }
    }
    
    var calculatedWeeklyTarget: Int {
        switch selectedGoalType {
        case .seconds:
            // Sum the actual daily targets for time-based goals
            return dailyTargets.values.reduce(0, +)
        case .steps, .kilocalories:
            return Int(primaryMetricTarget * Double(activeDays.count))
        case .screenTime:
            return Int(primaryMetricTarget * Double(activeDays.count))
        }
    }
    
    /// Redistributes a new weekly total evenly across active days
    func updateWeeklyTarget(_ newWeeklyMinutes: Int) {
        let dayCount = max(activeDays.count, 1)
        // Enforce minimum 1 minute per day for time-based goals
        let clampedWeekly = max(newWeeklyMinutes, dayCount * 1)
        let baseDailyMinutes = clampedWeekly / dayCount
        let remainder = clampedWeekly % dayCount
        let sortedDays = activeDays.sorted()
        for (index, weekday) in sortedDays.enumerated() {
            dailyTargets[weekday] = max(baseDailyMinutes + (index < remainder ? 1 : 0), 1)
        }
        durationInMinutes = clampedWeekly
    }
    
    func validatePrimaryMetricTarget() {
        guard primaryMetricTarget > 0 else {
            switch selectedGoalType {
            case .seconds: primaryMetricTarget = 0
            case .steps:
                primaryMetricTarget = 100
                validationMessage = "Target set to minimum: 100 steps"
                showingValidationAlert = true
            case .kilocalories:
                primaryMetricTarget = 50
                validationMessage = "Target set to minimum: 50 calories"
                showingValidationAlert = true
            case .screenTime:
                primaryMetricTarget = 15
                validationMessage = "Target set to minimum: 15 minutes"
                showingValidationAlert = true
            }
            return
        }

        switch selectedGoalType {
        case .seconds: break
        case .steps:
            if primaryMetricTarget > 100000 {
                primaryMetricTarget = 100000
                validationMessage = "Target adjusted to maximum: 100,000 steps"
                showingValidationAlert = true
            } else if primaryMetricTarget < 100 {
                primaryMetricTarget = 100
                validationMessage = "Target adjusted to minimum: 100 steps"
                showingValidationAlert = true
            }
        case .kilocalories:
            if primaryMetricTarget > 10000 {
                primaryMetricTarget = 10000
                validationMessage = "Target adjusted to maximum: 10,000 calories"
                showingValidationAlert = true
            } else if primaryMetricTarget < 50 {
                primaryMetricTarget = 50
                validationMessage = "Target adjusted to minimum: 50 calories"
                showingValidationAlert = true
            }
        case .screenTime:
            if primaryMetricTarget > 1440 {
                primaryMetricTarget = 1440
                validationMessage = "Target adjusted to maximum: 24 hours"
                showingValidationAlert = true
            } else if primaryMetricTarget < 15 {
                primaryMetricTarget = 15
                validationMessage = "Target adjusted to minimum: 15 minutes"
                showingValidationAlert = true
            }
        }
    }
    
    func handleGoalTypeChange(_ newType: Goal.TargetUnit) {
        switch newType {
        case .seconds:
            selectedHealthKitMetric = nil
            healthKitSyncEnabled = false
            screenTimeEnabled = false
        case .steps:
            selectedHealthKitMetric = .stepCount
            healthKitSyncEnabled = true
            primaryMetricTarget = 10000
            screenTimeEnabled = false
        case .kilocalories:
            selectedHealthKitMetric = .activeEnergyBurned
            healthKitSyncEnabled = true
            primaryMetricTarget = 500
            screenTimeEnabled = false
        case .screenTime:
            selectedHealthKitMetric = nil
            healthKitSyncEnabled = false
            screenTimeEnabled = true
            primaryMetricTarget = 120 // Default 2 hours
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
        let dayCount = max(targetDays.count, 1)
        let baseDailyMinutes = template.duration / dayCount
        let remainder = template.duration % dayCount
        let sortedDays = targetDays.sorted()
        for (index, weekday) in sortedDays.enumerated() {
            dailyTargets[weekday] = max(baseDailyMinutes + (index < remainder ? 1 : 0), 1)
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
        
        // Create GoalTheme based on the category color
        let matchedTheme = matchTheme(named: category.color)
        selectedColorPreset = matchedTheme
        
        // Check if a tag with the category name already exists in the database
        let existingTag = allTags.first(where: { $0.title.caseInsensitiveCompare(categoryName) == .orderedSame })
        
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
        if let goalTypeString = template.goalType {
            switch goalTypeString {
            case "count": selectedGoalType = .steps
            case "calories": selectedGoalType = .kilocalories
            case "screentime":
                selectedGoalType = .screenTime
                handleGoalTypeChange(.screenTime)
            default: selectedGoalType = .seconds
            }
        } else {
            selectedGoalType = .seconds
        }

        // Set primary metric target if specified, reset otherwise
        primaryMetricTarget = template.primaryMetricTarget ?? 0

        print("✨ Template Applied:")
        print("   Title: \(template.title)")
        print("   Duration: \(template.duration) min")
        print("   Daily Minutes: \(baseDailyMinutes) min per day")
        print("   Goal Type: \(selectedGoalType)")
        print("   Primary Target: \(primaryMetricTarget)")
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
    
    // MARK: - Schedule Navigation Helpers
    
    /// Get the next active schedule day after the given weekday (or first if nil)
    func getNextActiveScheduleDay(after weekday: Int?) -> Int? {
        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun
        
        if let currentDay = weekday {
            // Find next active day after current
            guard let currentIndex = orderedWeekdays.firstIndex(of: currentDay) else { return nil }
            let remainingDays = orderedWeekdays[(currentIndex + 1)...]
            return remainingDays.first(where: { activeDays.contains($0) })
        } else {
            // Return first active day
            return orderedWeekdays.first(where: { activeDays.contains($0) })
        }
    }
    
    /// Get the previous active schedule day before the given weekday (or last if nil)
    func getPreviousActiveScheduleDay(before weekday: Int?) -> Int? {
        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun
        
        if let currentDay = weekday {
            // Find previous active day before current
            guard let currentIndex = orderedWeekdays.firstIndex(of: currentDay) else { return nil }
            let previousDays = orderedWeekdays[..<currentIndex]
            return previousDays.reversed().first(where: { activeDays.contains($0) })
        } else {
            // Return last active day
            return orderedWeekdays.reversed().first(where: { activeDays.contains($0) })
        }
    }
    
    /// Toggle a time slot for a specific weekday
    func toggleTimeSlot(weekday: Int, timeOfDay: TimeOfDay) {
        if dayTimePreferences[weekday]?.contains(timeOfDay) ?? false {
            dayTimePreferences[weekday]?.remove(timeOfDay)
            
            // If all time slots are now unchecked, deactivate the day
            if dayTimePreferences[weekday]?.isEmpty ?? true {
                activeDays.remove(weekday)
                dailyTargets.removeValue(forKey: weekday)
            }
        } else {
            dayTimePreferences[weekday, default: []].insert(timeOfDay)
        }
    }
    
    // MARK: - Relevance Rule
    
    /// Cycle a day through preferred → open → never → preferred.
    func cycleDayAvailability(_ weekday: Int) {
        let current = dayAvailabilities[weekday] ?? .open
        dayAvailabilities[weekday] = current.next
        syncActiveDaysFromAvailabilities()
    }
    
    /// Keep legacy activeDays in sync with dayAvailabilities.
    func syncActiveDaysFromAvailabilities() {
        activeDays = Set((1...7).filter { dayAvailabilities[$0] != .never })
        for weekday in 1...7 where dayAvailabilities[weekday] == .never {
            dailyTargets.removeValue(forKey: weekday)
        }
    }
    
    /// Compact summary for the goal editor row.
    var compactRelevanceSummary: String {
        let weekdayAbbrevs = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var parts: [String] = []
        
        let preferred = (1...7).filter { dayAvailabilities[$0] == .preferred }
        if !preferred.isEmpty {
            parts.append(preferred.map { weekdayAbbrevs[$0] }.joined(separator: ", "))
        } else {
            parts.append("Any day")
        }
        
        var signals: [String] = []
        // Time of day summary
        let allTimes = (1...7).flatMap { dayTimePreferences[$0] ?? [] }
        let uniqueTimes = Set(allTimes)
        if !uniqueTimes.isEmpty && uniqueTimes.count < TimeOfDay.allCases.count {
            signals.append(uniqueTimes.sorted().map { $0.displayName }.joined(separator: ", "))
        }
        // Weather summary
        if weatherEnabled && !selectedWeatherConditions.isEmpty {
            signals.append(selectedWeatherConditions.map { $0.displayName }.joined(separator: ", "))
        }
        if weatherEnabled && hasMaxWindSpeed {
            signals.append("wind ≤\(Int(maxWindSpeed)) km/h")
        }
        if locationEnabled && locationLatitude != nil {
            signals.append(locationName.isEmpty ? "📍 location" : "📍 \(locationName)")
        }
        
        if !signals.isEmpty {
            parts.append(signals.joined(separator: " / "))
        }
        
        return parts.joined(separator: " · ")
    }
    
    /// Full natural-language summary for the relevance rule screen.
    var relevanceRuleSummary: String {
        let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var parts: [String] = []
        
        let preferred = (1...7).filter { dayAvailabilities[$0] == .preferred }
        let never = (1...7).filter { dayAvailabilities[$0] == .never }
        
        if !preferred.isEmpty {
            parts.append("Usually \(preferred.map { weekdayNames[$0] }.joined(separator: ", "))")
        }
        
        var signalDescriptions: [String] = []
        let allTimes = (1...7).flatMap { dayTimePreferences[$0] ?? [] }
        let uniqueTimes = Set(allTimes)
        if !uniqueTimes.isEmpty && uniqueTimes.count < TimeOfDay.allCases.count {
            signalDescriptions.append(uniqueTimes.sorted().map { $0.displayName.lowercased() }.joined(separator: " or "))
        }
        if weatherEnabled && !selectedWeatherConditions.isEmpty {
            signalDescriptions.append(selectedWeatherConditions.map { $0.displayName.lowercased() }.joined(separator: " or "))
        }
        if weatherEnabled && hasMaxWindSpeed {
            signalDescriptions.append("wind ≤\(Int(maxWindSpeed)) km/h")
        }
        if !signalDescriptions.isEmpty {
            parts.append("Promoted when \(signalDescriptions.joined(separator: " or "))")
        }
        
        if !never.isEmpty {
            parts.append("Never \(never.map { weekdayNames[$0] }.joined(separator: ", "))")
        }
        
        let openCount = (1...7).filter { dayAvailabilities[$0] == .open }.count
        if openCount > 0 {
            let estimatedTimes = max(preferred.count, 1)
            parts.append("≈ \(estimatedTimes)× this week · still openable anytime")
        }
        
        return parts.joined(separator: ". ") + (parts.isEmpty ? "No rules configured" : ".")
    }
    
    /// Remove a signal entirely (clear its values and strength).
    func removeSignal(_ signalType: SignalType) {
        signalStrengths.removeValue(forKey: signalType)
        switch signalType {
        case .timeOfDay:
            for weekday in 1...7 {
                dayTimePreferences[weekday] = Set(TimeOfDay.allCases)
            }
        case .weather:
            weatherEnabled = false
            selectedWeatherConditions.removeAll()
            hasMinTemperature = false
            hasMaxTemperature = false
            hasMaxWindSpeed = false
        case .location:
            locationEnabled = false
            locationLatitude = nil
            locationLongitude = nil
            locationName = ""
            locationRadius = 200
        }
    }
    
    /// Cycle a signal's strength: boost → require → avoid → boost.
    func toggleSignalStrength(_ signalType: SignalType) {
        let current = signalStrengths[signalType] ?? .boost
        switch current {
        case .boost: signalStrengths[signalType] = .require
        case .require: signalStrengths[signalType] = .avoid
        case .avoid: signalStrengths[signalType] = .boost
        }
    }
    
    /// Whether a signal type currently has configured values.
    func hasSignalConfigured(_ signalType: SignalType) -> Bool {
        switch signalType {
        case .timeOfDay:
            let allTimes = (1...7).flatMap { dayTimePreferences[$0] ?? [] }
            let uniqueTimes = Set(allTimes)
            return !uniqueTimes.isEmpty && uniqueTimes.count < TimeOfDay.allCases.count
        case .weather:
            return weatherEnabled && (!selectedWeatherConditions.isEmpty || hasMinTemperature || hasMaxTemperature || hasMaxWindSpeed)
        case .location:
            return locationEnabled && locationLatitude != nil
        }
    }
    
    /// Summary text for a specific signal's current configuration.
    func signalValueSummary(_ signalType: SignalType) -> String {
        switch signalType {
        case .timeOfDay:
            let allTimes = (1...7).flatMap { dayTimePreferences[$0] ?? [] }
            let uniqueTimes = Set(allTimes)
            if uniqueTimes.isEmpty || uniqueTimes.count >= TimeOfDay.allCases.count {
                return "Any time"
            }
            return uniqueTimes.sorted().map { $0.displayName.lowercased() }.joined(separator: ", ")
        case .weather:
            if !weatherEnabled || (selectedWeatherConditions.isEmpty && !hasMinTemperature && !hasMaxTemperature && !hasMaxWindSpeed) { return "Not set" }
            var parts: [String] = []
            if !selectedWeatherConditions.isEmpty {
                parts.append(selectedWeatherConditions.map { $0.displayName.lowercased() }.joined(separator: ", "))
            }
            if hasMaxWindSpeed {
                parts.append("wind ≤\(Int(maxWindSpeed)) km/h")
            }
            return parts.isEmpty ? "Not set" : parts.joined(separator: " · ")
        case .location:
            if !locationEnabled || locationLatitude == nil { return "Not set" }
            return locationName.isEmpty ? "Pinned location" : locationName
        }
    }
    
    // MARK: - Button Actions
    
    func handleButtonTap(allTags: [GoalTag]) {
        switch currentStage {
        case .name:
            // Cancel any in-flight suggestion generation to prevent stale result updates
            generationTask?.cancel()
            generationTask = nil
            
            if let template = selectedTemplate {
                // Prefill from template and go to duration without AI
                applyTemplate(template, allTags: allTags)
                currentStage = .duration
            } else {
                // New freeform goal: apply LLM-recommended theme/icon if available
                applyRecommendedThemeIfNeeded(allTags: allTags)
                
                // Infer icon from title if LLM didn't provide one
                inferIconFromInput()
                
                // Populate daily targets from default duration
                if dailyTargets.isEmpty {
                    let dayCount = max(activeDays.count, 1)
                    let baseDailyMinutes = durationInMinutes / dayCount
                    let remainder = durationInMinutes % dayCount
                    let sortedDays = activeDays.sorted()
                    for (index, weekday) in sortedDays.enumerated() {
                        // Distribute remainder across first few days so weekly total is exact
                        dailyTargets[weekday] = max(baseDailyMinutes + (index < remainder ? 1 : 0), 1)
                    }
                }
                currentStage = .duration
            }
        case .duration:
            // This will be handled by the View's saveGoal function
            break
        }
    }
    
    // MARK: - Paste Bullet List to Checklist
    
    /// Parses pasted text containing bullet points, numbered lists, or plain lines
    /// and appends them as checklist items.
    ///
    /// Lines with a bullet/number/checkbox prefix start new checklist items.
    /// Lines that are indented or plain continuation text (no prefix) after a
    /// prefixed item become notes on that item. If no lines have any prefix,
    /// every line becomes its own checklist item.
    func importChecklistFromText(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        let bulletPrefixes: [String] = ["•", "-", "*", ">", "☐", "□", "▪", "▸", "–", "—", "·"]
        
        /// Returns the cleaned text and whether a structural prefix was found.
        func stripPrefix(_ input: String) -> (cleaned: String, hadPrefix: Bool) {
            var cleaned = input
            var hadPrefix = false
            
            // Strip bullet prefixes
            for prefix in bulletPrefixes {
                if cleaned.hasPrefix(prefix) {
                    cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    hadPrefix = true
                    break
                }
            }
            
            // Strip numbered list prefixes: "1.", "1)", "1:", "(1)"
            if let match = cleaned.range(of: #"^\(?(\d+)[.):]\)?\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                hadPrefix = true
            }
            
            // Strip markdown checkbox prefixes: "[ ]", "[x]", "[X]"
            if let match = cleaned.range(of: #"^\[[ xX]?\]\s*"#, options: .regularExpression) {
                cleaned = String(cleaned[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                hadPrefix = true
            }
            
            return (cleaned, hadPrefix)
        }
        
        // First pass: check if any top-level (non-indented) line has a structural
        // prefix. If none do, treat every line as a separate item (plain list).
        let hasAnyPrefix = lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
            let indented = leading.count >= 2 || leading.contains("\t")
            guard !indented else { return false }
            return stripPrefix(trimmed).hadPrefix
        }
        
        var newItems: [ChecklistItemData] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" })
            let isIndented = leadingWhitespace.count >= 2 || leadingWhitespace.contains("\t")
            
            let (cleaned, hadPrefix) = stripPrefix(trimmed)
            guard !cleaned.isEmpty else { continue }
            
            // Indented lines are always notes on the preceding item
            if isIndented, !newItems.isEmpty {
                let lastIndex = newItems.count - 1
                if newItems[lastIndex].notes.isEmpty {
                    newItems[lastIndex].notes = cleaned
                } else {
                    newItems[lastIndex].notes += "\n" + cleaned
                }
            } else if !hasAnyPrefix {
                // No prefixes found anywhere — each line is its own item
                newItems.append(ChecklistItemData(title: cleaned))
            } else if !hadPrefix, !newItems.isEmpty {
                // Plain continuation line after a prefixed item — append as notes
                let lastIndex = newItems.count - 1
                if newItems[lastIndex].notes.isEmpty {
                    newItems[lastIndex].notes = cleaned
                } else {
                    newItems[lastIndex].notes += "\n" + cleaned
                }
            } else {
                newItems.append(ChecklistItemData(title: cleaned))
            }
        }
        
        guard !newItems.isEmpty else { return }
        checklistItems.append(contentsOf: newItems)
    }
    
    // MARK: - Checklist Generation
    
    func generateChecklist(for input: String) {
        errorMessage = nil
        generationTask?.cancel()

        generationTask = Task {
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
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.result = partialResponse.content
            }
        }
    }
    
    // MARK: - Theme Recommendation
    
    /// Kicks off an on-device LLM call to recommend a theme and icon for the given title.
    /// Cancels any previous in-flight recommendation.
    func recommendTheme(for title: String) {
        themeRecommendationTask?.cancel()
        
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            recommendedTheme = nil
            recommendedIcon = nil
            return
        }
        
        isRecommendingTheme = true
        
        let themeTitles = ThemeStore.presets.map(\.title).joined(separator: ", ")
        
        themeRecommendationTask = Task {
            defer { 
                Task { @MainActor in self.isRecommendingTheme = false }
            }
            
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(
                    to: "Given the goal title \"\(trimmed)\", pick the single most fitting color theme and SF Symbol icon. Available themes: \(themeTitles). Return the exact theme title and a valid SF Symbol name.",
                    generating: ThemeRecommendationResult.self
                )
                
                guard !Task.isCancelled else { return }
                
                let result = response.content
                
                // Match the theme title to an actual preset
                let matched = ThemeStore.presets.first { $0.title.caseInsensitiveCompare(result.themeTitle) == .orderedSame }
                    ?? ThemeStore.presets.first { $0.title.localizedCaseInsensitiveContains(result.themeTitle) }
                
                await MainActor.run {
                    self.recommendedTheme = matched
                    self.recommendedIcon = result.iconName
                }
            } catch {
                // Silently fail — recommendation is best-effort
            }
        }
    }
    
    /// Applies the LLM-recommended theme and icon if no user selection has been made.
    func applyRecommendedThemeIfNeeded(allTags: [GoalTag]) {
        // Don't override if the user already picked a color or template
        guard selectedColorPreset == nil,
              selectedGoalTheme == nil,
              selectedTemplate == nil else { return }
        
        if let preset = recommendedTheme {
            handleColorSelection(preset)
        }
        
        if let icon = recommendedIcon, selectedIcon == nil {
            selectedIcon = icon
        }
    }
    
    // MARK: - Recommended Target
    
    /// Computes the recommended daily target from historical session averages
    func computeRecommendedTarget(modelContext: ModelContext) {
        guard let goal = existingGoal else { return }
        let goalIDString = goal.id.uuidString
        
        do {
            let descriptor = FetchDescriptor<Day>()
            let allDays = try modelContext.fetch(descriptor)
            
            var totalSeconds: Double = 0
            var sessionDayCount = 0
            
            for day in allDays {
                guard let sessions = day.historicalSessions else { continue }
                let dayTotal = sessions
                    .filter { $0.goalIDs.contains(goalIDString) }
                    .reduce(0.0) { $0 + $1.duration }
                if dayTotal > 0 {
                    totalSeconds += dayTotal
                    sessionDayCount += 1
                }
            }
            
            guard sessionDayCount >= 3 else { return } // Need enough data
            
            let avgMinutes = Int((totalSeconds / Double(sessionDayCount)) / 60.0)
            if avgMinutes > 0 {
                recommendedDailyMinutes = avgMinutes
            }
        } catch {
            // Silently fail
        }
    }
    
    // MARK: - Save Goal
    
    func saveGoal(
        modelContext: ModelContext,
        allGoals: [Goal],
        calculatedWeeklyTarget: Int,
        currentPlanTimestamp: Double,
        onRequestNotificationPermissions: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) async throws -> Double {
        // Validate primary metric target before saving
        validatePrimaryMetricTarget()
        
        let goal: Goal
        let isEditing = existingGoal != nil
        
        // Track if goal was scheduled for today before editing (for toast notification)
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())
        let hadAnyScheduleForToday = existingGoal?.timesForWeekday(todayWeekday).isEmpty == false
        
        // Fetch existing tags to avoid creating duplicates
        let existingTags = (try? modelContext.fetch(FetchDescriptor<GoalTag>())) ?? []
        
        // Determine theme based on user selection or suggestion
        let finalGoalTag: GoalTag
        if let customGoalTag = selectedGoalTheme {
            // User has selected a tag (either custom or from suggestions)
            finalGoalTag = customGoalTag
        } else if let template = selectedTemplate,
                  let category = suggestionsData.categories.first(where: { $0.suggestions.contains(where: { $0.id == template.id }) }) {
            // Use the category's theme to create a tag
            let matchedTheme = matchTheme(named: category.color)
            finalGoalTag = existingTags.first(where: { $0.title.caseInsensitiveCompare(category.name) == .orderedSame })
                ?? GoalTag(title: category.name, themeID: matchedTheme.id)
        } else if let selectedSuggestion = selectedSuggestion, let themeNames = selectedSuggestion.themes, !themeNames.isEmpty {
            // Use the first theme from generated suggestions
            let matchedTheme = matchTheme(named: themeNames[0])
            finalGoalTag = existingTags.first(where: { $0.title.caseInsensitiveCompare("General") == .orderedSame })
                ?? GoalTag(title: "General", themeID: matchedTheme.id)
        } else {
            // Find an unused theme, or fall back to random
            let unusedTheme = findUnusedTheme(excluding: allGoals)
            finalGoalTag = existingTags.first(where: { $0.title.caseInsensitiveCompare("General") == .orderedSame })
                ?? GoalTag(title: "General", themeID: unusedTheme.id)
        }
        
        // Debug print day-time schedule
        if !dayTimePreferences.isEmpty {
            print("\n📅 Day-Time Schedule:")
            let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            for (weekday, times) in dayTimePreferences.sorted(by: { $0.key < $1.key }) where !times.isEmpty {
                let timeStrings = times.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.displayName }
                print("   \(weekdayNames[weekday]): \(timeStrings.joined(separator: ", "))")
            }
        }
      
        if let existingGoal = existingGoal {
            // Update existing goal
            goal = existingGoal
            goal.title = userInput
            goal.primaryTag = finalGoalTag
            goal.themeID = finalGoalTag.themeID
            goal.iconName = selectedIcon
            goal.scheduleNotificationsEnabled = scheduleNotificationsEnabled
            goal.completionNotificationsEnabled = completionNotificationsEnabled
            goal.completionBehaviors = selectedCompletionBehaviors
            goal.healthKitMetric = selectedHealthKitMetric
            goal.healthKitSyncEnabled = healthKitSyncEnabled
            goal.notes = goalNotes.isEmpty ? nil : goalNotes
            goal.link = goalLink.isEmpty ? nil : goalLink
            
            // Clear existing schedule and set new one
            goal.dayTimeSchedule.removeAll()
        } else {
            // Create new goal
            let title = selectedSuggestion?.title ?? userInput
            goal = Goal(
                title: title,
                primaryTag: finalGoalTag,
                scheduleNotificationsEnabled: scheduleNotificationsEnabled,
                completionNotificationsEnabled: completionNotificationsEnabled,
                healthKitMetric: selectedHealthKitMetric,
                healthKitSyncEnabled: healthKitSyncEnabled
            )
            goal.themeID = finalGoalTag.themeID
            goal.iconName = selectedIcon
            goal.dailyMinimum = hasDailyMinimum ? TimeInterval((dailyMinimumMinutes ?? 10) * 60) : nil
            goal.completionBehaviors = selectedCompletionBehaviors
            goal.notes = goalNotes.isEmpty ? nil : goalNotes
            goal.link = goalLink.isEmpty ? nil : goalLink
        }
        
        // ✅ Save the day-time schedule using the convenience method
        // For active days, use their time preferences, or default to all times if not set
        for weekday in 1...7 {
            if activeDays.contains(weekday) {
                // Day is active - use specified times or default to all times
                let times = dayTimePreferences[weekday] ?? Set(TimeOfDay.allCases)
                goal.setTimes(times, forWeekday: weekday)
            } else {
                // Day is not active - clear any time preferences
                goal.setTimes([], forWeekday: weekday)
            }
        }
        
        // ✅ Save unified target system
        goal.targetUnit = selectedGoalType
        switch selectedGoalType {
        case .seconds:
            let avgDailySeconds = activeDays.isEmpty ? 1800.0 : Double(calculatedWeeklyTarget * 60) / Double(activeDays.count)
            goal.unifiedDailyTarget = max(avgDailySeconds, 60) // Minimum 1 minute
            goal.perDayTargets.removeAll()
            for (weekday, minutes) in dailyTargets {
                goal.perDayTargets[String(weekday)] = Double(minutes * 60)
            }
        case .steps, .kilocalories:
            goal.unifiedDailyTarget = primaryMetricTarget
            goal.perDayTargets.removeAll()
        case .screenTime:
            // primaryMetricTarget is in minutes, store as seconds
            goal.unifiedDailyTarget = primaryMetricTarget * 60
            goal.perDayTargets.removeAll()
            goal.screenTimeEnabled = true
            goal.screenTimeIsInverseGoal = true
        }
        
        // ✅ Save weather settings
        goal.weatherEnabled = weatherEnabled
        if weatherEnabled {
            goal.weatherConditionsTyped = selectedWeatherConditions.isEmpty ? nil : Array(selectedWeatherConditions)
            goal.minTemperature = hasMinTemperature ? minTemperature : nil
            goal.maxTemperature = hasMaxTemperature ? maxTemperature : nil
            goal.maxWindSpeed = hasMaxWindSpeed ? maxWindSpeed : nil
        } else {
            goal.weatherConditionsTyped = nil
            goal.minTemperature = nil
            goal.maxTemperature = nil
            goal.maxWindSpeed = nil
        }
        
        // ✅ Save location settings
        goal.locationEnabled = locationEnabled
        if locationEnabled, let lat = locationLatitude, let lon = locationLongitude {
            goal.locationLatitude = lat
            goal.locationLongitude = lon
            goal.locationName = locationName.isEmpty ? nil : locationName
            goal.locationRadius = locationRadius
        } else {
            goal.locationLatitude = nil
            goal.locationLongitude = nil
            goal.locationName = nil
            goal.locationRadius = nil
        }
        
        // ✅ Save relevance rule
        for weekday in 1...7 {
            let availability = dayAvailabilities[weekday] ?? .open
            goal.setDayAvailability(availability, for: weekday)
        }
        for (signalType, strength) in signalStrengths {
            goal.setSignalStrength(strength, for: signalType)
        }
        
        // ✅ Save checklist items
        // Remove old checklist items
        if let existingItems = goal.checklistItems {
            for item in existingItems {
                modelContext.delete(item)
            }
        }
        goal.checklistItems = []
        
        // Add new checklist items
        for item in checklistItems where !item.title.trimmingCharacters(in: .whitespaces).isEmpty {
            let checklistItem = ChecklistItem(title: item.title, notes: item.notes.isEmpty ? nil : item.notes, goal: goal)
            modelContext.insert(checklistItem)
            goal.checklistItems?.append(checklistItem)
        }
        
        print("\n✅ Goal \(isEditing ? "updated" : "saved") with schedule:")
        print(goal.scheduleSummary)
        if weatherEnabled {
            print("🌤️ Weather triggers: \(selectedWeatherConditions.map { $0.displayName }.joined(separator: ", "))")
            if hasMinTemperature { print("   Min temp: \(Int(minTemperature))°C") }
            if hasMaxTemperature { print("   Max temp: \(Int(maxTemperature))°C") }
            if hasMaxWindSpeed { print("   Max wind: \(Int(maxWindSpeed)) km/h") }
        }
        
        // Request notification permissions if enabled
        if selectedCompletionBehaviors.contains(.notify) {
            onRequestNotificationPermissions()
        }
        
        // Only insert if creating new goal
        if !isEditing {
            modelContext.insert(goal)
        }
        
        // Handle notification scheduling
        let notificationManager = GoalNotificationManager()
        
        // Schedule notifications if enabled and there's a schedule
        if scheduleNotificationsEnabled && goal.hasSchedule {
            do {
                try await notificationManager.scheduleNotifications(for: goal)
            } catch {
                print("❌ Failed to schedule notifications: \(error)")
            }
        } else {
            // Cancel schedule notifications if disabled
            await notificationManager.cancelScheduleNotifications(for: goal)
        }
        
        // Request HealthKit permissions immediately if this goal has HealthKit sync enabled
        if goal.healthKitSyncEnabled, let metric = goal.healthKitMetric {
            let healthKitManager = HealthKitManager()
            do {
                try await healthKitManager.requestAuthorization(for: [metric])
                print("✅ HealthKit authorization requested for \(metric.displayName)")
            } catch {
                print("❌ Failed to request HealthKit authorization: \(error)")
            }
        }
        
        // Start Screen Time monitoring if this is a screen time goal
        if goal.screenTimeEnabled && selectedGoalType == .screenTime {
            let screenTimeManager = ScreenTimeManager.shared
            if !screenTimeManager.isAuthorized {
                try? await screenTimeManager.requestAuthorization()
            }
            if screenTimeManager.isAuthorized {
                screenTimeManager.startMonitoring(goal: goal, selection: screenTimeSelection)
                print("✅ Screen Time monitoring started for \(goal.title)")
            }
        }
        
        // Reset the plan generation timestamp to trigger a new plan
        print("🔄 Reset plan generation timestamp - new plan will be generated")
        
        // Update all existing sessions for this goal to reflect new dailyTarget
        if isEditing {
            let calendar = Calendar.current
            let todayWeekday = calendar.component(.weekday, from: Date())
            let isNowScheduledForToday = !goal.timesForWeekday(todayWeekday).isEmpty
            
            // Fetch all sessions for this goal
            let goalID = goal.id.uuidString
            let fetchRequest = FetchDescriptor<GoalSession>(
                predicate: #Predicate<GoalSession> { session in
                    session.goalID == goalID
                }
            )
            
            if let sessions = try? modelContext.fetch(fetchRequest) {
                for session in sessions {
                    session.updateDailyTarget()
                }
                
                // Show toast if goal moved in/out of today's schedule
                if hadAnyScheduleForToday != isNowScheduledForToday {
                    let message: String
                    if isNowScheduledForToday {
                        message = "'\(goal.title)' is now available today"
                    } else {
                        message = "'\(goal.title)' is no longer scheduled for today"
                    }
                    
                    // Post notification to show toast in ContentView
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowToast"),
                        object: message
                    )
                }
            }
        } else {
            // Show toast for new goal creation
            let calendar = Calendar.current
            let todayWeekday = calendar.component(.weekday, from: Date())
            let isScheduledForToday = !goal.timesForWeekday(todayWeekday).isEmpty
            
            let message: String
            if isScheduledForToday {
                message = "'\(goal.title)' created and available in Today"
            } else {
                // Get the next scheduled day
                let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                var nextScheduledDay: String?
                
                // Check days starting from tomorrow
                for offset in 1...7 {
                    let futureDate = calendar.date(byAdding: .day, value: offset, to: Date())!
                    let futureWeekday = calendar.component(.weekday, from: futureDate)
                    if !goal.timesForWeekday(futureWeekday).isEmpty {
                        nextScheduledDay = weekdayNames[futureWeekday]
                        break
                    }
                }
                
                if let nextDay = nextScheduledDay {
                    message = "'\(goal.title)' created. Next scheduled: \(nextDay)"
                } else {
                    message = "'\(goal.title)' created with no schedule set"
                }
            }
            
            // Post notification to show toast in ContentView
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowToast"),
                object: message
            )
        }
        
        // Sync checklist changes to existing sessions
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncChecklistToSessions"),
            object: goal
        )

        // Reload widgets to show the new goal
        #if os(iOS)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Reloaded all widget timelines")
        #endif

        onDismiss()
        
        // Return reset timestamp
        return 0
    }
    
    // MARK: - Theme Color Logic
    
    /// Get the active theme color based on current selections
    func getActiveThemeColor(colorScheme: ColorScheme) -> Color {
        if let selectedPreset = selectedColorPreset {
            return selectedPreset.color(for: colorScheme)
        } else if let selectedTheme = selectedGoalTheme {
            return selectedTheme.theme.color(for: colorScheme)
        } else if let template = selectedTemplate,
                  let category = suggestionsData.categories.first(where: { $0.suggestions.contains(where: { $0.id == template.id }) }) {
            let matchedTheme = matchTheme(named: category.color)
            return matchedTheme.color(for: colorScheme)
        } else if let recommended = recommendedTheme {
            return recommended.color(for: colorScheme)
        }
        return .accentColor
    }
}

// MARK: - Generable Types for On-Device LLM

@Generable(description: "A recommended theme and icon for a goal based on its title")
struct ThemeRecommendationResult {
    @Guide(description: "The exact title of the recommended color theme")
    var themeTitle: String
    
    @Guide(description: "A valid SF Symbol name for the goal icon, e.g. 'figure.run', 'book.fill', 'music.note'")
    var iconName: String
}
