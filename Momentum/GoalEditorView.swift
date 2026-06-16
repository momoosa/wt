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
    
    enum Stage: Int, CaseIterable, Identifiable {
        case title = 0
        case goal = 1
        case schedule = 2
        case extras = 3
        
        var id: Int { rawValue }
        
        var nextStage: Stage? {
            Stage(rawValue: rawValue + 1)
        }
        
        var previousStage: Stage? {
            rawValue > 0 ? Stage(rawValue: rawValue - 1) : nil
        }
        
        var buttonLabel: String {
            switch self {
            case .title: "Next"
            case .goal: "Next"
            case .schedule: "Next"
            case .extras: "Save Goal"
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
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
        case .goal, .schedule, .extras:
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
                        
                        // Section 2: Recommend when
                        if stage.rawValue >= Stage.schedule.rawValue {
                            editorSection(number: 2, title: "Recommend when") {
                                RecommendWhenCard(vm: viewModel)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                        
                        // Section 3: Settings
                        if stage.rawValue >= Stage.extras.rawValue {
                            editorSection(number: 3, title: "Settings") {
                                SettingsEditorCard(vm: viewModel)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                            
                            editorSection(number: 4, title: "Notes & checklist") {
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
                cardExpanded = stage != .title
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
        .sheet(isPresented: $viewModel.showingRelevanceRuleSheet) {
            RelevanceRuleView(
                viewModel: viewModel,
                activeThemeColor: activeThemeColor
            )
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
            // If editing an existing goal, start at the goal stage expanded
            if isEditingExisting {
                stage = .goal
                cardExpanded = true
            }
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Back button
                if let previous = stage.previousStage {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            stage = previous
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
        .background(Color(.systemBackground))
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
    
    // MARK: - Actions
    
    private func handleNextTap() {
        switch stage {
        case .title:
            // Apply template if matched, advance VM to .duration so it applies defaults
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                viewModel.handleButtonTap(allTags: allTags)
                stage = .goal
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
            
        case .goal:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                stage = .schedule
            }
            
        case .schedule:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                stage = .extras
            }
            
        case .extras:
            saveGoal()
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
