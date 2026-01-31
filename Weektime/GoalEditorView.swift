import SwiftUI
import FoundationModels
import WeektimeKit
import SwiftData
import UserNotifications

// MARK: - AI Suggestion Model
@Generable
struct GoalThemeSuggestionsResponse: Codable {
    var suggestedThemes: [String] // Array of theme names (e.g., ["Wellness", "Fitness", "Productivity"])
    var reasoning: String? // optional explanation
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Optional existing goal for editing
    var existingGoal: Goal?
    
    @State private var userInput: String = ""
    @State private var result: GoalEditorSuggestionsResult.PartiallyGenerated?
    @State private var errorMessage: String?
    @State private var session = LanguageModelSession(instructions: "Come up with up to three separate goals for the user to add based on their input, including how long to spend on each goal. Return the goals as a list of dictionaries with the title + duration.")
    @State var selectedSuggestion: GoalSuggestion.PartiallyGenerated?
    @State private var currentStage: EditorStage = .name
    @State private var durationInMinutes: Int = 30
    @State private var notificationsEnabled: Bool = false
    @State private var selectedHealthKitMetric: HealthKitMetric?
    @State private var healthKitSyncEnabled: Bool = false
    @State private var isGeneratingSuggestions = false
    @State private var aiSuggestedThemes: [Theme] = []
    @State private var aiReasoning: String?
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
    @State private var weeklySchedule: [Int: DaySchedule] = {
        // Keys 1...7 for Sun(1) ... Sat(7) using Calendar component .weekday
        var dict: [Int: DaySchedule] = [:]
        let calendar = Calendar.current
        let defaultMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        for weekday in 1...7 {
            dict[weekday] = DaySchedule(enabled: false, relation: .before, time: defaultMorning)
        }
        return dict
    }()
    
    // Option 2: Multiple times list with per-day overrides
    @State private var globalTimes: [Date] = []
    // Keys 1...7 for Sun...Sat
    @State private var perDayTimes: [Int: [Date]] = [:]
    
    // Grid scheduling types
    enum TimeBucket: String, CaseIterable, Identifiable { case morning, midday, afternoon, evening, night; var id: String { rawValue }
        var displayName: String {
            switch self {
            case .morning: return "Morning"
            case .midday: return "Midday"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .night: return "Night"
            }
        }
        var hoursRange: ClosedRange<Int> {
            switch self {
            case .morning: return 6...10
            case .midday: return 10...14
            case .afternoon: return 14...17
            case .evening: return 17...21
            case .night: return 21...23
            }
        }
    }
    struct DayBucket: Identifiable, Hashable {
        var id: String {
            return "\(weekday)-\(bucket.id)"
        }
        let weekday: Int
        let bucket: TimeBucket
    }
    @State private var bucketTimes: [DayBucket: [DateComponents]] = [:]
    @State private var editingBucket: DayBucket?
    @State private var tempTimes: [Date] = []
    
    // Simple multi-select time of day
    enum SimpleTimeOfDay: String, CaseIterable, Identifiable { case anytime = "Anytime", morning = "Morning", afternoon = "Afternoon", evening = "Evening"; var id: String { rawValue } }
    @State private var selectedSimpleTimes: Set<SimpleTimeOfDay> = [.anytime]
    
    // Custom theme selection
    @State private var selectedTheme: Theme?
    @State private var useCustomTheme: Bool = false
    @State private var showingAddThemeSheet: Bool = false
    @State private var customThemeName: String = ""
    @State private var customThemes: [Theme] = []
    @State private var selectedThemes: [Theme] = [] // Track user's selected themes
    @State private var selectedBaseThemeForCustom: Theme? // For creating custom themes
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                    
                    List {
                            // Custom input section
                            Section {
                                TextField("What do you want to do?", text: $userInput)
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
                                Picker("Duration (minutes)", selection: $durationInMinutes) {
                                    ForEach([5, 10, 15, 20, 30, 45, 60, 90], id: \.self) { minutes in
                                        Text("\(minutes) min").tag(minutes)
                                    }
                                }
                                .pickerStyle(.menu)
                            }                            
                            
                            Section(header: Text("When to recommend this goal")) {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Header with time periods
                                    HStack(spacing: 4) {
                                        Text("")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                                            VStack(spacing: 4) {
                                                Image(systemName: timeOfDay.icon)
                                                    .font(.caption2)
                                                Text(timeOfDay.displayName)
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Days with toggleable time periods
                                    ForEach(weekdays, id: \.0) { weekday, name in
                                        HStack(spacing: 4) {
                                            Text(name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .frame(width: 50, alignment: .leading)
                                            
                                            ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                                                TimeSlotButton(
                                                    isSelected: dayTimePreferences[weekday]?.contains(timeOfDay) ?? false,
                                                    action: {
                                                        toggleTimeSlot(weekday: weekday, timeOfDay: timeOfDay)
                                                    }
                                                )
                                                .frame(maxWidth: .infinity)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                Text("Tap cells to choose when this goal should be recommended each day")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            
                            Section(header: Text("Theme")) {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Tag cloud with flow layout - show only selected themes
                                    TagFlowLayout(spacing: 8) {
                                        ForEach(selectedThemes, id: \.id) { theme in
                                            ThemeTagButton(
                                                theme: theme,
                                                isSelected: selectedTheme?.id == theme.id,
                                                action: {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        selectedTheme = theme
                                                        useCustomTheme = true
                                                    }
                                                    
                                                    #if os(iOS)
                                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                                    generator.impactOccurred()
                                                    #endif
                                                }
                                            )
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    removeTheme(theme)
                                                } label: {
                                                    Label("Remove", systemImage: "trash")
                                                }
                                            }
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
                                                    .strokeBorder(Color.accentColor, lineWidth: 2, antialiased: true)
                                            )
                                            .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    if selectedThemes.isEmpty {
                                        Text("Tap 'Add Theme' to choose a color theme for your goal")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            
                            Section(header: Text("Notifications")) {
                                Toggle("Notify when target is reached", isOn: $notificationsEnabled)
                            }
                            
                            HealthKitConfigurationView(
                                selectedMetric: $selectedHealthKitMetric,
                                syncEnabled: $healthKitSyncEnabled
                            )
                        }
                        
                    }
                    .animation(.spring(), value: result)
                    
                // Bottom button
                VStack(spacing: 0) {
                    Divider()
                    Button(action: {
                        handleButtonTap()
                    }) {
                        HStack {
                            if isGeneratingSuggestions {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Generating suggestions...")
                            } else {
                                Text(currentStage == .name ? "Next" : "Save")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background {
                            Capsule()
                                .fill(buttonEnabled && !isGeneratingSuggestions ? Color.accentColor : Color.gray)
                        }
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!buttonEnabled || isGeneratingSuggestions)
                    .padding()
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle(currentStage == .name ? (existingGoal == nil ? "New Goal" : "Edit Goal") : "Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if currentStage == .duration && existingGoal == nil {
                            // Only allow going back to name stage if creating new goal
                            withAnimation {
                                currentStage = .name
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
                // Removed the trailing toolbar button since we have the bottom button now
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .sheet(item: $editingBucket) { key in
            NavigationStack {
                VStack {
                    if tempTimes.isEmpty {
                        Text("Add one or more exact times for this cell.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    List {
                        ForEach(tempTimes.indices, id: \.self) { idx in
                            DatePicker(
                                "Time \(idx + 1)",
                                selection: Binding(
                                    get: { tempTimes[idx] },
                                    set: { tempTimes[idx] = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            Button(role: .destructive) {
                                tempTimes.remove(at: idx)
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        Button {
                            let base = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                            tempTimes.append(base)
                        } label: {
                            Label("Add time", systemImage: "plus.circle")
                        }
                    }
                }
                .navigationTitle("Edit Times")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingBucket = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            let comps = tempTimes.map { Calendar.current.dateComponents([.hour, .minute], from: $0) }
                            bucketTimes[key] = comps
                            editingBucket = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddThemeSheet) {
            NavigationStack {
                List {
                    // Available themes section
                    Section(header: Text("Available Themes")) {
                        ForEach(allAvailableThemes.filter { theme in
                            !selectedThemes.contains(where: { $0.id == theme.id })
                        }, id: \.id) { theme in
                            Button(action: {
                                addThemeToSelected(theme)
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [theme.light, theme.dark],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                    
                                    Text(theme.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(theme.dark)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Create custom theme section
                    Section(header: Text("Create Custom Theme")) {
                        TextField("Theme name", text: $customThemeName)
                        
                        Text("Base Color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(themes, id: \.id) { theme in
                                    ThemeColorButton(
                                        theme: theme,
                                        isSelected: selectedBaseThemeForCustom?.id == theme.id,
                                        action: {
                                            selectedBaseThemeForCustom = theme
                                            
                                            #if os(iOS)
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            #endif
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets())
                        
                        Button(action: {
                            createCustomTheme()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Create Custom Theme")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(customThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedBaseThemeForCustom == nil)
                    }
                }
                .navigationTitle("Add Theme")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showingAddThemeSheet = false
                        }
                    }
                }
            }
        }
        .task {
            prewarm()
            
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
    
    // MARK: - Helper Functions
    
    /// Load existing goal data for editing
    private func loadGoalData(from goal: Goal) {
        userInput = goal.title
        durationInMinutes = Int(goal.weeklyTarget / 60 / 7) // Convert weekly back to daily
        notificationsEnabled = goal.notificationsEnabled
        selectedHealthKitMetric = goal.healthKitMetric
        healthKitSyncEnabled = goal.healthKitSyncEnabled
        
        // Load theme
        if let matchedTheme = themes.first(where: { $0.id == goal.primaryTheme.theme.id }) {
            selectedTheme = matchedTheme
            useCustomTheme = true
            
            // Add to selected themes
            if !selectedThemes.contains(where: { $0.id == matchedTheme.id }) {
                selectedThemes.append(matchedTheme)
            }
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
    
    var allAvailableThemes: [Theme] {
        return themes + customThemes
    }
    
    private func addCustomTheme(name: String, baseOn baseTheme: Theme) {
        let newTheme = Theme(
            id: "custom_\(UUID().uuidString)",
            title: name,
            light: baseTheme.light,
            dark: baseTheme.dark, neon: baseTheme.neon
        )
        customThemes.append(newTheme)
        
        // Auto-select the new theme
        withAnimation(.spring(response: 0.3)) {
            selectedTheme = newTheme
            useCustomTheme = true
        }
        
        // Reset text field
        customThemeName = ""
        showingAddThemeSheet = false
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Add a theme to the selected themes list
    private func addThemeToSelected(_ theme: Theme) {
        withAnimation(.spring(response: 0.3)) {
            selectedThemes.append(theme)
            selectedTheme = theme
            useCustomTheme = true
        }
        
        showingAddThemeSheet = false
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Create and add a custom theme
    private func createCustomTheme() {
        guard let baseTheme = selectedBaseThemeForCustom else { return }
        let name = customThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let newTheme = Theme(
            id: "custom_\(UUID().uuidString)",
            title: name,
            light: baseTheme.light,
            dark: baseTheme.dark,
            neon: baseTheme.neon
        )
        
        customThemes.append(newTheme)
        
        withAnimation(.spring(response: 0.3)) {
            selectedThemes.append(newTheme)
            selectedTheme = newTheme
            useCustomTheme = true
        }
        
        // Reset
        customThemeName = ""
        selectedBaseThemeForCustom = nil
        showingAddThemeSheet = false
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Remove a theme from the selected themes list
    private func removeTheme(_ theme: Theme) {
        withAnimation(.spring(response: 0.3)) {
            selectedThemes.removeAll(where: { $0.id == theme.id })
            
            // If we removed the currently selected theme, select the first available
            if selectedTheme?.id == theme.id {
                selectedTheme = selectedThemes.first
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
        } else {
            dayTimePreferences[weekday, default: []].insert(timeOfDay)
        }
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    func handleButtonTap() {
        switch currentStage {
        case .name:
            if let template = selectedTemplate {
                // Prefill from template and go to duration
                applyTemplate(template)
                withAnimation {
                    currentStage = .duration
                }
            } else {
                // New goal: go to duration
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
        
        // Set theme based on template
        let matchedTheme = matchTheme(named: template.theme)
        selectedTheme = matchedTheme
        useCustomTheme = false
        
        // Add to selected themes if not already there
        if !selectedThemes.contains(where: { $0.id == matchedTheme.id }) {
            selectedThemes.append(matchedTheme)
        }
        
        // Show it as an AI suggestion for consistency
        aiSuggestedThemes = [matchedTheme]
        aiReasoning = template.subtitle
        
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
    
    /// Generate AI-powered theme suggestions based on the goal text
    func generateAISuggestions() async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run { isGeneratingSuggestions = false }
            return
        }
        
        await MainActor.run {
            isGeneratingSuggestions = true
        }
        
        do {
            let session = LanguageModelSession()
            
            // Get available theme names for the prompt
            let themeNames = themes.map { $0.title }.joined(separator: ", ")
            
            let prompt = """
            Analyze this goal activity: "\(userInput)"
            
            Suggest 2-3 most appropriate themes from this list: \(themeNames)
            
            Return themes that best match the activity type and vibe. For example:
            - "meditate" → Wellness themes (Mint, Lavender, Sky)
            - "run" → Fitness themes (Coral, Cherry, Tangerine)
            - "read" → Learning themes (Sky, Mint, Lilac)
            - "code" → Productivity themes (Sky, Mint)
            - "paint" → Creative themes (Lilac, Rose, Tangerine)
            
            Provide a brief reasoning explaining why these themes fit.
            """
            
            let response = try await session.respond(
                to: Prompt(prompt),
                generating: GoalThemeSuggestionsResponse.self,
                options: GenerationOptions(temperature: 0.3)
            )
            
            await MainActor.run {
                let suggestion = response.content
                
                // Match suggested theme names to actual Theme objects
                let matchedThemes = suggestion.suggestedThemes.compactMap { themeName in
                    matchTheme(named: themeName)
                }
                
                // Remove duplicates and limit to 3
                var uniqueThemes: [Theme] = []
                for theme in matchedThemes {
                    if !uniqueThemes.contains(where: { $0.id == theme.id }) {
                        uniqueThemes.append(theme)
                    }
                }
                
                self.aiSuggestedThemes = Array(uniqueThemes.prefix(3))
                self.aiReasoning = suggestion.reasoning
                
                // Add AI-suggested themes to selected themes
                for theme in uniqueThemes.prefix(3) {
                    if !selectedThemes.contains(where: { $0.id == theme.id }) {
                        selectedThemes.append(theme)
                    }
                }
                
                // Auto-select the first suggested theme if user hasn't picked one
                if !useCustomTheme, let firstTheme = uniqueThemes.first {
                    self.selectedTheme = firstTheme
                }
                
                isGeneratingSuggestions = false
                
                print("🎨 AI Theme Suggestions:")
                print("   Themes: \(uniqueThemes.map { $0.title }.joined(separator: ", "))")
                if let reasoning = suggestion.reasoning {
                    print("   Reasoning: \(reasoning)")
                }
            }
        } catch {
            await MainActor.run {
                isGeneratingSuggestions = false
                print("❌ Failed to generate AI theme suggestions: \(error)")
            }
        }
    }
    
    func saveGoal() {
        let goal: Goal
        let isEditing = existingGoal != nil
        
        // Determine theme based on user selection or suggestion
        let finalTheme: Theme
        if let customTheme = selectedTheme {
            // User has selected a theme (either custom or from AI suggestions)
            finalTheme = customTheme
        } else if let template = selectedTemplate {
            // Use the template's theme
            finalTheme = matchTheme(named: template.theme)
        } else if let selectedSuggestion, let themeNames = selectedSuggestion.themes, !themeNames.isEmpty {
            // Use the first theme from generated suggestions
            finalTheme = matchTheme(named: themeNames[0])
        } else {
            // Random fallback
            finalTheme = themes.randomElement() ?? themes[0]
        }
        
        let theme = GoalTheme(title: finalTheme.title, color: finalTheme)
        
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
            goal.primaryTheme = theme
            goal.weeklyTarget = TimeInterval(durationInMinutes * 60 * 7)
            goal.notificationsEnabled = notificationsEnabled
            goal.healthKitMetric = selectedHealthKitMetric
            goal.healthKitSyncEnabled = healthKitSyncEnabled
            
            // Clear existing schedule and set new one
            goal.dayTimeSchedule.removeAll()
        } else {
            // Create new goal
            if let selectedSuggestion, let title = selectedSuggestion.title {
                goal = Goal(
                    title: title,
                    primaryTheme: theme,
                    weeklyTarget: TimeInterval(durationInMinutes * 60 * 7), // Convert daily to weekly
                    notificationsEnabled: notificationsEnabled,
                    healthKitMetric: selectedHealthKitMetric,
                    healthKitSyncEnabled: healthKitSyncEnabled
                )
            } else {
                goal = Goal(
                    title: userInput,
                    primaryTheme: theme,
                    weeklyTarget: TimeInterval(durationInMinutes * 60 * 7), // Convert daily to weekly
                    notificationsEnabled: notificationsEnabled,
                    healthKitMetric: selectedHealthKitMetric,
                    healthKitSyncEnabled: healthKitSyncEnabled
                )
            }
        }
        
        // ✅ Save the day-time schedule using the convenience method
        for (weekday, times) in dayTimePreferences {
            goal.setTimes(times, forWeekday: weekday)
        }
        
        print("\n✅ Goal \(isEditing ? "updated" : "saved") with schedule:")
        print(goal.scheduleSummary)
        
        // Request notification permissions if enabled
        if notificationsEnabled {
            requestNotificationPermissions()
        }
        
        // Only insert if creating new goal
        if !isEditing {
            modelContext.insert(goal)
        }
        
        dismiss()
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func prewarm() {
//        session.prewarm()
    }
    
    /// Match a theme name to an actual Theme from the themes array
    func matchTheme(named themeName: String) -> Theme {
        let normalizedThemeName = themeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try exact match first
        if let exactMatch = themes.first(where: { $0.title.lowercased() == normalizedThemeName }) {
            return exactMatch
        }
        
        // Try partial match
        if let partialMatch = themes.first(where: { $0.title.lowercased().contains(normalizedThemeName) }) {
            return partialMatch
        }
        
        // Try reverse match (theme name contains the search term)
        if let reverseMatch = themes.first(where: { normalizedThemeName.contains($0.title.lowercased()) }) {
            return reverseMatch
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
            "fitness": "exercise",
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
                if let match = themes.first(where: { $0.id == themeId }) {
                    return match
                }
            }
        }
        
        // Default fallback - use "general" theme
        return themes.first(where: { $0.id == "general" }) ?? themes[0]
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
}
// MARK: - Category Suggestions View

struct CategorySuggestionsView: View {
    let category: GoalCategory
    @Binding var selectedTemplate: GoalTemplateSuggestion?
    @Binding var userInput: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestions List
            List {
                ForEach(category.suggestions) { suggestion in
                    SuggestionRow(
                        suggestion: suggestion,
                        isSelected: selectedTemplate?.id == suggestion.id,
                        categoryColor: category.colorValue
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
                .foregroundStyle(isSelected ? categoryColor : categoryColor.contrastingTextColor)
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
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? category.colorValue.contrastingTextColor : category.colorValue)
            
            Text(category.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? category.colorValue.contrastingTextColor : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isSelected ? category.colorValue : Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .strokeBorder(category.colorValue, lineWidth: isSelected ? 0 : 1.5)
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

struct TimeSlotButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                .frame(height: 44)
                .overlay(
                    Image(systemName: isSelected ? "checkmark" : "")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

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
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.light, theme.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? theme.dark : Color.clear, lineWidth: 2)
                    )
                
                Text(theme.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? theme.light.opacity(0.3) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? theme.dark : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? theme.dark : .primary)
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

// MARK: - Add Custom Theme Sheet

struct AddCustomThemeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var themeName: String
    var onSave: (String, Theme) -> Void
    
    @State private var selectedBaseTheme: Theme = themes[0]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Theme Name")) {
                    TextField("e.g., Morning Vibes", text: $themeName)
                }
                
                Section(header: Text("Base Color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(themes, id: \.id) { theme in
                                Button(action: {
                                    selectedBaseTheme = theme
                                    
                                    #if os(iOS)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    #endif
                                }) {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [theme.light, theme.dark],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(selectedBaseTheme.id == theme.id ? theme.dark : Color.clear, lineWidth: 3)
                                            )
                                        
                                        Text(theme.title)
                                            .font(.caption2)
                                            .foregroundStyle(selectedBaseTheme.id == theme.id ? .primary : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                Section {
                    HStack {
                        Text("Preview:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [selectedBaseTheme.light, selectedBaseTheme.dark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 24, height: 24)
                            
                            Text(themeName.isEmpty ? "My Theme" : themeName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(selectedBaseTheme.dark)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedBaseTheme.light.opacity(0.3))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedBaseTheme.dark, lineWidth: 2)
                        )
                    }
                }
            }
            .navigationTitle("Add Custom Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(name.isEmpty ? "My Theme" : name, selectedBaseTheme)
                        dismiss()
                    }
                }
            }
        }
    }
}

