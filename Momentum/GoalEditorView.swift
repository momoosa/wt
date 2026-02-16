import SwiftUI
import FoundationModels
import MomentumKit
import SwiftData
import UserNotifications
import EventKit
#if os(iOS)
import WidgetKit
#endif

// MARK: - AI Suggestion Model
@Generable
struct GoalThemeSuggestionsResponse: Codable {
    var suggestedThemes: [String] // Array of theme names (e.g., ["Wellness", "Fitness", "Productivity"])
    var reasoning: String? // optional explanation
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allGoals: [Goal]
    
    // Optional existing goal for editing
    var existingGoal: Goal?
    
    @State private var userInput: String = ""
    @FocusState private var focusedField: Field?
    @Namespace private var buttonNamespace
    
    enum Field: Hashable {
        case goalName
        case duration
        case dailyMinimum
        case scheduleDay(Int) // weekday 1-7
    }
    @State private var result: GoalEditorSuggestionsResult.PartiallyGenerated?
    @State private var errorMessage: String?
    @State var selectedSuggestion: GoalSuggestion.PartiallyGenerated?
    @State private var currentStage: EditorStage = .name
    @State private var durationInMinutes: Int = 30
    @State private var dailyMinimumMinutes: Int? = nil
    @State private var hasDailyMinimum: Bool = false
    @State private var notificationsEnabled: Bool = false // Legacy, kept for backward compatibility
    @State private var scheduleNotificationsEnabled: Bool = false
    @State private var completionNotificationsEnabled: Bool = false
    @State private var selectedHealthKitMetric: HealthKitMetric?
    @State private var healthKitSyncEnabled: Bool = false
    @State private var suggestionsData: GoalSuggestionsData = GoalSuggestionsLoader.shared.loadSuggestions()
    @State private var selectedTemplate: GoalTemplateSuggestion?
    @State private var selectedCategoryIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var dayTimePreferences: [Int: Set<TimeOfDay>] = {
        // Initialize with all time slots enabled by default
        var preferences: [Int: Set<TimeOfDay>] = [:]
        for weekday in 1...7 {
            preferences[weekday] = Set(TimeOfDay.allCases)
        }
        return preferences
    }()
    
    // Weekday helper (1 = Sunday, 2 = Monday ... 7 = Saturday)
    private let weekdays: [(Int, String)] = [
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat"),
        (1, "Sun")
    ]
    
    // Scheduling state
    enum TimeRelation: String, CaseIterable, Identifiable { case before, after; var id: String { rawValue } }
    struct DaySchedule: Identifiable { let id = UUID(); var enabled: Bool; var relation: TimeRelation; var time: Date }
    
  
    // Simple multi-select time of day
    enum SimpleTimeOfDay: String, CaseIterable, Identifiable { case anytime = "Anytime", morning = "Morning", afternoon = "Afternoon", evening = "Evening"; var id: String { rawValue } }
    
    // Custom theme selection
    @State private var selectedGoalTheme: GoalTag?
    @State private var showingAddThemeSheet: Bool = false
    @State private var customThemeName: String = ""
    @State private var selectedBaseThemeForCustom: Theme? // For creating custom themes
    @State private var isEditingThemes: Bool = false // Track edit mode for theme sheet
    @State private var showingColorPicker: Bool = false
    @State private var selectedColorPreset: ThemePreset?
    @State private var showingIconPicker: Bool = false
    @State private var selectedIcon: String?

    @Query private var allTags: [GoalTag]
    @State private var selectedTags: [GoalTag] = []
    @State private var showingTagPicker: Bool = false
    @State private var editingTag: GoalTag?
    
    // Track if user has made any changes
    private var hasUnsavedChanges: Bool {
        // Check if user has entered text
        if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Check if user selected a template
        if selectedTemplate != nil {
            return true
        }
        
        // Check if in duration stage (means they pressed Next)
        if currentStage == .duration {
            return true
        }
        
        return false
    }
    
    // Local alias map for suggestion autocomplete
    private let suggestionAliases: [String: [String]] = [
        // Keyed by canonical suggestion title (case-insensitive matching will be used)
        "Meditation": ["meditate", "rest", "mindfulness", "breathing"],
        "Run": ["running", "jog", "jogging", "cardio"],
        "Reading": ["read", "book", "books"],
        "Journal": ["journaling", "write journal", "diary"],
        "Yoga": ["stretching", "stretch", "asanas"],
        "Walk": ["walking", "steps"],
    ]

    private func matchesSuggestion(_ suggestion: GoalTemplateSuggestion, with input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Title match
        if suggestion.title.caseInsensitiveCompare(trimmed) == .orderedSame { return true }
        // Alias match
        if let aliases = suggestionAliases[suggestion.title] {
            return aliases.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
        return false
    }
    
    enum EditorStage {
        case name
        case duration
    }
    
    // Computed property for the active theme color
    private var activeThemeColor: Color {
        if let selectedPreset = selectedColorPreset {
            return selectedPreset.color(for: colorScheme)
        } else if let selectedTheme = selectedGoalTheme {
            return selectedTheme.themePreset.color(for: colorScheme)
        } else if let template = selectedTemplate {
            let matchedTheme = matchTheme(named: template.theme)
            return matchedTheme.color(for: colorScheme)
        }
        return .accentColor
    }
    
    /// Calculate appropriate text color for buttons based on background luminance
    private var buttonTextColor: Color {
        let luminance = activeThemeColor.luminance ?? 0.5
        return luminance > 0.5 ? .black : .white
    }
    
    var body: some View {
        NavigationStack {
                    
                    List {
                            // Custom input section
                            Section {
                                TextField("What do you want to do?", text: $userInput)
                                    .focused($focusedField, equals: .goalName)
                                    .onChange(of: userInput) { _, newValue in
                                        // Clear selection if user is typing freeform
                                        if !newValue.isEmpty {
                                            selectedTemplate = nil
                                        }

                                        // Try to find a match among suggestions by title or aliases and select it
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmed.isEmpty else { return }

                                        if let (categoryIndex, matchedSuggestion) = suggestionsData.categories.enumerated().compactMap({ (idx, category) -> (Int, GoalTemplateSuggestion)? in
                                            if let suggestion = category.suggestions.first(where: { matchesSuggestion($0, with: trimmed) }) {
                                                return (idx, suggestion)
                                            }
                                            return nil
                                        }).first {
                                            // Select the template and category
                                            selectedTemplate = matchedSuggestion
                                            selectedCategoryIndex = categoryIndex

                                            // Scroll category tabs to selected category if available
                                            if let proxy = scrollProxy {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    proxy.scrollTo(categoryIndex, anchor: .center)
                                                }
                                            }
                                        }
                                        
                                        // Infer icon from user input if no icon is selected yet
                                        if selectedIcon == nil, !trimmed.isEmpty, trimmed.count >= 3 {
                                            Task { @MainActor in
                                                if selectedIcon == nil {
                                                    selectedIcon = inferIcon(from: trimmed)
                                                }
                                            }
                                        }
                                    }
                                
                            }
                        if currentStage == .name {

                            // Scrollable Category Tabs
                            Section {
                                
                                
                                VStack(spacing: 0) {
                                    ScrollViewReader { proxy in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                HStack(spacing: 12) {
                                                    // Reminders tab
                                                    RemindersTab(isSelected: selectedCategoryIndex == -1)
                                                        .id(-1)
                                                        .onTapGesture {
                                                            withAnimation(.spring(response: 0.3)) {
                                                                selectedCategoryIndex = -1
                                                            }
                                                            
                                                            // Haptic feedback
#if os(iOS)
                                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                                            generator.impactOccurred()
#endif
                                                        }
                                                    
                                                    ForEach(Array(suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                                                        CategoryTab(
                                                            category: category,
                                                            isSelected: selectedCategoryIndex == index
                                                        )
                                                        .id(index) // Add ID for scrolling
                                                        .onTapGesture {
                                                            withAnimation(.spring(response: 0.3)) {
                                                                selectedCategoryIndex = index
                                                            }
                                                            
                                                            // Haptic feedback
#if os(iOS)
                                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                                            generator.impactOccurred()
#endif
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal)
                                                .padding(.vertical)
                                            }
                                        }
                                        .onAppear {
                                            scrollProxy = proxy
                                        }
                                        .onChange(of: selectedCategoryIndex) { _, newIndex in
                                            // Auto-scroll to selected tab
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(newIndex, anchor: .center)
                                            }
                                        }
                                    }
                                    // Category Tabs
                                    TabView(selection: $selectedCategoryIndex) {
                                        // Reminders tab content
                                        RemindersTabView(
                                            userInput: $userInput,
                                            onReminderSelected: { reminder in
                                                // Fill in the goal name from reminder
                                                userInput = reminder.title ?? ""
                                                selectedTemplate = nil
                                            }
                                        )
                                        .tag(-1)
                                        
                                        ForEach(Array(suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                                            CategorySuggestionsView(
                                                category: category,
                                                selectedTemplate: $selectedTemplate,
                                                userInput: $userInput
                                            )
                                            .tag(index)
                                        }
                                    }
                                    .tabViewStyle(.page(indexDisplayMode: .never))
                                    .frame(height: 400)
                                }
                                
                            } header: {
                                Text("Suggestions")
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        
                        if currentStage == .duration {
                                                                                    
                            Section(header: Text("Weekly Goal")) {
                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Weekly Target")
                                            Spacer()
                                            Text("\(calculatedWeeklyTarget) min")
                                                .foregroundStyle(activeThemeColor)
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                        Divider()
                                        
                                        VStack(spacing: 8) {
                                            ForEach(weekdays, id: \.0) { weekday, name in
                                                ExpandableDayRow(
                                                    weekday: weekday,
                                                    name: name,
                                                    isActive: isDayActive(weekday),
                                                    minutes: dailyTargets[weekday] ?? 30,
                                                    selectedTimes: dayTimePreferences[weekday] ?? [],
                                                    themeColor: activeThemeColor,
                                                    isExpanded: expandedDay == weekday,
                                                    focusedField: $focusedField,
                                                    onToggleDay: { toggleActiveDay(weekday) },
                                                    onUpdateMinutes: { updateDailyTarget(for: weekday, minutes: $0) },
                                                    onToggleTime: { toggleTimeSlot(weekday: weekday, timeOfDay: $0) },
                                                    onToggleExpand: {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            expandedDay = (expandedDay == weekday) ? nil : weekday
                                                        }
                                                    }
                                                )
                                                
                                                if weekday != weekdays.last?.0 {
                                                    Divider()
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Color and icon picker buttons
                            Section {
                                HStack(spacing: 12) {
                                    // Color picker button
                                    Button(action: {
                                        showingColorPicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            // Color preview circle
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            selectedColorPreset?.neon ?? activeThemeColor,
                                                            selectedColorPreset?.dark ?? activeThemeColor
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 24, height: 24)
                                            
                                            Text(selectedColorPreset?.title ?? "Color")
                                                .foregroundStyle(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Icon picker button
                                    Button(action: {
                                        showingIconPicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            // Icon preview
                                            Image(systemName: selectedIcon ?? "star.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(activeThemeColor)
                                                .frame(width: 24, height: 24)
                                            
                                            Text("Icon")
                                                .foregroundStyle(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Section(header: Text("Theme")) {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Tag cloud with flow layout - show only selected themes
                                    TagFlowLayout(spacing: 8) {
                                        ForEach(selectedTags, id: \.title) { goalTheme in
                                            ThemeTagButton(
                                                goalTheme: goalTheme,
                                                isSelected: true,
                                                action: {
                                                    #if os(iOS)
                                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                                    generator.impactOccurred()
                                                    #endif
                                                },
                                                onRemove: {
                                                    removeGoalTheme(goalTheme)
                                                }
                                            )
                                        }
                                        
                                        // Add theme button
                                        Button(action: {
                                            showingAddThemeSheet = true
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 16))
                                                Text("Add Theme")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .strokeBorder(activeThemeColor, lineWidth: 2, antialiased: true)
                                            )
                                            .foregroundStyle(activeThemeColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    if selectedTags.isEmpty {
                                        Text("Tap 'Add Theme' to choose a color theme for your goal")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            Section(header: Text("Notifications")) {
                                Toggle(isOn: $scheduleNotificationsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Start Notifications")
                                            .font(.subheadline)
                                        Text("Notify at scheduled times")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Toggle(isOn: $completionNotificationsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Finish Notifications")
                                            .font(.subheadline)
                                        Text("Notify when daily goal is completed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            HealthKitConfigurationView(
                                selectedMetric: $selectedHealthKitMetric,
                                syncEnabled: $healthKitSyncEnabled
                            )
                        }
                        
                        Spacer()
                            .frame(height: 60.0)
                    }
                    .animation(.spring(), value: result)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStage)
                    
            .overlay(alignment: .bottom) {
                // Bottom button (hide when keyboard is active)
                if focusedField == nil {
                    VStack(spacing: 0) {
                        Divider()
                        if currentStage == .name {
                            Button(action: {
                                handleButtonTap()
                            }) {
                                Text("Next")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background {
                                        Capsule()
                                            .fill(buttonEnabled ? activeThemeColor : Color.gray)
                                    }
                                    .foregroundStyle(buttonEnabled ? buttonTextColor : .white)
                            }
                            .disabled(!buttonEnabled)
                            .padding()
                        } else {
                            Button(action: {
                                handleButtonTap()
                            }) {
                                Text("Save")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background {
                                        Capsule()
                                            .fill(buttonEnabled ? activeThemeColor : Color.gray)
                                    }
                                    .foregroundStyle(buttonEnabled ? buttonTextColor : .white)
                            }
                            .matchedGeometryEffect(id: "actionButton", in: buttonNamespace)
                            .disabled(!buttonEnabled)
                            .padding()
                        }
                    }
                    .frame(height: 60.0)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(currentStage == .name ? (existingGoal == nil ? "New Goal" : "Edit Goal") : "Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .tint(activeThemeColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if currentStage == .duration && existingGoal == nil {
                            // Only allow going back to name stage if creating new goal
                            withAnimation {
                                currentStage = .name
                                // Reset theme selections when going back
                                selectedTags.removeAll()
                                selectedGoalTheme = nil
                                selectedTemplate = nil
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        // Show X when editing, or when on name stage
                        // Show back arrow only when on duration stage of new goal
                        
                        Image(systemName: (currentStage == .name || existingGoal != nil) ? "xmark" : "chevron.left")
                    }

                }
                
                // Close button on duration stage
                if currentStage == .duration {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Close")
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                // Keyboard navigation toolbar
                ToolbarItemGroup(placement: .keyboard) {
                    HStack(spacing: 12) {
                        Button {
                            focusPreviousField()
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(!canFocusPrevious())
                        
                        Button {
                            focusNextField()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(!canFocusNext())
                        
                        Button {
                            focusedField = nil
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Spacer()
                    
                    // Next button (only on name stage with goalName field focused)
                    if currentStage == .name && focusedField == .goalName {
                        Button {
                            handleButtonTap()
                        } label: {
                            Text("Next")
                                .fontWeight(.semibold)
                                .foregroundStyle(activeThemeColor)
                        }
                        .disabled(!buttonEnabled)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Save button (only on duration stage)G
                    if currentStage == .duration {
                        Button {
                            saveGoal()
                        } label: {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(activeThemeColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: focusedField)
        }
        .sheet(isPresented: $showingAddThemeSheet) {
            TagSelectionSheet(
                allTags: allTags,
                selectedTags: $selectedTags,
                selectedGoalTheme: $selectedGoalTheme,
                modelContext: modelContext,
                editingTag: $editingTag
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTag) { tag in
            NavigationStack {
                GoalTagTriggersEditor(goalTag: tag)
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(
                selectedColorPreset: $selectedColorPreset,
                onSelect: { preset in
                    selectedColorPreset = preset
                    
                    // If there's an existing tag selected, update its color
                    if !selectedTags.isEmpty {
                        selectedTags[0].themeID = preset.id
                    }
                    
                    showingColorPicker = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(
                selectedIcon: $selectedIcon,
                themeColor: activeThemeColor,
                onSelect: { icon in
                    selectedIcon = icon
                    showingIconPicker = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }

        .task {
            // Load existing goal data if editing
            if let existingGoal {
                loadGoalData(from: existingGoal)
            } else if userInput.isEmpty {
                generateChecklist(for: "")
            }
        }
    }
    
    var buttonEnabled: Bool {
        switch currentStage {
        case .name:
            return selectedTemplate != nil || !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .duration:
            return true
        }
    }
    
    // MARK: - Keyboard Navigation
    
    private func focusNextField() {
        switch focusedField {
        case .goalName:
            if currentStage == .duration {
                focusedField = .duration
            }
        case .duration:
            if hasDailyMinimum {
                focusedField = .dailyMinimum
            } else if let firstActiveDay = getNextActiveScheduleDay(after: nil) {
                focusedField = .scheduleDay(firstActiveDay)
            } else {
                focusedField = nil
            }
        case .dailyMinimum:
            if let firstActiveDay = getNextActiveScheduleDay(after: nil) {
                focusedField = .scheduleDay(firstActiveDay)
            } else {
                focusedField = nil
            }
        case .scheduleDay(let weekday):
            if let nextDay = getNextActiveScheduleDay(after: weekday) {
                focusedField = .scheduleDay(nextDay)
            } else {
                focusedField = nil
            }
        case .none:
            focusedField = .goalName
        }
    }
    
    private func focusPreviousField() {
        switch focusedField {
        case .goalName:
            focusedField = nil
        case .duration:
            focusedField = .goalName
        case .dailyMinimum:
            focusedField = .duration
        case .scheduleDay(let weekday):
            if let previousDay = getPreviousActiveScheduleDay(before: weekday) {
                focusedField = .scheduleDay(previousDay)
            } else if hasDailyMinimum {
                focusedField = .dailyMinimum
            } else {
                focusedField = .duration
            }
        case .none:
            if currentStage == .duration {
                if let lastActiveDay = getPreviousActiveScheduleDay(before: nil) {
                    focusedField = .scheduleDay(lastActiveDay)
                } else if hasDailyMinimum {
                    focusedField = .dailyMinimum
                } else {
                    focusedField = .duration
                }
            } else {
                focusedField = .goalName
            }
        }
    }
    
    private func canFocusNext() -> Bool {
        switch focusedField {
        case .goalName:
            return currentStage == .duration
        case .duration:
            return hasDailyMinimum || !activeDays.isEmpty
        case .dailyMinimum:
            return !activeDays.isEmpty
        case .scheduleDay(let weekday):
            return getNextActiveScheduleDay(after: weekday) != nil
        case .none:
            return true
        }
    }
    
    private func canFocusPrevious() -> Bool {
        switch focusedField {
        case .goalName:
            return false
        case .duration:
            return true
        case .dailyMinimum:
            return true
        case .scheduleDay:
            return true
        case .none:
            return currentStage == .duration
        }
    }
    
    // MARK: - Schedule Focus Navigation Helpers
    
    /// Get the next active schedule day after the given weekday (or first if nil)
    private func getNextActiveScheduleDay(after weekday: Int?) -> Int? {
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
    private func getPreviousActiveScheduleDay(before weekday: Int?) -> Int? {
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
    
    // MARK: - Helper Functions
    
    /// Load existing goal data for editing
    private func loadGoalData(from goal: Goal) {
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
                // Use dailyMinimum as the target for all active days when editing
                dailyTargets[weekday] = dailyMinimumMinutes ?? 10
            }
        }
        
        // If no active days found, default to weekdays with default targets
        if activeDays.isEmpty {
            activeDays = Set(2...6) // Monday-Friday
            for weekday in 2...6 {
                dailyTargets[weekday] = dailyMinimumMinutes ?? 10
            }
        }
        
        notificationsEnabled = goal.notificationsEnabled
        scheduleNotificationsEnabled = goal.scheduleNotificationsEnabled
        completionNotificationsEnabled = goal.completionNotificationsEnabled
        selectedHealthKitMetric = goal.healthKitMetric
        healthKitSyncEnabled = goal.healthKitSyncEnabled
        
        // Load tag/theme
        selectedGoalTheme = goal.primaryTag
        
        // Add to selected themes
        if !selectedTags.contains(where: { $0.id == goal.primaryTag.id }) {
            selectedTags.append(goal.primaryTag)
        }
        
        // Load schedule
        for weekday in 1...7 {
            let times = goal.timesForWeekday(weekday)
            if !times.isEmpty {
                dayTimePreferences[weekday] = times
            }
        }
        
        // Go straight to duration stage when editing
        currentStage = .duration
    }
     
    /// Remove a theme from the selected themes list
    private func removeGoalTheme(_ goalTheme: GoalTag) {
        withAnimation(.spring(response: 0.3)) {
            selectedTags.removeAll(where: { $0.title == goalTheme.title })
            
            // If we removed the currently selected theme, select the first available
            if selectedGoalTheme?.title == goalTheme.title {
                selectedGoalTheme = selectedTags.first
            }
        }
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
    
    enum SchedulePreset {
        case weekdayMornings
        case everyEvening
        case weekends
        case everyDay
    }
    
    private func applyPreset(_ preset: SchedulePreset) {
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
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func toggleTimeSlot(weekday: Int, timeOfDay: TimeOfDay) {
        if dayTimePreferences[weekday]?.contains(timeOfDay) ?? false {
            dayTimePreferences[weekday]?.remove(timeOfDay)
            
            // If all time slots are now unchecked, deactivate the day
            if dayTimePreferences[weekday]?.isEmpty ?? true {
                activeDays.remove(weekday)
                dailyTargets.removeValue(forKey: weekday)
                withAnimation {
                    expandedDay = nil // Close the row when deactivating
                }
            }
        } else {
            dayTimePreferences[weekday, default: []].insert(timeOfDay)
        }
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    // MARK: - Active Days Management
    
    @State private var activeDays: Set<Int> = Set(2...6) // Default: Monday-Friday
    @State private var dailyTargets: [Int: Int] = Dictionary(uniqueKeysWithValues: (2...6).map { ($0, 10) }) // Default 10 min for weekdays
    @State private var expandedDay: Int? = nil // Track which day row is expanded (accordion-style)
    
    private func toggleActiveDay(_ weekday: Int) {
        if activeDays.contains(weekday) {
            activeDays.remove(weekday)
            dailyTargets.removeValue(forKey: weekday)
        } else {
            activeDays.insert(weekday)
            // Set default target when activating a day
            dailyTargets[weekday] = dailyMinimumMinutes ?? 10
        }
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func isDayActive(_ weekday: Int) -> Bool {
        activeDays.contains(weekday)
    }
    
    private var calculatedWeeklyTarget: Int {
        return dailyTargets.values.reduce(0, +)
    }
    
    private func updateDailyTarget(for weekday: Int, minutes: Int) {
        dailyTargets[weekday] = minutes
    }
    
    func handleButtonTap() {
        switch currentStage {
        case .name:
            if let template = selectedTemplate {
                // Prefill from template and go to duration without AI
                applyTemplate(template)
                withAnimation {
                    currentStage = .duration
                }
            } else {
                // New goal: go to duration immediately, then start generating suggestions in background
                withAnimation {
                    currentStage = .duration
                }
            }
        case .duration:
            saveGoal()
        }
    }
    
    /// Apply a template's predefined values
    func applyTemplate(_ template: GoalTemplateSuggestion) {
        // Set the title
        userInput = template.title
        
        // Set duration
        durationInMinutes = template.duration
        
        // Infer and set icon from template
        selectedIcon = inferIcon(from: template.title)
        
        // Create GoalTheme based on template's theme
        let matchedTheme = matchTheme(named: template.theme)
        
        // Check if a tag with this name already exists in the database
        let existingTag = allTags.first(where: { $0.title == template.theme })
        
        let goalTheme: GoalTag
        if let existing = existingTag {
            // Use the existing tag
            goalTheme = existing
            print("♻️ Using existing tag: \(existing.title)")
        } else {
            // Create new tag
            goalTheme = GoalTag(title: template.theme, color: matchedTheme)
            print("✨ Created new tag: \(template.theme) with theme \(matchedTheme.title)")
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
        
        print("✨ Template Applied:")
        print("   Title: \(template.title)")
        print("   Duration: \(template.duration) min")
        print("   Theme: \(template.theme)")
        print("   HealthKit: \(template.healthKitMetric ?? "none")")
    }
    
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0
    
    func saveGoal() {
        let goal: Goal
        let isEditing = existingGoal != nil
        
        // Determine theme based on user selection or suggestion
        let finalGoalTag: GoalTag
        if let customGoalTag = selectedGoalTheme {
            // User has selected a tag (either custom or from suggestions)
            finalGoalTag = customGoalTag
        } else if let template = selectedTemplate {
            // Use the template's theme to create a tag
            let matchedTheme = matchTheme(named: template.theme)
            finalGoalTag = GoalTag(title: matchedTheme.title, color: matchedTheme)
        } else if let selectedSuggestion, let themeNames = selectedSuggestion.themes, !themeNames.isEmpty {
            // Use the first theme from generated suggestions
            let matchedTheme = matchTheme(named: themeNames[0])
            finalGoalTag = GoalTag(title: matchedTheme.title, color: matchedTheme)
        } else {
            // Find an unused theme, or fall back to random
            let unusedTheme = findUnusedTheme()
            finalGoalTag = GoalTag(title: unusedTheme.title, color: unusedTheme)
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
      
        if let existingGoal {
            // Update existing goal
            goal = existingGoal
            goal.title = userInput
            goal.primaryTag = finalGoalTag
            goal.weeklyTarget = TimeInterval(calculatedWeeklyTarget * 60) // Weekly minutes to seconds
            // Calculate average daily target from per-day targets
            let avgDailyTarget = activeDays.isEmpty ? 30 : (calculatedWeeklyTarget / activeDays.count)
            goal.dailyMinimum = TimeInterval(avgDailyTarget * 60) // Average daily target in seconds
            goal.iconName = selectedIcon
            goal.notificationsEnabled = notificationsEnabled
            goal.scheduleNotificationsEnabled = scheduleNotificationsEnabled
            goal.completionNotificationsEnabled = completionNotificationsEnabled
            goal.healthKitMetric = selectedHealthKitMetric
            goal.healthKitSyncEnabled = healthKitSyncEnabled
            
            // Clear existing schedule and set new one
            goal.dayTimeSchedule.removeAll()
        } else {
            // Create new goal
            if let selectedSuggestion, let title = selectedSuggestion.title {
                goal = Goal(
                    title: title,
                    primaryTag: finalGoalTag,
                    weeklyTarget: TimeInterval(calculatedWeeklyTarget * 60), // Weekly minutes to seconds
                    notificationsEnabled: notificationsEnabled,
                    scheduleNotificationsEnabled: scheduleNotificationsEnabled,
                    completionNotificationsEnabled: completionNotificationsEnabled,
                    healthKitMetric: selectedHealthKitMetric,
                    healthKitSyncEnabled: healthKitSyncEnabled
                )
                goal.iconName = selectedIcon
                let avgDailyTarget = activeDays.isEmpty ? 30 : (calculatedWeeklyTarget / activeDays.count)
                goal.dailyMinimum = TimeInterval(avgDailyTarget * 60)
            } else {
                goal = Goal(
                    title: userInput,
                    primaryTag: finalGoalTag,
                    weeklyTarget: TimeInterval(calculatedWeeklyTarget * 60), // Weekly minutes to seconds
                    notificationsEnabled: notificationsEnabled,
                    scheduleNotificationsEnabled: scheduleNotificationsEnabled,
                    completionNotificationsEnabled: completionNotificationsEnabled,
                    healthKitMetric: selectedHealthKitMetric,
                    healthKitSyncEnabled: healthKitSyncEnabled
                )
                goal.iconName = selectedIcon
                let avgDailyTarget = activeDays.isEmpty ? 30 : (calculatedWeeklyTarget / activeDays.count)
                goal.dailyMinimum = TimeInterval(avgDailyTarget * 60)
                goal.dailyMinimum = hasDailyMinimum ? TimeInterval((dailyMinimumMinutes ?? 10) * 60) : nil
            }
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
        
        print("\n✅ Goal \(isEditing ? "updated" : "saved") with schedule:")
        print(goal.scheduleSummary)
        
        // Request notification permissions if enabled
        if scheduleNotificationsEnabled || completionNotificationsEnabled {
            requestNotificationPermissions()
        }
        
        // Only insert if creating new goal
        if !isEditing {
            modelContext.insert(goal)
        }
        
        // Handle notification scheduling
        Task {
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
        }
        
        // Reset the plan generation timestamp to trigger a new plan
        lastPlanGeneratedTimestamp = 0
        print("🔄 Reset plan generation timestamp - new plan will be generated")
        
        // Reload widgets to show the new goal
        #if os(iOS)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Reloaded all widget timelines")
        #endif
        
        dismiss()
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Infer an appropriate icon from a goal title
    func inferIcon(from title: String) -> String? {
        guard !title.isEmpty else { return nil }
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { return nil }
        
        // Icon mapping dictionary - maps keywords to SF Symbol names
        let iconMapping: [String: String] = [
            // Fitness
            "run": "figure.run",
            "running": "figure.run",
            "jog": "figure.run",
            "walk": "figure.walk",
            "walking": "figure.walk",
            "yoga": "figure.yoga",
            "stretch": "figure.yoga",
            "gym": "dumbbell.fill",
            "workout": "figure.strengthtraining.traditional",
            "exercise": "figure.strengthtraining.traditional",
            "strength": "dumbbell.fill",
            "cardio": "heart.circle.fill",
            "cycle": "bicycle",
            "bike": "bicycle",
            "swim": "figure.pool.swim",
            "swimming": "figure.pool.swim",
            "dance": "figure.dance",
            "basketball": "figure.basketball",
            "soccer": "figure.soccer",
            "tennis": "figure.tennis",
            "climb": "figure.climbing",
            "hike": "figure.hiking",
            "hiking": "figure.hiking",
            
            // Wellness
            "meditate": "figure.mind.and.body",
            "meditation": "figure.mind.and.body",
            "sleep": "bed.double.fill",
            "rest": "zzz",
            "water": "waterbottle.fill",
            "hydrate": "drop.fill",
            "breathe": "wind",
            "breathing": "wind",
            "health": "heart.fill",
            "mindful": "sparkles",
            "wellness": "heart.circle.fill",
            
            // Learning
            "read": "book.fill",
            "reading": "book.fill",
            "book": "book.fill",
            "study": "book.closed.fill",
            "learn": "graduationcap.fill",
            "learning": "lightbulb.fill",
            "write": "pencil",
            "writing": "pencil",
            "journal": "note.text",
            "note": "note.text",
            "practice": "star.fill",
            "course": "graduationcap.fill",
            "education": "graduationcap.fill",
            
            // Creative
            "paint": "paintbrush.fill",
            "painting": "paintbrush.fill",
            "draw": "pencil.and.ruler.fill",
            "drawing": "pencil.and.ruler.fill",
            "art": "paintpalette.fill",
            "photo": "camera.fill",
            "photography": "camera.fill",
            "music": "music.note",
            "guitar": "guitars.fill",
            "piano": "pianokeys.inverse",
            "sing": "mic.fill",
            "singing": "mic.fill",
            "creative": "paintbrush.fill",
            "design": "paintbrush.pointed.fill",
            
            // Productivity
            "work": "checkmark.circle.fill",
            "task": "checkmark.square.fill",
            "focus": "target",
            "plan": "calendar",
            "organize": "folder.fill",
            "email": "envelope.fill",
            "meeting": "person.2.fill",
            "project": "doc.fill",
            "code": "chevron.left.forwardslash.chevron.right",
            "coding": "chevron.left.forwardslash.chevron.right",
            "program": "chevron.left.forwardslash.chevron.right",
            
            // Home
            "cook": "fork.knife",
            "cooking": "fork.knife",
            "clean": "sparkles",
            "cleaning": "trash.fill",
            "garden": "leaf.fill",
            "gardening": "leaf.fill",
            "laundry": "washer.fill",
            "dishes": "cup.and.saucer.fill",
            
            // Social
            "call": "phone.fill",
            "chat": "message.fill",
            "message": "bubble.fill",
            "friend": "person.2.fill",
            "family": "person.3.fill",
            "social": "person.2.fill",
            "party": "party.popper.fill",
            "celebrate": "balloon.fill",
            
            // Nature
            "nature": "leaf.fill",
            "outdoor": "sun.max.fill",
            "outdoors": "sun.max.fill",
            "tree": "tree.fill",
            "flower": "flower.fill",
            "plant": "leaf.fill",
            "pet": "pawprint.fill",
            "dog": "dog.fill",
            "cat": "cat.fill"
        ]
        
        // Try to find a direct match first
        if let icon = iconMapping[normalizedTitle] {
            return icon
        }
        
        // Try to find a partial match (keyword contained in title)
        for (keyword, icon) in iconMapping {
            if normalizedTitle.contains(keyword) {
                return icon
            }
        }
        
        return nil
    }
    
    /// Match a theme name to an actual Theme from the themes array
    func matchTheme(named themeName: String) -> Theme {
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
                return match.toTheme()
            }
        }
        
        // Try exact match first
        if let exactMatch = themePresets.first(where: { $0.title.lowercased() == normalizedThemeName }) {
            return exactMatch.toTheme()
        }
        
        // Try partial match
        if let partialMatch = themePresets.first(where: { $0.title.lowercased().contains(normalizedThemeName) }) {
            return partialMatch.toTheme()
        }
        
        // Try reverse match (theme name contains the search term)
        if let reverseMatch = themePresets.first(where: { normalizedThemeName.contains($0.title.lowercased()) }) {
            return reverseMatch.toTheme()
        }
        
        // Category-based matching for suggestion categories
        let categoryKeywords: [String: String] = [
            "fitness": "exercise",
            "wellness": "wellness",
            "learning": "learning",
            "creative": "creative",
            "productivity": "productivity",
            "lifestyle": "home",
            "social": "social",
            "personal growth": "growth"
        ]
        
        for (category, themeId) in categoryKeywords {
            if normalizedThemeName.contains(category) {
                if let match = themePresets.first(where: { $0.id == themeId }) {
                    return match.toTheme()
                }
            }
        }
        
        // Keyword-based matching for common activities
        let themeKeywords: [String: String] = [
            // Fitness
            "run": "running",
            "jog": "running",
            "cardio": "cardio",
            "gym": "strength",
            "workout": "exercise",
            "exercise": "exercise",
            "strength": "strength",
            "yoga": "yoga",
            "sport": "sports",
            
            // Wellness
            "meditate": "meditation",
            "meditation": "meditation",
            "mindful": "mindfulness",
            "wellness": "wellness",
            "relax": "relaxation",
            "breathe": "breathing",
            "breath": "breathing",
            
            // Learning
            "read": "reading",
            "book": "reading",
            "write": "writing",
            "journal": "journal",
            "learn": "learning",
            "study": "study",
            "practice": "practice",
            "art": "art",
            "paint": "art",
            "draw": "art",
            "music": "music",
            "instrument": "music",
            "creative": "creative",
            "create": "creative",
            
            // Productivity
            "work": "work",
            "focus": "focus",
            "productive": "productivity",
            "productivity": "productivity",
            "plan": "planning",
            
            // Lifestyle
            "cook": "cooking",
            "clean": "cleaning",
            "garden": "gardening",
            "organize": "organizing",
            "home": "home",
            
            // Social
            "social": "social",
            "family": "family",
            "friend": "friends",
            "community": "community",
            
            // Personal Growth
            "grow": "growth",
            "growth": "growth",
            "habit": "habits",
            "goal": "goals",
            "reflect": "reflection",
            
            // Misc
            "adventure": "adventure",
            "nature": "nature",
            "travel": "travel",
            "hobby": "hobby"
        ]
        
        for (keyword, themeId) in themeKeywords {
            if normalizedThemeName.contains(keyword) {
                if let match = themePresets.first(where: { $0.id == themeId })?.toTheme() {
                    return match
                }
            }
        }
        
        // Default fallback - use "general" theme
        return themePresets.first(where: { $0.id == "general" })?.toTheme() ?? themePresets[0].toTheme()
    }
    
    /// Find a theme that isn't currently used by any active goal
    func findUnusedTheme() -> Theme {
        // Get all theme IDs currently in use by active goals
        let usedThemeIDs = Set(allGoals.filter { $0.status == .active }.map { $0.primaryTag.themeID })
        
        // Find first unused theme
        if let unusedPreset = themePresets.first(where: { !usedThemeIDs.contains($0.id) }) {
            return unusedPreset.toTheme()
        }
        
        // If all themes are used, return a random one
        return (themePresets.randomElement() ?? themePresets[0]).toTheme()
    }
    
    func generateChecklist(for input: String) {
        errorMessage = nil
//        result = []

        Task {
            do {
                // Replace this part with proper FoundationModels API usage as needed
                // This is a placeholder showing where you would use your LLM
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
    
    private func tagIcon(for tag: GoalTag) -> String {
        if let loc = tag.locationTypesTyped, loc.contains(.gym) { return "dumbbell.fill" }
        if let loc = tag.locationTypesTyped, loc.contains(.outdoor) { return "tree.fill" }
        if let times = tag.timeOfDayPreferencesTyped, times.contains(.morning) { return "sunrise.fill" }
        if tag.requiresDaylight { return "sun.max.fill" }
        if let weather = tag.weatherConditionsTyped, weather.contains(.rainy) { return "cloud.rain.fill" }
        return "tag.fill"
    }
}
// MARK: - Category Suggestions View

struct CategorySuggestionsView: View {
    let category: GoalCategory
    @Binding var selectedTemplate: GoalTemplateSuggestion?
    @Binding var userInput: String
    
    // Helper to get category theme colors
    private var categoryThemeColor: Color {
        let themeKeywords: [String: String] = [
            "fitness": "exercise",
            "wellness": "wellness",
            "learning": "learning",
            "creative": "creative",
            "productivity": "productivity",
            "lifestyle": "home",
            "social": "social",
            "personal growth": "growth"
        ]
        
        let normalizedName = category.name.lowercased()
        
        // Try to find matching theme
        if let themeId = themeKeywords[normalizedName],
           let theme = themePresets.first(where: { $0.id == themeId })?.toTheme() {
            return theme.dark
        }
        
        // Fallback to first theme with matching title
        if let theme = themePresets.first(where: { $0.title.lowercased() == normalizedName })?.toTheme() {
            return theme.dark
        }
        
        // Use category color as fallback
        return category.colorValue
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestions List
            List {
                ForEach(category.suggestions) { suggestion in
                    SuggestionRow(
                        suggestion: suggestion,
                        isSelected: selectedTemplate?.id == suggestion.id,
                        categoryColor: categoryThemeColor
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTemplate = suggestion
                            userInput = suggestion.title // Prefill textfield
                        }
                        
                        // Haptic feedback
                        #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        #endif
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let suggestion: GoalTemplateSuggestion
    let isSelected: Bool
    let categoryColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: suggestion.icon)
                .font(.system(size: 32))
                .foregroundStyle(isSelected ? .white : categoryColor)
                .frame(width: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(suggestion.subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Duration badge
            Text("\(suggestion.duration) min")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? categoryColor : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? .white : categoryColor)
                )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? categoryColor : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? categoryColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

// MARK: - Category Tab
struct CategoryTab: View {
    let category: GoalCategory
    let isSelected: Bool
    
    // Helper to match category theme colors
    private var categoryThemeColors: (light: Color, dark: Color) {
        // Find matching theme from themes array
        let themeKeywords: [String: String] = [
            "fitness": "exercise",
            "wellness": "wellness",
            "learning": "learning",
            "creative": "creative",
            "productivity": "productivity",
            "lifestyle": "home",
            "social": "social",
            "personal growth": "growth"
        ]
        
        let normalizedName = category.name.lowercased()
        var matchedTheme: Theme?
        
        // Try to find matching theme
        if let themeId = themeKeywords[normalizedName] {
            matchedTheme = themePresets.first(where: { $0.id == themeId })?.toTheme()
        }
        
        // Fallback to first theme with matching title
        if matchedTheme == nil {
            matchedTheme = themePresets.first(where: { $0.title.lowercased() == normalizedName })?.toTheme()
        }
        
        // Use matched theme colors or fallback to category color
        if let theme = matchedTheme {
            return (theme.light, theme.dark)
        } else {
            return (category.colorValue.opacity(0.2), category.colorValue)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? categoryThemeColors.dark.contrastingTextColor : categoryThemeColors.dark)
            
            Text(category.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? categoryThemeColors.dark.contrastingTextColor : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isSelected ? categoryThemeColors.dark : Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .strokeBorder(categoryThemeColors.dark, lineWidth: isSelected ? 0 : 1.5)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

// MARK: - Color Extension for Contrast

extension Color {
    /// Returns either black or white text color based on the background luminance
    var contrastingTextColor: Color {
        // Convert to UIColor/NSColor to access RGB components
        #if os(iOS)
        let uiColor = UIColor(self)
        #elseif os(macOS)
        let uiColor = NSColor(self)
        #endif
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        #if os(iOS)
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif os(macOS)
        if let rgbColor = uiColor.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }
        #endif
        
        // Calculate relative luminance using the formula:
        // L = 0.2126 * R + 0.7152 * G + 0.0722 * B
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        
        // Use black text for light backgrounds, white text for dark backgrounds
        return luminance > 0.6 ? .black : .white
    }
}

// MARK: - Theme Color Button

struct ThemeColorButton: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Color circle with gradient
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [theme.light, theme.neon, theme.dark],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? theme.dark : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: theme.dark.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(theme.dark)
                                    .frame(width: 26, height: 26)
                            )
                    }
                }
                
                // Theme name
                Text(theme.title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? theme.dark : .secondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Time Slot Button
// MARK: - Quick Preset Button
struct QuickPresetButton: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isDestructive ? .red : .blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isDestructive ? .red : .primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 100, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggested Theme Card

struct SuggestedThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Color circle with gradient
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [theme.light, theme.neon, theme.dark],
                                center: .center,
                                startRadius: 0,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .shadow(color: theme.dark.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(theme.dark)
                                    .frame(width: 32, height: 32)
                            )
                    }
                }
                
                // Theme name
                Text(theme.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundStyle(isSelected ? theme.dark : .primary)
                    .lineLimit(1)
            }
            .frame(width: 100)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? theme.light.opacity(0.2) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? theme.dark : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Theme Tag Button
struct ThemeTagButton: View {
    @Environment(\.colorScheme) var colorScheme
    let goalTheme: GoalTag
    let isSelected: Bool
    let action: () -> Void
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        let themeColor = goalTheme.themePreset.color(for: colorScheme)
        let backgroundColor = colorScheme == .dark ? goalTheme.themePreset.dark : goalTheme.themePreset.light
        Button(action: action) {
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goalTheme.themePreset.light, goalTheme.themePreset.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
                    )
                
                Text(goalTheme.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                // Remove button
                if let onRemove = onRemove {
                    Button(action: {
                        onRemove()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? backgroundColor.opacity(0.3) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? themeColor : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Tag Selection Sheet

struct TagSelectionSheet: View {
    let allTags: [GoalTag]
    @Binding var selectedTags: [GoalTag]
    @Binding var selectedGoalTheme: GoalTag?
    let modelContext: ModelContext
    @Binding var editingTag: GoalTag?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if allTags.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "tag.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No Tags Available")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Load predefined tags or create your own")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                let predefined = GoalTag.predefinedSmartTags(themes: themePresets.map { $0.toTheme() })
                                for tag in predefined {
                                    if !allTags.contains(where: { $0.title == tag.title }) {
                                        modelContext.insert(tag)
                                    }
                                }
                            } label: {
                                Label("Load Predefined Smart Tags", systemImage: "square.and.arrow.down")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        // Tags grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Tags")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            TagFlowLayout(spacing: 8) {
                                ForEach(allTags, id: \.id) { tag in
                                    TagButton(
                                        tag: tag,
                                        isSelected: selectedTags.contains(where: { $0.id == tag.id }),
                                        onSelect: {
                                            toggleTagSelection(tag)
                                        },
                                        onEdit: {
                                            editingTag = tag
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button {
                                let predefined = GoalTag.predefinedSmartTags(themes: themePresets.map { $0.toTheme() })
                                for tag in predefined {
                                    if !allTags.contains(where: { $0.title == tag.title }) {
                                        modelContext.insert(tag)
                                    }
                                }
                            } label: {
                                Label("Load Predefined Smart Tags", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            // Future: Add custom tag creation button
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Add Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleTagSelection(_ tag: GoalTag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            // Deselect
            withAnimation(.spring(response: 0.3)) {
                selectedTags.remove(at: index)
                
                // If this was the selected theme, update it
                if selectedGoalTheme?.id == tag.id {
                    selectedGoalTheme = selectedTags.first
                }
            }
        } else {
            // Select
            withAnimation(.spring(response: 0.3)) {
                selectedTags.append(tag)
                
                // If no theme is selected, make this the selected theme
                if selectedGoalTheme == nil {
                    selectedGoalTheme = tag
                }
            }
        }
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Tag Button

struct TagButton: View { // TODO: Combine with theme
    let tag: GoalTag
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tag.themePreset.light, tag.themePreset.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? tag.themePreset.dark : Color.clear, lineWidth: 2)
                    )
                
                Text(tag.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .fontWeight(isSelected ? .semibold : .regular)
             
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? tag.themePreset.light.opacity(0.3) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? tag.themePreset.dark : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? tag.themePreset.dark : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    // Move to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
// MARK: - Color Picker Sheet

struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedColorPreset: ThemePreset?
    let onSelect: (ThemePreset) -> Void
    
    // Rainbow-sorted color order
    private var sortedPresets: [ThemePreset] {
        let order = [
            // Red family
            "red", "cherry", "crimson", "ruby", "coral", "salmon", "hot_pink", "rose",
            // Orange family
            "orange", "burnt_orange", "tangerine", "peach", "amber", "apricot",
            // Yellow family
            "yellow", "sunshine", "lemon", "gold", "mustard", "beige", "cream",
            // Green family
            "green", "emerald", "mint", "seafoam", "lime", "olive", "sage", "forest",
            // Blue family
            "blue", "navy", "sky_blue", "azure", "cyan", "teal", "turquoise", "mint_blue", "steel", "grey_blue", "cobalt",
            // Purple/Violet family
            "purple", "indigo", "violet", "lilac", "grape", "plum", "mauve", "lavender", "orchid", "magenta",
            // Pink family
            "pink0", "bubblegum", "fuchsia",
            // Brown/Neutral family
            "chocolate", "coffee", "taupe",
            // Gray family
            "silver0", "charcoal", "slate"
        ]
        
        return order.compactMap { id in
            themePresets.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(sortedPresets, id: \.id) { preset in
                        ColorPresetButton(
                            preset: preset,
                            isSelected: selectedColorPreset?.id == preset.id,
                            colorScheme: colorScheme
                        ) {
                            onSelect(preset)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ColorPresetButton: View {
    let preset: ThemePreset
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Color preview with gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [preset.neon, preset.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.primary : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .shadow(color: preset.neon.opacity(0.3), radius: 6)
                
                // Color name
                Text(preset.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Icon Picker Sheet
struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String?
    let themeColor: Color
    let onSelect: (String) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedCategory: IconCategory = .fitness
    
    var filteredIcons: [String] {
        let categoryIcons = selectedCategory.icons
        if searchText.isEmpty {
            return categoryIcons
        }
        return categoryIcons.filter { icon in
            icon.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(IconCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                themeColor: themeColor
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Icon grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(filteredIcons, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon,
                                themeColor: themeColor
                            ) {
                                onSelect(icon)
                            }
                        }
                    }
                    .padding()
                }
                .searchable(text: $searchText, prompt: "Search icons")
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryButton: View {
    let category: IconCategory
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? themeColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? themeColor : .primary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? themeColor.opacity(0.15) : Color(.systemGray6))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Icon Categories

enum IconCategory: String, CaseIterable {
    case fitness = "Fitness"
    case wellness = "Wellness"
    case learning = "Learning"
    case creative = "Creative"
    case productivity = "Productivity"
    case home = "Home"
    case social = "Social"
    case nature = "Nature"
    
    var name: String { rawValue }
    
    var icon: String {
        switch self {
        case .fitness: return "figure.run"
        case .wellness: return "heart.fill"
        case .learning: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .productivity: return "checkmark.circle.fill"
        case .home: return "house.fill"
        case .social: return "person.2.fill"
        case .nature: return "leaf.fill"
        }
    }
    
    var icons: [String] {
        switch self {
        case .fitness:
            return [
                "figure.run", "figure.walk", "figure.yoga", "figure.cooldown",
                "figure.strengthtraining.traditional", "dumbbell.fill", "figure.dance",
                "figure.jumprope", "figure.boxing", "figure.kickboxing",
                "figure.basketball", "figure.soccer", "figure.tennis",
                "figure.baseball", "figure.volleyball", "figure.badminton",
                "figure.skiing.downhill", "figure.snowboarding", "figure.surfing",
                "bicycle", "figure.outdoor.cycle", "figure.indoor.cycle",
                "figure.pool.swim", "figure.water.fitness", "figure.rowing",
                "figure.climbing", "figure.hiking", "shoeprints.fill",
                "heart.circle.fill", "bolt.heart.fill", "stopwatch.fill"
            ]
        case .wellness:
            return [
                "heart.fill", "heart.circle.fill", "sparkles",
                "leaf.fill", "drop.fill", "wind",
                "sun.max.fill", "moon.stars.fill", "cloud.sun.fill",
                "bed.double.fill", "zzz", "waterbottle.fill",
                "brain.fill", "lungs.fill", "figure.mind.and.body",
                "pills.fill", "cross.vial.fill", "stethoscope",
                "medical.thermometer.fill", "bandage.fill", "cross.case.fill",
                "allergens", "syringe.fill", "ivfluid.bag.fill"
            ]
        case .learning:
            return [
                "book.fill", "book.closed.fill", "books.vertical.fill",
                "magazine.fill", "newspaper.fill", "note.text",
                "doc.text.fill", "doc.richtext.fill", "note",
                "pencil", "pencil.circle.fill", "highlighter",
                "graduationcap.fill", "studentdesk", "backpack.fill",
                "brain.head.profile", "lightbulb.fill", "star.fill",
                "chart.bar.fill", "text.book.closed.fill", "character.book.closed.fill",
                "abc", "textformat.abc", "textformat.123"
            ]
        case .creative:
            return [
                "paintbrush.fill", "paintpalette.fill", "photo.fill",
                "camera.fill", "video.fill", "film.fill",
                "music.note", "music.note.list", "guitars.fill",
                "pianokeys.inverse", "mic.fill", "waveform",
                "scissors", "pencil.and.ruler.fill", "square.and.pencil",
                "paintbrush.pointed.fill", "eyedropper.halffull", "swatchpalette.fill",
                "lasso.badge.sparkles", "photo.badge.plus.fill", "rectangle.portrait.on.rectangle.portrait.fill"
            ]
        case .productivity:
            return [
                "checkmark.circle.fill", "checkmark.square.fill", "list.bullet",
                "list.bullet.clipboard.fill", "calendar", "clock.fill",
                "timer", "stopwatch.fill", "bell.fill",
                "flag.fill", "star.fill", "paperclip",
                "folder.fill", "doc.fill", "tray.fill",
                "archivebox.fill", "shippingbox.fill", "envelope.fill",
                "paperplane.fill", "link", "square.grid.2x2.fill",
                "target", "scope", "chart.line.uptrend.xyaxis"
            ]
        case .home:
            return [
                "house.fill", "door.left.hand.closed", "lightbulb.fill",
                "lamp.desk.fill", "lamp.floor.fill", "lamp.ceiling.fill",
                "fan.fill", "poweroutlet.type.a.fill", "heater.vertical.fill",
                "basket.fill", "cart.fill", "bag.fill",
                "fork.knife", "cup.and.saucer.fill", "mug.fill",
                "refrigerator.fill", "stove.fill", "oven.fill",
                "washer.fill", "dryer.fill", "dishwasher.fill",
                "trash.fill", "toilet.fill", "shower.fill",
                "bathtub.fill", "bed.double.fill", "sofa.fill",
                "chair.fill", "table.furniture.fill", "cabinet.fill"
            ]
        case .social:
            return [
                "person.fill", "person.2.fill", "person.3.fill",
                "person.crop.circle.fill", "person.crop.square.fill", "person.and.background.dotted",
                "bubble.fill", "bubble.left.and.bubble.right.fill", "message.fill",
                "phone.fill", "video.fill", "envelope.fill",
                "heart.fill", "hand.thumbsup.fill", "star.fill",
                "gift.fill", "party.popper.fill", "balloon.fill",
                "birthday.cake.fill", "cup.and.saucer.fill", "wineglass.fill",
                "camera.fill", "camera.viewfinder", "photo.on.rectangle.fill"
            ]
        case .nature:
            return [
                "leaf.fill", "tree.fill", "flower.fill",
                "sun.max.fill", "cloud.sun.fill", "cloud.rain.fill",
                "snowflake", "wind", "tornado",
                "flame.fill", "drop.fill", "globe.americas.fill",
                "mountain.2.fill", "beach.umbrella.fill", "water.waves",
                "pawprint.fill", "hare.fill", "bird.fill",
                "fish.fill", "ladybug.fill", "ant.fill",
                "tortoise.fill", "lizard.fill", "cat.fill",
                "dog.fill", "carrot.fill", "leaf.arrow.triangle.circlepath"
            ]
        }
    }
}

// MARK: - Reminders Tab

struct RemindersTab: View {
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.body.weight(.medium))
            Text("Reminders")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(isSelected ? Color.teal : Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.teal : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

struct RemindersTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    
    @Binding var userInput: String
    let onReminderSelected: (EKReminder) -> Void
    
    @State private var remindersManager = RemindersManager()
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Group {
            if !remindersManager.isAuthorized {
                permissionView
            } else if isLoading {
                ProgressView("Loading reminders...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reminders.isEmpty {
                emptyStateView
            } else {
                remindersList
            }
        }
        .task {
            if remindersManager.isAuthorized {
                await loadReminders()
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Cannot access Reminders")
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Access Reminders")
                .font(.headline)
            
            Text("Import your reminders as time-tracked goals")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Allow Access") {
                Task {
                    await requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Reminders")
                .font(.headline)
            
            Text("You don't have any incomplete reminders")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var remindersList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                    Button {
                        importReminder(reminder)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle")
                                .font(.body)
                                .foregroundStyle(.teal)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title ?? "Untitled")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                if let dueDate = reminder.dueDateComponents?.date {
                                    Text("Due: \(dueDate, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let notes = reminder.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private func requestPermission() async {
        do {
            let granted = try await remindersManager.requestAccess()
            if granted {
                await loadReminders()
            } else {
                errorMessage = "Reminders access was denied"
                showingPermissionAlert = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showingPermissionAlert = true
        }
    }
    
    private func loadReminders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            reminders = try await remindersManager.fetchIncompleteReminders()
            reminders.sort { reminder1, reminder2 in
                let date1 = reminder1.dueDateComponents?.date ?? Date.distantFuture
                let date2 = reminder2.dueDateComponents?.date ?? Date.distantFuture
                return date1 < date2
            }
        } catch {
            errorMessage = error.localizedDescription
            showingPermissionAlert = true
        }
    }
    
    private func importReminder(_ reminder: EKReminder) {
        // Create the goal
        let _ = remindersManager.createGoal(from: reminder, context: context, goalStore: goalStore)
        
        // Fill in the text field with reminder title
        onReminderSelected(reminder)
        
        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

