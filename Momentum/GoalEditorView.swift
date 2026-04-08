import SwiftUI
import MomentumKit
import SwiftData
import UserNotifications
import EventKit
#if os(iOS)
import WidgetKit
#endif

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
    @State private var expandedDay: Int? = nil
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Computed property for the active theme color
    private var activeThemeColor: Color {
        viewModel.getActiveThemeColor(colorScheme: colorScheme)
    }
    
    /// Calculate appropriate text color for buttons based on background luminance
    private var buttonTextColor: Color {
        let luminance = activeThemeColor.luminance ?? 0.5
        return luminance > 0.5 ? .black : .white
    }



    // Helper to find matching suggestion and category
    private func findMatchingSuggestion(for input: String) -> (categoryIndex: Int, suggestion: GoalTemplateSuggestion)? {
        return viewModel.suggestionsData.categories.enumerated().compactMap { (idx, category) -> (Int, GoalTemplateSuggestion)? in
            if let suggestion = category.suggestions.first(where: { viewModel.matchesSuggestion($0, with: input, aliases: viewModel.suggestionAliases) }) {
                return (idx, suggestion)
            }
            return nil
        }.first
    }
    
    // Computed binding for HealthKit daily target
    private var healthKitDailyTargetBinding: Binding<Int?> {
        Binding(
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
    }
    
    // Handle user input changes
    private func handleUserInputChange(_ newValue: String) {
        // Clear selection if user is typing freeform
        if !newValue.isEmpty {
            viewModel.selectedTemplate = nil
        }

        // Try to find a match among suggestions by title or aliases and select it
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let (categoryIndex, matchedSuggestion) = findMatchingSuggestion(for: trimmed) {
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
                    viewModel.selectedIcon = viewModel.inferIcon(from: trimmed)
                }
            }
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        // Custom input section
        Section {
            TextField("What do you want to do?", text: $viewModel.userInput)
                .focused($focusedField, equals: .goalName)
                .onChange(of: viewModel.userInput) { _, newValue in
                    handleUserInputChange(newValue)
                }
        }
        
        if viewModel.currentStage == .name {
            SuggestionsSection(
                viewModel: viewModel,
                scrollProxy: $scrollProxy
            )
        }
        
        if viewModel.currentStage == .duration {
            ThemeSelectionSection(
                viewModel: viewModel,
                activeThemeColor: activeThemeColor
            )

            ScheduleSection(
                viewModel: viewModel,
                focusedField: $focusedField,
                expandedDay: $expandedDay,
                activeThemeColor: activeThemeColor,
                onToggleTime: toggleTimeSlot
            )

            CompletionBehaviorsSection(
                viewModel: viewModel,
                activeThemeColor: activeThemeColor
            )
            
            HealthKitConfigurationView(
                selectedMetric: $viewModel.selectedHealthKitMetric,
                syncEnabled: $viewModel.healthKitSyncEnabled,
                dailyTargetMinutes: healthKitDailyTargetBinding
            )
            
            // Screen Time Configuration (only shown when editing an existing goal)
            if let existingGoal = viewModel.existingGoal {
                ScreenTimeGoalConfigurationView(goal: existingGoal)
            }
            
            NotesAndResourcesSection(
                viewModel: viewModel,
                activeThemeColor: activeThemeColor
            )
            
            // Checklist Section
            ChecklistSection(viewModel: viewModel, activeThemeColor: activeThemeColor)
            
            // Weather-based visibility
            WeatherConfigSection(viewModel: viewModel, activeThemeColor: activeThemeColor)
        }
        
        Spacer()
            .frame(height: LayoutConstants.Heights.filterBar)
    }
    
    var body: some View {
        NavigationStack {
            List {
                listContent
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
                        .disabled(!canFocusPrevious)
                        
                        Button {
                            focusNextField()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(!canFocusNext)
                        
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
                    if case .scheduleDay(let weekday) = focusedField, viewModel.shouldShowApplyToAll(for: weekday) {
                        Button {
                            viewModel.applyDurationToAllDays(from: weekday)
                            // Dismiss keyboard and provide haptic feedback
                            focusedField = nil
                            HapticFeedbackManager.trigger(.success)
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
                onSelect: { preset in
                    viewModel.handleColorSelection(preset)
                }
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
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            // Load existing goal data if editing
            if let existingGoal = viewModel.existingGoal {
                viewModel.loadGoalData(from: existingGoal)
            } else if viewModel.userInput.isEmpty {
                viewModel.generateChecklist(for: "")
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
    
    private var canFocusNext: Bool {
        switch focusedField {
        case .goalName:
            return viewModel.currentStage == .duration
        case .duration:
            return viewModel.hasDailyMinimum || getNextActiveScheduleDay(after: nil) != nil
        case .dailyMinimum:
            return getNextActiveScheduleDay(after: nil) != nil
        case .scheduleDay(let weekday):
            return getNextActiveScheduleDay(after: weekday) != nil
        case .none:
            return true
        }
    }
    
    private var canFocusPrevious: Bool {
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
        viewModel.getNextActiveScheduleDay(after: weekday)
    }
    
    /// Get the previous active schedule day before the given weekday (or last if nil)
    private func getPreviousActiveScheduleDay(before weekday: Int?) -> Int? {
        viewModel.getPreviousActiveScheduleDay(before: weekday)
    }
    
    // MARK: - Helper Functions


    
    private func toggleTimeSlot(weekday: Int, timeOfDay: TimeOfDay) {
        // Check if we're deactivating the last time slot (for animation)
        let willDeactivateDay = (viewModel.dayTimePreferences[weekday]?.count == 1 && 
                                 viewModel.dayTimePreferences[weekday]?.contains(timeOfDay) == true)
        
        // Call ViewModel for business logic
        viewModel.toggleTimeSlot(weekday: weekday, timeOfDay: timeOfDay)
        
        // Handle UI concerns
        if willDeactivateDay {
            withAnimation {
                expandedDay = nil // Close the row when deactivating
            }
        }
        
        HapticFeedbackManager.trigger(.light)
    }
    
    // MARK: - Button Actions
    
    func handleButtonTap() {
        switch viewModel.currentStage {
        case .name:
            // Call ViewModel for stage progression logic (handles template application internally)
            withAnimation {
                viewModel.handleButtonTap(allTags: allTags)
            }
            
            // Request HealthKit authorization if template applied and needed
            if viewModel.selectedTemplate != nil,
               let metric = viewModel.selectedHealthKitMetric,
               viewModel.healthKitSyncEnabled {
                Task {
                    let healthKitManager = HealthKitManager()
                    do {
                        try await healthKitManager.requestAuthorization(for: [metric])
                        print("✅ HealthKit authorization requested for \(metric.displayName)")
                    } catch {
                        print("⚠️ Failed to request HealthKit authorization: \(error.localizedDescription)")
                    }
                }
            }
        case .duration:
            saveGoal()
        }
    }
    
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0
    
    func saveGoal() {
        Task {
            do {
                let newTimestamp = try await viewModel.saveGoal(
                    modelContext: modelContext,
                    allGoals: allGoals,
                    calculatedWeeklyTarget: viewModel.calculatedWeeklyTarget,
                    currentPlanTimestamp: lastPlanGeneratedTimestamp,
                    onRequestNotificationPermissions: {
                        requestNotificationPermissions()
                    },
                    onDismiss: {
                        dismiss()
                    }
                )
                lastPlanGeneratedTimestamp = newTimestamp
            } catch {
                print("❌ Failed to save goal: \(error)")
                errorMessage = "Failed to save goal: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
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
