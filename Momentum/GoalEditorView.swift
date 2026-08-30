import SwiftUI
import MomentumKit
import SwiftData
import UserNotifications
import EventKit
#if os(iOS)
import WidgetKit
#endif

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allGoals: [Goal]
    @Query private var allTags: [GoalTag]
    @Bindable private var viewModel: GoalEditorViewModel
    
    init(viewModel: GoalEditorViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Stage Management
    
    enum Stage: Identifiable {
        case title
        case editor
        
        var id: String {
            switch self {
            case .title: "title"
            case .editor: "editor"
            }
        }
        
        var buttonLabel: String {
            switch self {
            case .title: "Next"
            case .editor: "Save Goal"
            }
        }
    }
    
    // Legacy Field enum kept for ExpandableDayRow / ScheduleSection compatibility
    enum Field: Hashable {
        case goalName
        case duration
        case dailyMinimum
        case scheduleDay(Int)
    }
    
    @State private var stage: Stage = .title
    @State private var cardExpanded: Bool = false
    @State private var selectedSuggestionCategory: Int = -1 // -1 = Featured
    @State private var showingPremiumPaywall = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Staggered section visibility
    @State private var showScheduleSection = false
    @State private var showSettingsSection = false
    @State private var showIntervalsSection = false
    @State private var showNotesSection = false
    
    // Interval editor sheet
    @State private var intervalListToEdit: IntervalList?
    
    // Keyboard tracking
    @State private var isKeyboardVisible = false
    
    // Debounce for theme recommendation
    @State private var themeRecommendationDebounce: Task<Void, Never>?
    
    private var activeThemeColor: Color {
        viewModel.getActiveThemeColor(colorScheme: colorScheme)
    }
    
    private var isEditingExisting: Bool {
        viewModel.existingGoal != nil
    }
    
    private var buttonEnabled: Bool {
        switch stage {
        case .title:
            return !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.selectedTemplate != nil
        case .editor:
            return true
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Section 1: Goal card
                        editorSection(
                            number: 1,
                            title: stage == .title ? "Name it" : "Goal & target"
                        ) {
                            GoalEditorCard(vm: viewModel, isExpanded: $cardExpanded)
                        }
                        
                        // Suggestions (only at title stage, not when editing)
                        if stage == .title && !isEditingExisting {
                            goalSuggestionsView
                                .transition(.opacity)
                        }
                        
                        // Section 2: Recommend when
                        if showScheduleSection {
                            editorSection(number: 2, title: "Recommend when") {
                                RecommendWhenCard(vm: viewModel)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                        
                        // Section 3: Settings
                        if showSettingsSection {
                            editorSection(number: 3, title: "Settings") {
                                SettingsEditorCard(vm: viewModel)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                        
                        // Section 4: Intervals
                        if showIntervalsSection {
                            editorSection(number: 4, title: "Intervals") {
                                IntervalsEditorCard(vm: viewModel, onEdit: { list in
                                    intervalListToEdit = list
                                })
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                        
                        // Section 5: Notes & checklist
                        if showNotesSection {
                            editorSection(number: 5, title: "Notes & checklist") {
                                NotesChecklistCard(vm: viewModel)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                .background(Color(.secondarySystemBackground))
                
                // Bottom navigation bar
                bottomBar
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stage)
            .onChange(of: stage) {
                if stage == .editor {
                    cardExpanded = true
                    revealEditorSections()
                } else {
                    cardExpanded = false
                    showScheduleSection = false
                    showSettingsSection = false
                    showIntervalsSection = false
                    showNotesSection = false
                }
            }
            .navigationTitle(isEditingExisting ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(activeThemeColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddThemeSheet) {
            TagSelectionSheet(
                allTags: allTags,
                selectedTags: $viewModel.selectedTags,
                selectedGoalTheme: $viewModel.selectedGoalTheme,
                modelContext: modelContext,
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .sheet(isPresented: $viewModel.showingRelevanceRuleSheet) {
            RelevanceRuleView(
                viewModel: viewModel,
                activeThemeColor: activeThemeColor,
                allGoals: allGoals
            )
        }
        .sheet(item: $intervalListToEdit) { list in
            IntervalsEditorView(list: list)
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
        .onAppear {
            // If editing an existing goal, start at the editor stage with everything visible
            if isEditingExisting {
                stage = .editor
                cardExpanded = true
                showScheduleSection = true
                showSettingsSection = true
                showIntervalsSection = true
                showNotesSection = true
                viewModel.computeRecommendedTarget(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.selectedTemplate?.id) {
            // Auto-advance to editor when a suggestion is tapped
            guard stage == .title, viewModel.selectedTemplate != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                handleNextTap()
            }
        }
        .onChange(of: viewModel.userInput) {
            // Debounce: kick off a theme recommendation after a short pause
            guard stage == .title, !isEditingExisting else { return }
            themeRecommendationDebounce?.cancel()
            themeRecommendationDebounce = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                viewModel.recommendTheme(for: viewModel.userInput)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .interactiveDismissDisabled(stage == .editor)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            if isKeyboardVisible && stage == .editor {
                // Keyboard toolbar: dismiss button
                HStack {
                    Spacer()
                    
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Text("Done")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(activeThemeColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 12) {
                    // Back button (only in editor stage)
                    if stage == .editor {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                stage = .title
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.tertiarySystemFill))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Next / Save button
                    Button {
                        handleNextTap()
                    } label: {
                        Text(stage.buttonLabel)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(buttonForegroundColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(buttonBackgroundStyle)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!buttonEnabled)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
        .animation(.snappy(duration: 0.2), value: isKeyboardVisible)
    }
    
    private var buttonForegroundColor: Color {
        guard buttonEnabled else { return .white }
        if let preset = viewModel.activeThemePreset {
            return preset.foregroundColor(for: colorScheme)
        }
        return .white
    }
    
    private var buttonBackgroundStyle: some ShapeStyle {
        if buttonEnabled, let preset = viewModel.activeThemePreset {
            return AnyShapeStyle(preset.gradient(for: colorScheme))
        }
        return AnyShapeStyle(Color.gray)
    }
    
    // MARK: - Section Helper
    
    private func editorSection<Content: View>(
        number: Int,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GoalEditorSectionHeader(number: number, title: title)
                .padding(.horizontal, 20)
            
            content()
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Goal Suggestions
    
    private var goalSuggestionsView: some View {
        let categories = viewModel.suggestionsData.categories
        
        return VStack(spacing: 16) {
            // Divider label
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                Text("OR PICK A STARTER")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 20)
            
            // Category tabs
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Featured tab
                        FeaturedTab(isSelected: selectedSuggestionCategory == -1)
                            .id(-1)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    selectedSuggestionCategory = -1
                                }
                                HapticFeedbackManager.trigger(.light)
                            }
                        
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            GoalSuggestionCategoryTab(
                                category: category,
                                isSelected: selectedSuggestionCategory == index
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    selectedSuggestionCategory = index
                                }
                                HapticFeedbackManager.trigger(.light)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: selectedSuggestionCategory) {
                    withAnimation {
                        scrollProxy.scrollTo(selectedSuggestionCategory, anchor: .center)
                    }
                }
            }
            
            if selectedSuggestionCategory == -1 {
                // Featured header
                HStack {
                    Text("Featured")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    let count = viewModel.suggestionsData.featuredSuggestions.count
                    Text("\(count) IDEAS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                
                // Featured grid
                FeaturedSuggestionsGrid(
                    viewModel: viewModel,
                    showingPremiumPaywall: $showingPremiumPaywall
                )
                .padding(.horizontal, 16)
            } else if categories.indices.contains(selectedSuggestionCategory) {
                let category = categories[selectedSuggestionCategory]
                
                // Category header
                HStack {
                    Text(category.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(category.suggestions.count) IDEAS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                
                // Suggestion grid
                GoalSuggestionCategoryView(
                    category: category,
                    selectedTemplate: $viewModel.selectedTemplate,
                    userInput: $viewModel.userInput
                )
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallSheet()
        }
    }
    
    // MARK: - Actions
    
    private func handleNextTap() {
        switch stage {
        case .title:
            // Dismiss keyboard immediately
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            // Apply template if matched, advance VM to .duration so it applies defaults
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                viewModel.handleButtonTap(allTags: allTags)
                stage = .editor
            }
            
            // Request HealthKit auth if template set a metric
            if viewModel.selectedTemplate != nil,
               let metric = viewModel.selectedHealthKitMetric,
               viewModel.healthKitSyncEnabled {
                Task {
                    let healthKitManager = HealthKitManager()
                    do {
                        try await healthKitManager.requestAuthorization(for: [metric])
                    } catch {
                        print("Failed to request HealthKit authorization: \(error.localizedDescription)")
                    }
                }
            }
            
        case .editor:
            saveGoal()
        }
    }
    
    private func revealEditorSections() {
        let spring = Animation.spring(response: 0.45, dampingFraction: 0.85)
        
        withAnimation(spring.delay(0.15)) {
            showScheduleSection = true
        }
        withAnimation(spring.delay(0.30)) {
            showSettingsSection = true
        }
        withAnimation(spring.delay(0.45)) {
            showIntervalsSection = true
        }
        withAnimation(spring.delay(0.60)) {
            showNotesSection = true
        }
    }
    
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0
    
    private func saveGoal() {
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
                print("Failed to save goal: \(error)")
                errorMessage = "Failed to save goal: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
}


// MARK: - Intervals Editor Card

private struct IntervalsEditorCard: View {
    @Bindable var vm: GoalEditorViewModel
    var onEdit: (IntervalList) -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 0) {
            // Existing interval lists
            ForEach(vm.intervalLists) { list in
                Button {
                    onEdit(list)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name.isEmpty ? "Untitled Routine" : list.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            let count = list.intervals?.count ?? 0
                            Text("\(count) interval\(count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        if let index = vm.intervalLists.firstIndex(where: { $0.id == list.id }) {
                            let removed = vm.intervalLists.remove(at: index)
                            modelContext.delete(removed)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                
                if list.id != vm.intervalLists.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            
            // Add button
            Button {
                let newList = IntervalList(name: "", orderIndex: vm.intervalLists.count)
                modelContext.insert(newList)
                vm.intervalLists.append(newList)
                onEdit(newList)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Interval Routine")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
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
