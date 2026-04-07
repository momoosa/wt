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

// MARK: - Checklist Item Data
struct ChecklistItemData: Identifiable, Equatable {
    let id: UUID
    var title: String
    var notes: String

    init(id: UUID = UUID(), title: String = "", notes: String = "") {
        self.id = id
        self.title = title
        self.notes = notes
    }
}

struct GoalEditorView: View {
    enum Field: Hashable {
        case goalName
        case duration
        case dailyMinimum
        case scheduleDay(Int) // weekday 1-7
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var buttonNamespace
    @Query private var allGoals: [Goal]
    @Query private var allTags: [GoalTag]
    @FocusState private var focusedField: Field?
    @Bindable private var viewModel: GoalEditorViewModel
    
    // Initializer to properly initialize ViewModel
    init(viewModel: GoalEditorViewModel) {
        self.viewModel = viewModel
    }
    
    
    @State private var scrollProxy: ScrollViewProxy?
    // Weekday helper (1 = Sunday, 2 = Monday ... 7 = Saturday)
    private let weekdays = WeekdayConstants.weekdays
    
    // Track if user has made any changes
    private var hasUnsavedChanges: Bool {
        // Check if user has entered text
        if !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Check if user selected a template
        if viewModel.selectedTemplate != nil {
            return true
        }
        
        // Check if in duration stage (means they pressed Next)
        if viewModel.currentStage == .duration {
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

    
    // Computed property for the active theme color
    private var activeThemeColor: Color {
        if let selectedPreset = viewModel.selectedColorPreset {
            return selectedPreset.color(for: colorScheme)
        } else if let selectedTheme = viewModel.selectedGoalTheme {
            return selectedTheme.themePreset.color(for: colorScheme)
        } else if let template = viewModel.selectedTemplate,
                  let category = viewModel.suggestionsData.categories.first(where: { $0.suggestions.contains(where: { $0.id == template.id }) }) {
            let matchedTheme = matchTheme(named: category.color)
            return matchedTheme.color(for: colorScheme)
        }
        return .accentColor
    }
    
    /// Calculate appropriate text color for buttons based on background luminance
    private var buttonTextColor: Color {
        let luminance = activeThemeColor.luminance ?? 0.5
        return luminance > 0.5 ? .black : .white
    }

    /// Unit label for the current goal type
    private var goalTypeUnit: String {
        viewModel.selectedGoalType.unitLabel
    }
    
    /// Suggested target values based on goal type
    private var targetSuggestions: [Int] {
        switch viewModel.selectedGoalType {
        case .time:
            return []
        case .count:
            return [5000, 7500, 10000, 12500]
        case .calories:
            return [200, 300, 500, 750]
        }
    }

    /// Schedule section with goal type picker
    @ViewBuilder
    private var scheduleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Goal type picker section (extracted component)
                GoalTypeSection(
                    selectedType: $viewModel.selectedGoalType,
                    primaryMetricTarget: $viewModel.primaryMetricTarget,
                    calculatedWeeklyTarget: calculatedWeeklyTarget,
                    activeThemeColor: activeThemeColor,
                    goalTypeUnit: goalTypeUnit,
                    targetSuggestions: targetSuggestions,
                    onTypeChange: handleGoalTypeChange
                )

                Divider()

                // Schedule configuration
                daysList
            }
            .padding(.vertical, 4)
        } header: {
            Text(viewModel.selectedGoalType == .time ? "Weekly Goal" : "Goal & Schedule")
        } footer: {
            if viewModel.selectedGoalType != .time {
                Text("Select which days and times you want to be reminded about this goal. Your daily target of \(Int(viewModel.primaryMetricTarget)) \(goalTypeUnit) applies to all selected days.")
            }
        }
    }

    private var weeklyTargetHeader: some View {
        Group {
            HStack {
                Text("Weekly Target")
                Spacer()
                Text("\(calculatedWeeklyTarget) min")
                    .foregroundStyle(activeThemeColor)
            }
            .font(.subheadline)
            .fontWeight(.semibold)

            Divider()
        }
    }

    private var daysList: some View {
        VStack(spacing: 8) {
            ForEach(weekdays, id: \.0) { weekday, name in
                ExpandableDayRow(
                    weekday: weekday,
                    name: name,
                    isActive: isDayActive(weekday),
                    minutes: viewModel.dailyTargets[weekday] ?? 30,
                    selectedTimes: viewModel.dayTimePreferences[weekday] ?? [],
                    themeColor: activeThemeColor,
                    isExpanded: expandedDay == weekday,
                    showMinutes: viewModel.selectedGoalType == .time,
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

    var body: some View {
        NavigationStack {
                    
                    List {
                            // Custom input section
                            Section {
                                TextField("What do you want to do?", text: $viewModel.userInput)
                                    .focused($focusedField, equals: .goalName)
                                    .onChange(of: viewModel.userInput) { _, newValue in
                                        // Clear selection if user is typing freeform
                                        if !newValue.isEmpty {
                                            viewModel.selectedTemplate = nil
                                        }

                                        // Try to find a match among suggestions by title or aliases and select it
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmed.isEmpty else { return }

                                        if let (categoryIndex, matchedSuggestion) = viewModel.suggestionsData.categories.enumerated().compactMap({ (idx, category) -> (Int, GoalTemplateSuggestion)? in
                                            if let suggestion = category.suggestions.first(where: { matchesSuggestion($0, with: trimmed) }) {
                                                return (idx, suggestion)
                                            }
                                            return nil
                                        }).first {
                                            // Select the template and category
                                            viewModel.selectedTemplate = matchedSuggestion
                                            viewModel.selectedCategoryIndex = categoryIndex

                                            // Scroll category tabs to selected category if available
                                            if let proxy = scrollProxy {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    proxy.scrollTo(categoryIndex, anchor: .center)
                                                }
                                            }
                                        }
                                        
                                        // Infer icon from user input if no icon is selected yet
                                        if viewModel.selectedIcon == nil, !trimmed.isEmpty, trimmed.count >= 3 {
                                            Task { @MainActor in
                                                if viewModel.selectedIcon == nil {
                                                    viewModel.selectedIcon = inferIcon(from: trimmed)
                                                }
                                            }
                                        }
                                    }
                                
                            }
                        if viewModel.currentStage == .name {

                            // Scrollable Category Tabs
                            Section {
                                
                                
                                VStack(spacing: 0) {
                                    ScrollViewReader { proxy in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                HStack(spacing: 12) {
                                                    // Reminders tab
                                                    RemindersTab(isSelected: viewModel.selectedCategoryIndex == -1)
                                                        .id(-1)
                                                        .onTapGesture {
                                                            withAnimation(AnimationPresets.quickSpring) {
                                                                viewModel.selectedCategoryIndex = -1
                                                            }
                                                            
                                                            // Haptic feedback
                                                            HapticFeedbackManager.trigger(.light)
                                                        }
                                                    
                                                    ForEach(Array(viewModel.suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                                                        CategoryTab(
                                                            category: category,
                                                            isSelected: viewModel.selectedCategoryIndex == index
                                                        )
                                                        .id(index) // Add ID for scrolling
                                                        .onTapGesture {
                                                            withAnimation(AnimationPresets.quickSpring) {
                                                                viewModel.selectedCategoryIndex = index
                                                            }
                                                            
                                                            // Haptic feedback
                                                            HapticFeedbackManager.trigger(.light)
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
                                        .onChange(of: viewModel.selectedCategoryIndex) { _, newIndex in
                                            // Auto-scroll to selected tab
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(newIndex, anchor: .center)
                                            }
                                        }
                                    }
                                    // Category Tabs
                                    TabView(selection: $viewModel.selectedCategoryIndex) {
                                        // Reminders tab content
                                        RemindersTabView(
                                            userInput: $viewModel.userInput,
                                            onReminderSelected: { reminder in
                                                // Fill in the goal name from reminder
                                                viewModel.userInput = reminder.title ?? ""
                                                viewModel.selectedTemplate = nil
                                            }
                                        )
                                        .tag(-1)
                                        
                                        ForEach(Array(viewModel.suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                                            CategorySuggestionsView(
                                                category: category,
                                                selectedTemplate: $viewModel.selectedTemplate,
                                                userInput: $viewModel.userInput
                                            )
                                            .tag(index)
                                        }
                                    }
                                    .tabViewStyle(.page(indexDisplayMode: .never))
                                    .frame(height: LayoutConstants.Heights.suggestionPanel)
                                }
                                
                            } header: {
                                Text("Suggestions")
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        
                        if viewModel.currentStage == .duration {
                                         
                            Section(header: Text("Theme")) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        // Color picker button
                                        Button(action: {
                                            viewModel.showingColorPicker = true
                                        }) {
                                            HStack(spacing: 8) {
                                                // Color preview circle
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                viewModel.selectedColorPreset?.neon ?? activeThemeColor,
                                                                viewModel.selectedColorPreset?.dark ?? activeThemeColor
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 24, height: 24)
                                                
                                                Text(viewModel.selectedColorPreset?.title ?? "Color")
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
                                            viewModel.showingIconPicker = true
                                        }) {
                                            HStack(spacing: 8) {
                                                // Icon preview
                                                Image(systemName: viewModel.selectedIcon ?? "star.fill")
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
                                    // Tag cloud with flow layout - show only selected themes
                                    TagFlowLayout(spacing: 8) {
                                        ForEach(viewModel.selectedTags, id: \.title) { goalTheme in
                                            ThemeTagButton(
                                                goalTheme: goalTheme,
                                                isSelected: true,
                                                action: {
                                                    HapticFeedbackManager.trigger(.light)
                                                },
                                                onRemove: {
                                                    removeGoalTheme(goalTheme)
                                                }
                                            )
                                        }
                                        
                                        // Add theme button
                                        Button(action: {
                                            viewModel.showingAddThemeSheet = true
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
                                    
                                    if viewModel.selectedTags.isEmpty {
                                        Text("Tap 'Add Theme' to choose a color theme for your goal")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 4)
                                    }
                                }
                            }

                            scheduleSection



                            Section(header: Text("When Daily Goal Completes")) {
                                ForEach(Goal.CompletionBehavior.allCases) { behavior in
                                    Toggle(isOn: Binding(
                                        get: { viewModel.selectedCompletionBehaviors.contains(behavior) },
                                        set: { isOn in
                                            if isOn {
                                                viewModel.selectedCompletionBehaviors.insert(behavior)
                                            } else {
                                                viewModel.selectedCompletionBehaviors.remove(behavior)
                                            }
                                            HapticFeedbackManager.trigger(.light)
                                        }
                                    )) {
                                        HStack(spacing: 12) {
                                            Image(systemName: behavior.icon)
                                                .font(.body)
                                                .foregroundStyle(viewModel.selectedCompletionBehaviors.contains(behavior) ? activeThemeColor : .secondary)
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(behavior.displayName)
                                                    .font(.subheadline)
                                                Text(behavior.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .tint(activeThemeColor)
                                }
                            }
                            
                            HealthKitConfigurationView(
                                selectedMetric: $viewModel.selectedHealthKitMetric,
                                syncEnabled: $viewModel.healthKitSyncEnabled,
                                dailyTargetMinutes: Binding(
                                    get: {
                                        // Return the first active day's target as representative
                                        return viewModel.activeDays.sorted().first.flatMap { viewModel.dailyTargets[$0] }
                                    },
                                    set: { newValue in
                                        // Apply to all active days
                                        if let minutes = newValue {
                                            for weekday in viewModel.activeDays {
                                                viewModel.dailyTargets[weekday] = minutes
                                            }
                                        }
                                    }
                                )
                            )
                            
                            // Screen Time Configuration (only shown when editing an existing goal)
                            if let existingGoal = viewModel.existingGoal {
                                ScreenTimeGoalConfigurationView(goal: existingGoal)
                            }
                            
                            Section(header: Text("Notes & Resources")) {
                                    // Notes field
                                    VStack(alignment: .leading, spacing: 4) {
                                        TextField("Add any notes about this goal...", text: $viewModel.goalNotes, axis: .vertical)
                                            .lineLimit(3...6)
                                            
                                    
                                    // Link field
                                        HStack(spacing: 8) {
                                            Image(systemName: "link")
                                                .foregroundStyle(.secondary)
                                                .font(.subheadline)
                                            
                                            TextField("Add a link here...", text: $viewModel.goalLink)
                                                .keyboardType(.URL)
                                                .autocapitalization(.none)
                                        
                                        
                                        if !viewModel.goalLink.isEmpty, let url = URL(string: viewModel.goalLink), UIApplication.shared.canOpenURL(url) {
                                            Button(action: {
                                                UIApplication.shared.open(url)
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.up.right.square")
                                                    Text("Open Link")
                                                }
                                                .font(.caption)
                                                .foregroundStyle(activeThemeColor)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Checklist Section
                            ChecklistSection(viewModel: viewModel, activeThemeColor: activeThemeColor)
                            
                            // Weather-based visibility
                            WeatherConfigSection(viewModel: viewModel, activeThemeColor: activeThemeColor)
                        }
                        
                        Spacer()
                            .frame(height: LayoutConstants.Heights.filterBar)
                    }
                    .animation(.spring(), value: viewModel.result)
                    .animation(AnimationPresets.smoothSpring, value: viewModel.currentStage)
                    
            .overlay(alignment: .bottom) {
                // Bottom button (hide when keyboard is active or when editing existing goal on duration stage)
                if focusedField == nil && !(viewModel.existingGoal != nil && viewModel.currentStage == .duration) {
                    VStack(spacing: 0) {
                        Divider()
                        if viewModel.currentStage == .name {
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
                    .frame(height: LayoutConstants.Heights.filterBar)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(viewModel.currentStage == .name ? (viewModel.existingGoal == nil ? "New Goal" : "Edit Goal") : "Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .tint(activeThemeColor)
            .interactiveDismissDisabled(viewModel.currentStage != .name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if viewModel.currentStage == .duration && viewModel.existingGoal == nil {
                            // Only allow going back to name stage if creating new goal
                            withAnimation {
                                viewModel.currentStage = .name
                                // Reset theme selections when going back
                                viewModel.selectedTags.removeAll()
                                viewModel.selectedGoalTheme = nil
                                viewModel.selectedTemplate = nil
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        // Show X when editing, or when on name stage
                        // Show back arrow only when on duration stage of new goal
                        
                        Image(systemName: (viewModel.currentStage == .name || viewModel.existingGoal != nil) ? "xmark" : "chevron.left")
                    }

                }
                
                // Save/Close button on duration stage
                if viewModel.currentStage == .duration {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if viewModel.existingGoal != nil {
                                // Save when editing
                                handleButtonTap()
                            } else {
                                // Close when creating new
                                dismiss()
                            }
                        } label: {
                            Text(viewModel.existingGoal != nil ? "Save" : "Close")
                                .fontWeight(.semibold)
                        }
                        .disabled(viewModel.existingGoal != nil && !buttonEnabled)
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
                    if viewModel.currentStage == .name && focusedField == .goalName {
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
                    
                    // Apply to All Days button (when editing a specific day's duration and it differs from others)
                    if case .scheduleDay(let weekday) = focusedField, shouldShowApplyToAll(for: weekday) {
                        Button {
                            applyDurationToAllDays(from: weekday)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.caption)
                                Text("Apply to All")
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(activeThemeColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .id("applyToAll-\(weekday)")
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: focusedField)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.dailyTargets)
        }
        .sheet(isPresented: $viewModel.showingAddThemeSheet) {
            TagSelectionSheet(
                allTags: allTags,
                selectedTags: $viewModel.selectedTags,
                selectedGoalTheme: $viewModel.selectedGoalTheme,
                modelContext: modelContext,
                editingTag: $viewModel.editingTag
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewModel.editingTag) { tag in
            NavigationStack {
                GoalTagTriggersEditor(goalTag: tag)
            }
        }
        .sheet(isPresented: $viewModel.showingColorPicker) {
            ColorPickerSheet(
                selectedColorPreset: $viewModel.selectedColorPreset,
                onSelect: handleColorSelection
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showingIconPicker) {
            IconPickerSheet(
                selectedIcon: $viewModel.selectedIcon,
                themeColor: activeThemeColor,
                onSelect: { icon in
                    viewModel.selectedIcon = icon
                    viewModel.showingIconPicker = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Target Adjusted", isPresented: $viewModel.showingValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.validationMessage)
        }

        .task {
            // Load existing goal data if editing
            if let existingGoal = viewModel.existingGoal {
                loadGoalData(from: existingGoal)
            } else if viewModel.userInput.isEmpty {
                generateChecklist(for: "")
            }
        }
    }
    
    var buttonEnabled: Bool {
        switch viewModel.currentStage {
        case .name:
            return viewModel.selectedTemplate != nil || !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .duration:
            return true
        }
    }
    
    // MARK: - Keyboard Navigation
    
    private func focusNextField() {
        switch focusedField {
        case .goalName:
            if viewModel.currentStage == .duration {
                focusedField = .duration
            }
        case .duration:
            if viewModel.hasDailyMinimum {
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
            } else if viewModel.hasDailyMinimum {
                focusedField = .dailyMinimum
            } else {
                focusedField = .duration
            }
        case .none:
            if viewModel.currentStage == .duration {
                if let lastActiveDay = getPreviousActiveScheduleDay(before: nil) {
                    focusedField = .scheduleDay(lastActiveDay)
                } else if viewModel.hasDailyMinimum {
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
            return viewModel.currentStage == .duration
        case .duration:
            return viewModel.hasDailyMinimum || !viewModel.activeDays.isEmpty
        case .dailyMinimum:
            return !viewModel.activeDays.isEmpty
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
            return viewModel.currentStage == .duration
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
            return remainingDays.first(where: { viewModel.activeDays.contains($0) })
        } else {
            // Return first active day
            return orderedWeekdays.first(where: { viewModel.activeDays.contains($0) })
        }
    }
    
    /// Get the previous active schedule day before the given weekday (or last if nil)
    private func getPreviousActiveScheduleDay(before weekday: Int?) -> Int? {
        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun
        
        if let currentDay = weekday {
            // Find previous active day before current
            guard let currentIndex = orderedWeekdays.firstIndex(of: currentDay) else { return nil }
            let previousDays = orderedWeekdays[..<currentIndex]
            return previousDays.reversed().first(where: { viewModel.activeDays.contains($0) })
        } else {
            // Return last active day
            return orderedWeekdays.reversed().first(where: { viewModel.activeDays.contains($0) })
        }
    }
    
    // MARK: - Helper Functions

    /// Handle goal type changes
    private func handleGoalTypeChange(_ newType: Goal.GoalType) {
        switch newType {
        case .time:
            viewModel.selectedHealthKitMetric = nil
            viewModel.healthKitSyncEnabled = false
        case .count:
            viewModel.selectedHealthKitMetric = .stepCount
            viewModel.healthKitSyncEnabled = true
            viewModel.primaryMetricTarget = 10000
        case .calories:
            viewModel.selectedHealthKitMetric = .activeEnergyBurned
            viewModel.healthKitSyncEnabled = true
            viewModel.primaryMetricTarget = 500
        }
    }

    /// Validate and clamp primary metric target to reasonable ranges
    private func validatePrimaryMetricTarget() {
        guard viewModel.primaryMetricTarget > 0 else {
            // Set to default if zero or negative
            switch viewModel.selectedGoalType {
            case .time:
                viewModel.primaryMetricTarget = 0
            case .count:
                viewModel.primaryMetricTarget = 100 // Minimum 100 steps
                viewModel.validationMessage = "Target set to minimum: 100 steps"
                viewModel.showingValidationAlert = true
            case .calories:
                viewModel.primaryMetricTarget = 50 // Minimum 50 calories
                viewModel.validationMessage = "Target set to minimum: 50 calories"
                viewModel.showingValidationAlert = true
            }
            return
        }

        // Clamp to reasonable maximums
        switch viewModel.selectedGoalType {
        case .time:
            break // No validation needed
        case .count:
            if viewModel.primaryMetricTarget > 100000 {
                viewModel.primaryMetricTarget = 100000 // Max 100k steps
                viewModel.validationMessage = "Target adjusted to maximum: 100,000 steps"
                viewModel.showingValidationAlert = true
            } else if viewModel.primaryMetricTarget < 100 {
                viewModel.primaryMetricTarget = 100 // Min 100 steps
                viewModel.validationMessage = "Target adjusted to minimum: 100 steps"
                viewModel.showingValidationAlert = true
            }
        case .calories:
            if viewModel.primaryMetricTarget > 10000 {
                viewModel.primaryMetricTarget = 10000 // Max 10k calories
                viewModel.validationMessage = "Target adjusted to maximum: 10,000 calories"
                viewModel.showingValidationAlert = true
            } else if viewModel.primaryMetricTarget < 50 {
                viewModel.primaryMetricTarget = 50 // Min 50 calories
                viewModel.validationMessage = "Target adjusted to minimum: 50 calories"
                viewModel.showingValidationAlert = true
            }
        }
    }

    /// Load existing goal data for editing
    private func loadGoalData(from goal: Goal) {
        viewModel.userInput = goal.title
        viewModel.durationInMinutes = Int(goal.weeklyTarget / 60) // Convert weekly seconds to minutes (legacy)
        
        // Load daily minimum (this is now the primary daily target)
        if let dailyMin = goal.dailyMinimum {
            viewModel.dailyMinimumMinutes = Int(dailyMin / 60)
        } else {
            // Default to 10 minutes if not set
            viewModel.dailyMinimumMinutes = 10
        }
        
        // Infer active days from schedule - days with any time preferences are "active"
        viewModel.activeDays.removeAll()
        viewModel.dailyTargets.removeAll()
        
        for weekday in 1...7 {
            let times = goal.timesForWeekday(weekday)
            if !times.isEmpty {
                viewModel.activeDays.insert(weekday)
                // Check if there's a custom daily target for this day
                if let customTarget = goal.dailyTargets[String(weekday)] {
                    viewModel.dailyTargets[weekday] = Int(customTarget / 60) // Convert seconds to minutes
                } else {
                    // Fall back to dailyMinimum or default
                    viewModel.dailyTargets[weekday] = viewModel.dailyMinimumMinutes ?? 10
                }
            }
        }
        
        // If no active days found, default to weekdays with default targets
        if viewModel.activeDays.isEmpty {
            viewModel.activeDays = Set(2...6) // Monday-Friday
            for weekday in 2...6 {
                viewModel.dailyTargets[weekday] = viewModel.dailyMinimumMinutes ?? 10
            }
        }
        
        viewModel.scheduleNotificationsEnabled = goal.scheduleNotificationsEnabled
        viewModel.completionNotificationsEnabled = goal.completionNotificationsEnabled
        viewModel.selectedCompletionBehaviors = goal.completionBehaviors
        viewModel.selectedGoalType = goal.goalType
        viewModel.selectedHealthKitMetric = goal.healthKitMetric
        viewModel.healthKitSyncEnabled = goal.healthKitSyncEnabled

        // Load or set default primary metric target
        if goal.primaryMetricDailyTarget > 0 {
            viewModel.primaryMetricTarget = goal.primaryMetricDailyTarget
        } else {
            // Set defaults based on goal type for migrated goals
            switch goal.goalType {
            case .time:
                viewModel.primaryMetricTarget = 0
            case .count:
                viewModel.primaryMetricTarget = 10000 // Default: 10,000 steps
            case .calories:
                viewModel.primaryMetricTarget = 500 // Default: 500 calories
            }
        }

        viewModel.goalNotes = goal.notes ?? ""
        viewModel.goalLink = goal.link ?? ""
        
        // Load checklist items
        viewModel.checklistItems = goal.checklistItems?.map { ChecklistItemData(id: UUID(uuidString: $0.id) ?? UUID(), title: $0.title, notes: $0.notes ?? "") } ?? []
        
        // Load tag/theme
        viewModel.selectedGoalTheme = goal.primaryTag
        
        // Add to selected themes
        if let primaryTag = goal.primaryTag, !viewModel.selectedTags.contains(where: { $0.id == primaryTag.id }) {
            viewModel.selectedTags.append(primaryTag)
        }
        
        // Load schedule
        for weekday in 1...7 {
            let times = goal.timesForWeekday(weekday)
            if !times.isEmpty {
                viewModel.dayTimePreferences[weekday] = times
            }
        }
        
        // Load weather settings
        viewModel.weatherEnabled = goal.weatherEnabled
        if let conditions = goal.weatherConditionsTyped {
            viewModel.selectedWeatherConditions = Set(conditions)
        }
        if let minTemp = goal.minTemperature {
            viewModel.hasMinTemperature = true
            viewModel.minTemperature = minTemp
        }
        if let maxTemp = goal.maxTemperature {
            viewModel.hasMaxTemperature = true
            viewModel.maxTemperature = maxTemp
        }
        
        // Go straight to duration stage when editing
        viewModel.currentStage = .duration
    }
     
    /// Remove a theme from the selected themes list
    private func removeGoalTheme(_ goalTheme: GoalTag) {
        withAnimation(AnimationPresets.quickSpring) {
            viewModel.selectedTags.removeAll(where: { $0.title == goalTheme.title })
            
            // If we removed the currently selected theme, select the first available
            if viewModel.selectedGoalTheme?.title == goalTheme.title {
                viewModel.selectedGoalTheme = viewModel.selectedTags.first
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
        viewModel.dayTimePreferences.removeAll()
        
        switch preset {
        case .weekdayMornings:
            // Monday-Friday mornings
            for weekday in 2...6 {
                viewModel.dayTimePreferences[weekday] = [.morning]
            }
        case .everyEvening:
            // All days, evenings
            for weekday in 1...7 {
                viewModel.dayTimePreferences[weekday] = [.evening]
            }
        case .weekends:
            // Saturday and Sunday, all times
            viewModel.dayTimePreferences[7] = Set(TimeOfDay.allCases)
            viewModel.dayTimePreferences[1] = Set(TimeOfDay.allCases)
        case .everyDay:
            // All days, all times
            for weekday in 1...7 {
                viewModel.dayTimePreferences[weekday] = Set(TimeOfDay.allCases)
            }
        }
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func toggleTimeSlot(weekday: Int, timeOfDay: TimeOfDay) {
        if viewModel.dayTimePreferences[weekday]?.contains(timeOfDay) ?? false {
            viewModel.dayTimePreferences[weekday]?.remove(timeOfDay)
            
            // If all time slots are now unchecked, deactivate the day
            if viewModel.dayTimePreferences[weekday]?.isEmpty ?? true {
                viewModel.activeDays.remove(weekday)
                viewModel.dailyTargets.removeValue(forKey: weekday)
                withAnimation {
                    expandedDay = nil // Close the row when deactivating
                }
            }
        } else {
            viewModel.dayTimePreferences[weekday, default: []].insert(timeOfDay)
        }
        
        HapticFeedbackManager.trigger(.light)
    }
    
    // MARK: - Active Days Management
    
    @State private var expandedDay: Int? = nil // Track which day row is expanded (accordion-style)
    
    private func toggleActiveDay(_ weekday: Int) {
        if viewModel.activeDays.contains(weekday) {
            viewModel.activeDays.remove(weekday)
            viewModel.dailyTargets.removeValue(forKey: weekday)
        } else {
            viewModel.activeDays.insert(weekday)
            // Set default target when activating a day
            viewModel.dailyTargets[weekday] = viewModel.dailyMinimumMinutes ?? 10
        }
        
        HapticFeedbackManager.trigger(.light)
    }
    
    private func isDayActive(_ weekday: Int) -> Bool {
        viewModel.activeDays.contains(weekday)
    }
    
    private var calculatedWeeklyTarget: Int {
        return viewModel.dailyTargets.values.reduce(0, +)
    }
    
    private func updateDailyTarget(for weekday: Int, minutes: Int) {
        viewModel.dailyTargets[weekday] = minutes
    }
    
    private func shouldShowApplyToAll(for weekday: Int) -> Bool {
        guard let currentDuration = viewModel.dailyTargets[weekday] else { return false }
        
        // Check if any other active day has a different duration
        for otherWeekday in viewModel.activeDays where otherWeekday != weekday {
            if viewModel.dailyTargets[otherWeekday] != currentDuration {
                return true
            }
        }
        
        return false
    }
    
    private func applyDurationToAllDays(from sourceWeekday: Int) {
        guard let sourceDuration = viewModel.dailyTargets[sourceWeekday] else { return }
        
        // Apply the duration to all active days
        for weekday in viewModel.activeDays {
            viewModel.dailyTargets[weekday] = sourceDuration
        }
        
        // Dismiss keyboard and provide haptic feedback
        focusedField = nil
        HapticFeedbackManager.trigger(.success)
    }
    
    func handleButtonTap() {
        switch viewModel.currentStage {
        case .name:
            if let template = viewModel.selectedTemplate {
                // Prefill from template and go to duration without AI
                applyTemplate(template)
                withAnimation {
                    viewModel.currentStage = .duration
                }
            } else {
                // New goal: go to duration immediately, then start generating suggestions in background
                withAnimation {
                    viewModel.currentStage = .duration
                }
            }
        case .duration:
            saveGoal()
        }
    }
    
    /// Apply a template's predefined values
    func applyTemplate(_ template: GoalTemplateSuggestion) {
        // Set the title
        viewModel.userInput = template.title
        
        // Set duration
        viewModel.durationInMinutes = template.duration
        
        // Distribute the template duration across active days
        // If dailyGoal is true, use all 7 days; otherwise default to weekdays (Monday-Friday)
        let defaultDays: Set<Int> = (template.dailyGoal == true) ? Set(1...7) : Set(2...6)
        let targetDays = viewModel.activeDays.isEmpty ? defaultDays : viewModel.activeDays
        let dailyMinutes = targetDays.isEmpty ? template.duration : template.duration / targetDays.count
        
        for weekday in targetDays {
            viewModel.dailyTargets[weekday] = dailyMinutes
        }
        
        // Infer and set icon from template
        viewModel.selectedIcon = inferIcon(from: template.title)
        
        // Find the category for this template
        guard let category = viewModel.suggestionsData.categories.first(where: { category in
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
        
        viewModel.selectedGoalTheme = goalTheme
        
        // Add to selected themes if not already there
        if !viewModel.selectedTags.contains(where: { $0.title == goalTheme.title }) {
            viewModel.selectedTags.append(goalTheme)
        }
        
        // Set HealthKit metric if available
        if let metricRawValue = template.healthKitMetric,
           let metric = HealthKitMetric(rawValue: metricRawValue) {
            viewModel.selectedHealthKitMetric = metric
            viewModel.healthKitSyncEnabled = true
            
            // Request HealthKit authorization immediately
            Task {
                let healthKitManager = HealthKitManager()
                do {
                    try await healthKitManager.requestAuthorization(for: [metric])
                    print("✅ HealthKit authorization requested for \(metric.displayName)")
                } catch {
                    print("⚠️ Failed to request HealthKit authorization: \(error.localizedDescription)")
                    // Don't disable sync - user might grant permission later
                }
            }
        } else {
            viewModel.selectedHealthKitMetric = nil
            viewModel.healthKitSyncEnabled = false
        }
        

        // Set goal type if specified in template
        if let goalTypeString = template.goalType,
           let goalType = Goal.GoalType(rawValue: goalTypeString) {
            viewModel.selectedGoalType = goalType
        } else {
            viewModel.selectedGoalType = .time
        }

        // Set primary metric target if specified
        if let target = template.primaryMetricTarget {
            viewModel.primaryMetricTarget = target
        }

        print("✨ Template Applied:")
        print("   Title: \(template.title)")
        print("   Duration: \(template.duration) min")
        print("   Daily Minutes: \(dailyMinutes) min per day")
        print("   Goal Type: \(viewModel.selectedGoalType.rawValue)")
        print("   Primary Target: \(viewModel.primaryMetricTarget)")
        print("   Theme: \(template.theme)")
        print("   HealthKit: \(template.healthKitMetric ?? "none")")
    }
    
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0
    
    func saveGoal() {
        // Validate primary metric target before saving
        validatePrimaryMetricTarget()
        
        let goal: Goal
        let isEditing = viewModel.existingGoal != nil // TODO: hide existing goal
        
        // Track if goal was scheduled for today before editing (for toast notification)
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())
        let hadAnyScheduleForToday = viewModel.existingGoal?.timesForWeekday(todayWeekday).isEmpty == false
        
        // Determine theme based on user selection or suggestion
        let finalGoalTag: GoalTag
        if let customGoalTag = viewModel.selectedGoalTheme {
            // User has selected a tag (either custom or from suggestions)
            finalGoalTag = customGoalTag
        } else if let template = viewModel.selectedTemplate,
                  let category = viewModel.suggestionsData.categories.first(where: { $0.suggestions.contains(where: { $0.id == template.id }) }) {
            // Use the category's theme to create a tag
            let matchedTheme = matchTheme(named: category.color)
            finalGoalTag = GoalTag(title: category.name, themeID: matchedTheme.id)
        } else if let selectedSuggestion = viewModel.selectedSuggestion, let themeNames = selectedSuggestion.themes, !themeNames.isEmpty {
            // Use the first theme from generated suggestions
            let matchedTheme = matchTheme(named: themeNames[0])
            finalGoalTag = GoalTag(title: matchedTheme.title, themeID: matchedTheme.id)
        } else {
            // Find an unused theme, or fall back to random
            let unusedTheme = viewModel.findUnusedTheme(excluding: allGoals)
            finalGoalTag = GoalTag(title: unusedTheme.title, themeID: unusedTheme.id)
        }
        
        // Debug print day-time schedule
        if !viewModel.dayTimePreferences.isEmpty {
            print("\n📅 Day-Time Schedule:")
            let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            for (weekday, times) in viewModel.dayTimePreferences.sorted(by: { $0.key < $1.key }) where !times.isEmpty {
                let timeStrings = times.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.displayName }
                print("   \(weekdayNames[weekday]): \(timeStrings.joined(separator: ", "))")
            }
        }
      
        if let existingGoal = viewModel.existingGoal {
            // Update existing goal
            goal = existingGoal
            goal.title = viewModel.userInput
            goal.primaryTag = finalGoalTag
            goal.weeklyTarget = TimeInterval(calculatedWeeklyTarget * 60) // Weekly minutes to seconds
            // Calculate average daily target from per-day targets
            let avgDailyTarget = viewModel.activeDays.isEmpty ? 30 : (calculatedWeeklyTarget / viewModel.activeDays.count)
            goal.dailyMinimum = TimeInterval(avgDailyTarget * 60) // Average daily target in seconds
            goal.iconName = viewModel.selectedIcon
            goal.scheduleNotificationsEnabled = viewModel.scheduleNotificationsEnabled
            goal.completionNotificationsEnabled = viewModel.completionNotificationsEnabled
            goal.completionBehaviors = viewModel.selectedCompletionBehaviors
            goal.goalType = viewModel.selectedGoalType
            goal.healthKitMetric = viewModel.selectedHealthKitMetric
            goal.healthKitSyncEnabled = viewModel.healthKitSyncEnabled
            goal.primaryMetricDailyTarget = viewModel.primaryMetricTarget
            goal.notes = viewModel.goalNotes.isEmpty ? nil : viewModel.goalNotes
            goal.link = viewModel.goalLink.isEmpty ? nil : viewModel.goalLink
            
            // Clear existing schedule and set new one
            goal.dayTimeSchedule.removeAll()
        } else {
            // Create new goal
            if let selectedSuggestion = viewModel.selectedSuggestion, let title = selectedSuggestion.title {
                goal = Goal(
                    title: title,
                    primaryTag: finalGoalTag,
                    weeklyTarget: TimeInterval(calculatedWeeklyTarget * 60), // Weekly minutes to seconds
                    scheduleNotificationsEnabled: viewModel.scheduleNotificationsEnabled,
                    completionNotificationsEnabled: viewModel.completionNotificationsEnabled,
                    healthKitMetric: viewModel.selectedHealthKitMetric,
                    healthKitSyncEnabled: viewModel.healthKitSyncEnabled
                )
                goal.iconName = viewModel.selectedIcon
                let avgDailyTarget = viewModel.activeDays.isEmpty ? 30 : (calculatedWeeklyTarget / viewModel.activeDays.count)
                goal.dailyMinimum = TimeInterval(avgDailyTarget * 60)
                goal.completionBehaviors = viewModel.selectedCompletionBehaviors
                goal.goalType = viewModel.selectedGoalType
                goal.primaryMetricDailyTarget = viewModel.primaryMetricTarget
                goal.notes = viewModel.goalNotes.isEmpty ? nil : viewModel.goalNotes
                goal.link = viewModel.goalLink.isEmpty ? nil : viewModel.goalLink
            } else {
                goal = Goal(
                    title: viewModel.userInput,
                    primaryTag: finalGoalTag,
                    weeklyTarget: TimeInterval(calculatedWeeklyTarget * 60), // Weekly minutes to seconds
                    scheduleNotificationsEnabled: viewModel.scheduleNotificationsEnabled,
                    completionNotificationsEnabled: viewModel.completionNotificationsEnabled,
                    healthKitMetric: viewModel.selectedHealthKitMetric,
                    healthKitSyncEnabled: viewModel.healthKitSyncEnabled
                )
                goal.iconName = viewModel.selectedIcon
                let avgDailyTarget = viewModel.activeDays.isEmpty ? 30 : (calculatedWeeklyTarget / viewModel.activeDays.count)
                goal.dailyMinimum = TimeInterval(avgDailyTarget * 60)
                goal.dailyMinimum = viewModel.hasDailyMinimum ? TimeInterval((viewModel.dailyMinimumMinutes ?? 10) * 60) : nil
                goal.completionBehaviors = viewModel.selectedCompletionBehaviors
                goal.goalType = viewModel.selectedGoalType
                goal.primaryMetricDailyTarget = viewModel.primaryMetricTarget
                goal.notes = viewModel.goalNotes.isEmpty ? nil : viewModel.goalNotes
                goal.link = viewModel.goalLink.isEmpty ? nil : viewModel.goalLink
            }
        }
        
        // ✅ Save the day-time schedule using the convenience method
        // For active days, use their time preferences, or default to all times if not set
        for weekday in 1...7 {
            if viewModel.activeDays.contains(weekday) {
                // Day is active - use specified times or default to all times
                let times = viewModel.dayTimePreferences[weekday] ?? Set(TimeOfDay.allCases)
                goal.setTimes(times, forWeekday: weekday)
            } else {
                // Day is not active - clear any time preferences
                goal.setTimes([], forWeekday: weekday)
            }
        }
        
        // ✅ Save per-day targets
        goal.dailyTargets.removeAll()
        for (weekday, minutes) in viewModel.dailyTargets {
            goal.dailyTargets[String(weekday)] = TimeInterval(minutes * 60)
        }
        
        // ✅ Save weather settings
        goal.weatherEnabled = viewModel.weatherEnabled
        if viewModel.weatherEnabled {
            goal.weatherConditionsTyped = viewModel.selectedWeatherConditions.isEmpty ? nil : Array(viewModel.selectedWeatherConditions)
            goal.minTemperature = viewModel.hasMinTemperature ? viewModel.minTemperature : nil
            goal.maxTemperature = viewModel.hasMaxTemperature ? viewModel.maxTemperature : nil
        } else {
            goal.weatherConditionsTyped = nil
            goal.minTemperature = nil
            goal.maxTemperature = nil
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
        for item in viewModel.checklistItems where !item.title.trimmingCharacters(in: .whitespaces).isEmpty {
            let checklistItem = ChecklistItem(title: item.title, notes: item.notes.isEmpty ? nil : item.notes, goal: goal)
            modelContext.insert(checklistItem)
            goal.checklistItems?.append(checklistItem)
        }
        
        print("\n✅ Goal \(isEditing ? "updated" : "saved") with schedule:")
        print(goal.scheduleSummary)
        if viewModel.weatherEnabled {
            print("🌤️ Weather triggers: \(viewModel.selectedWeatherConditions.map { $0.displayName }.joined(separator: ", "))")
            if viewModel.hasMinTemperature { print("   Min temp: \(Int(viewModel.minTemperature))°C") }
            if viewModel.hasMaxTemperature { print("   Max temp: \(Int(viewModel.maxTemperature))°C") }
        }
        
        // Request notification permissions if enabled
        if viewModel.selectedCompletionBehaviors.contains(.notify) {
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
            if viewModel.scheduleNotificationsEnabled && goal.hasSchedule {
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
        }
        
        // Reset the plan generation timestamp to trigger a new plan
        lastPlanGeneratedTimestamp = 0
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
        let helper = GoalEditorIconHelper()
        return helper.inferIcon(from: title)
    }
    
    /// Handle color selection from the color picker
    private func handleColorSelection(_ preset: ThemePreset) {
        viewModel.selectedColorPreset = preset
        
        // Update existing tag or create new one
        if let currentTheme = viewModel.selectedGoalTheme {
            currentTheme.themeID = preset.id
        } else if !viewModel.selectedTags.isEmpty {
            viewModel.selectedTags[0].themeID = preset.id
            viewModel.selectedGoalTheme = viewModel.selectedTags[0]
        } else {
            // No tags exist - create new tag with selected color
            let newTag = GoalTag(title: preset.title, themeID: preset.id)
            viewModel.selectedGoalTheme = newTag
            viewModel.selectedTags.append(newTag)
        }
        
        viewModel.showingColorPicker = false
    }
    
    /// Match a theme name to an actual Theme from the themes array
    func matchTheme(named themeName: String) -> ThemePreset {
        let helper = GoalEditorThemeHelper()
        return helper.matchTheme(named: themeName)
    }
    
    func generateChecklist(for input: String) {
        viewModel.errorMessage = nil

        Task {
            do {
                // Replace this part with proper FoundationModels API usage as needed
                // This is a placeholder showing where you would use your LLM
                let response = try await generateTasksWithLLM(prompt: input)
                
                try await generateStreamedSuggestions()
                await MainActor.run {
                    let wrapped = GoalEditorSuggestionsResult(suggestions: response)
                    self.viewModel.result = wrapped.asPartiallyGenerated()
                }
            } catch {
                await MainActor.run {
                    self.viewModel.errorMessage = error.localizedDescription
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
            

            "Come up with up to 10 separate goals for the user to add based on their input, including how long to spend on each goal. Return the goals as a list of dictionaries with the short title, subtitle, description and duration (no more than 30 minutes) in the separate property, not the title. Be specific, e.g. 'Cardio' instead of 'Exercise routine'. Include things like gardening, reading a book, or learning a new skill, playing a musical instrument. Make it 100% relevant to: \(viewModel.userInput)"
        }
        
        for try await partialResponse in stream {
            // Handle each partial response here
            await MainActor.run {
                self.viewModel.result = partialResponse.content
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




