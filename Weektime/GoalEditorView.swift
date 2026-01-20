import SwiftUI
import FoundationModels
import WeektimeKit
import SwiftData
import UserNotifications

// MARK: - AI Suggestion Model
@Generable
struct GoalSuggestionResponse: Codable {
    var suggestedDuration: Int // in minutes
    var suggestedTheme: String
    var suggestedHealthKitMetric: String? // raw value of HealthKitMetric
    var reasoning: String? // optional explanation
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
    @State private var aiSuggestion: GoalSuggestionResponse?
    @State private var suggestionsData: GoalSuggestionsData = GoalSuggestionsLoader.shared.loadSuggestions()
    @State private var selectedTemplate: GoalTemplateSuggestion?
    @State private var selectedCategoryIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy?
    
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
                            
                            // Skip suggestions while generating
                            if isGeneratingSuggestions {
                                Section {
                                    Button(role: .cancel) {
                                        // Cancel suggestion flow
                                        isGeneratingSuggestions = false
                                        aiSuggestion = nil
                                    } label: {
                                        HStack {
                                            Image(systemName: "forward.fill")
                                            Text("Skip suggestions")
                                        }
                                    }
                                }
                            }
                            
                            // Show AI suggestion reasoning if available
                            if let aiSuggestion, let reasoning = aiSuggestion.reasoning {
                                Section {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.purple)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("AI Suggestion")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.secondary)
                                            Text(reasoning)
                                                .font(.callout)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            Section(header: Text("Time of Day")) {
                                Menu {
                                    // Toggle choices
                                    ForEach(SimpleTimeOfDay.allCases) { option in
                                        Button {
                                            if selectedSimpleTimes.contains(option) {
                                                selectedSimpleTimes.remove(option)
                                            } else {
                                                selectedSimpleTimes.insert(option)
                                            }
                                        } label: {
                                            HStack {
                                                Text(option.rawValue)
                                                Spacer()
                                                if selectedSimpleTimes.contains(option) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                    Button {
                                        selectedSimpleTimes = Set(SimpleTimeOfDay.allCases)
                                    } label: {
                                        Label("Select All", systemImage: "checkmark.circle")
                                    }
                                    Button(role: .destructive) {
                                        selectedSimpleTimes.removeAll()
                                    } label: {
                                        Label("Clear All", systemImage: "xmark.circle")
                                    }
                                } label: {
                                    HStack {
                                        Text("Select")
                                        Spacer()
                                        let summary: String = {
                                            if selectedSimpleTimes.isEmpty { return "None" }
                                            // Show up to three selections, else count
                                            let names = selectedSimpleTimes.map { $0.rawValue }
                                            if names.count <= 3 {
                                                return names.sorted().joined(separator: ", ")
                                            } else {
                                                return "\(names.count) selected"
                                            }
                                        }()
                                        Text(summary)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text("Quickly choose when this goal is relevant. You can still fine-tune below.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Section(header: Text("Duration")) {
                                Picker("Duration (minutes)", selection: $durationInMinutes) {
                                    ForEach([5, 10, 15, 20, 30, 45, 60, 90], id: \.self) { minutes in
                                        Text("\(minutes) min").tag(minutes)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
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
            .navigationTitle(currentStage == .name ? "Goal Editor" : "Set Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if currentStage == .duration {
                            // Go back to name stage
                            withAnimation {
                                currentStage = .name
                            }
                        } else {
                            // Dismiss the view
                            dismiss()
                        }
                    } label: {
                        Image(systemName: currentStage == .name ? "xmark" : "chevron.left")
                    }

                }
                // Removed the trailing toolbar button since we have the bottom button now
            }
        }
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
        .task {
            prewarm()
            if userInput.isEmpty {
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
                Task { await generateAISuggestions() }
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
        
        // Set HealthKit metric if available
        if let metricRawValue = template.healthKitMetric,
           let metric = HealthKitMetric(rawValue: metricRawValue) {
            selectedHealthKitMetric = metric
            healthKitSyncEnabled = true
        } else {
            selectedHealthKitMetric = nil
            healthKitSyncEnabled = false
        }
        
        // Create AI suggestion for display
        aiSuggestion = GoalSuggestionResponse(
            suggestedDuration: template.duration,
            suggestedTheme: template.theme,
            suggestedHealthKitMetric: template.healthKitMetric,
            reasoning: template.subtitle
        )
        
        print("✨ Template Applied:")
        print("   Title: \(template.title)")
        print("   Duration: \(template.duration) min")
        print("   Theme: \(template.theme)")
        print("   HealthKit: \(template.healthKitMetric ?? "none")")
    }
    
    /// Generate AI-powered suggestions for duration, theme, and HealthKit metric
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
            
            let prompt = """
            Analyze this goal activity: "\(userInput)"
            
            Provide smart suggestions for:
            1. Duration: Recommended daily duration in minutes (between 5 and 90)
            2. Theme: A theme category (e.g., "Wellness", "Learning", "Fitness", "Creative", "Productivity")
            3. HealthKit Metric: If applicable, suggest one of these HealthKit metrics:
               - "apple_exercise_time" for workouts, running, cardio, sports
               - "mindful_minutes" for meditation, mindfulness, breathing exercises, journaling
               - null if no HealthKit metric applies
            4. Reasoning: Brief explanation of your suggestions (optional)
            
            Examples:
            - "meditate" → duration: 10, theme: "Wellness", healthKitMetric: "mindful_minutes"
            - "run" → duration: 25, theme: "Fitness", healthKitMetric: "apple_exercise_time"
            - "read" → duration: 30, theme: "Learning", healthKitMetric: null
            - "journal" → duration: 15, theme: "Wellness", healthKitMetric: "mindful_minutes"
            """
            
            let response = try await session.respond(
                to: Prompt(prompt),
                generating: GoalSuggestionResponse.self,
                options: GenerationOptions(temperature: 0.3)
            )
            
            await MainActor.run {
                let suggestion = response.content
                self.aiSuggestion = suggestion
                
                // Apply suggestions
                self.durationInMinutes = suggestion.suggestedDuration
                
                // Try to match HealthKit metric
                if let metricRawValue = suggestion.suggestedHealthKitMetric,
                   let metric = HealthKitMetric(rawValue: metricRawValue) {
                    self.selectedHealthKitMetric = metric
                    self.healthKitSyncEnabled = true
                }
                
                isGeneratingSuggestions = false
                
                print("🤖 AI Suggestions:")
                print("   Duration: \(suggestion.suggestedDuration) min")
                print("   Theme: \(suggestion.suggestedTheme)")
                print("   HealthKit: \(suggestion.suggestedHealthKitMetric ?? "none")")
                if let reasoning = suggestion.reasoning {
                    print("   Reasoning: \(reasoning)")
                }
            }
        } catch {
            await MainActor.run {
                isGeneratingSuggestions = false
                print("❌ Failed to generate AI suggestions: \(error)")
            }
        }
    }
    
    func saveGoal() {
        let goal: Goal
        
        // Determine theme title
        let themeTitle: String
        if let aiSuggestion {
            themeTitle = aiSuggestion.suggestedTheme
        } else if let selectedSuggestion, let themes = selectedSuggestion.themes, !themes.isEmpty {
            themeTitle = themes[0]
        } else {
            themeTitle = ""
        }
        
        let theme = GoalTheme(title: themeTitle, color: themes.randomElement()!)
        
        // Convert time of day selections to strings for storage
        let timePreferences = selectedSimpleTimes.map { $0.rawValue.lowercased() }
        
        if !selectedSimpleTimes.isEmpty {
            print("Simple Time of Day:", selectedSimpleTimes.map { $0.rawValue }.sorted().joined(separator: ", "))
        }
      
        if let selectedSuggestion, let title = selectedSuggestion.title {
            goal = Goal(
                title: title,
                primaryTheme: theme,
                weeklyTarget: TimeInterval(durationInMinutes * 60 * 7), // Convert daily to weekly
                notificationsEnabled: notificationsEnabled,
                healthKitMetric: selectedHealthKitMetric,
                healthKitSyncEnabled: healthKitSyncEnabled
            )
            goal.preferredTimesOfDay = timePreferences
        } else {
            goal = Goal(
                title: userInput,
                primaryTheme: theme,
                weeklyTarget: TimeInterval(durationInMinutes * 60 * 7), // Convert daily to weekly
                notificationsEnabled: notificationsEnabled,
                healthKitMetric: selectedHealthKitMetric,
                healthKitSyncEnabled: healthKitSyncEnabled
            )
            goal.preferredTimesOfDay = timePreferences
        }
        
        // TODO: Persist scheduling to the Goal model when supported
        // Debug print for current schedule
        let calendar = Calendar.current
        for weekday in 1...7 {
            if let sched = weeklySchedule[weekday], sched.enabled {
                let comps = calendar.dateComponents([.hour, .minute], from: sched.time)
                print("Schedule for weekday \(weekday): \(sched.relation.rawValue) \(String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0))")
            }
        }
        
        // Request notification permissions if enabled
        if notificationsEnabled {
            requestNotificationPermissions()
        }
        
        modelContext.insert(goal)
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
//        let stream = try await session.streamResponse(
//            to: Prompt("Come up with up to three separate goals for the user to add based on their input, including how long to spend on each goal. Return the goals as a list of dictionaries with the short title and duration (no more than 30 minutes) in the separate property, not the title. Be specific, e.g. 'Cardio' instea of 'Exercise routine'. Include things like gardening, reading a book, or learning a new skill, playing a musical instrument."),
//            generating: GoalEditorSuggestionsResult.self,
//            includeSchemaInPrompt: false,
//            options: GenerationOptions(temperature: 0.5)
//        )
        
//        for try await partialResponse in stream {
//            result = partialResponse
//        }

//        return goalsResult.content

//        let session = LanguageModelSession()
//
//        let stream = try await session.streamResponse(
//            generating: [GoalSugg].self,
//            options: GenerationOptions(),
//            includeSchemaInPrompt: false
//        ) {
//            "Please generate a report about SwiftUI views."
//        }
//
//        for try await partial in stream {
//            // `partial` is a MyStruct.PartiallyGenerated
//            updateUI(with: partial)
//        }
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


