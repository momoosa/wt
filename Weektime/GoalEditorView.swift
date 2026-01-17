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
    
    enum EditorStage {
        case name
        case duration
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section(header: Text("Describe your goal")) {
                        TextField("What do you want to do?", text: $userInput)
                    }
                    
                    if currentStage == .duration {
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

//                Section {
//                    if session.isResponding {
//                        ProgressView("Generating suggestions...")
//                    } else if let errorMessage {
//                        Text(errorMessage).foregroundStyle(.red)
//                    } else if let suggestions = result?.suggestions {
//                        if suggestions.isEmpty {
//                            
//                        } else {
//                            ForEach(suggestions.prefix(5)) { task in
//                                VStack(alignment: .leading) {
//                                    if let title = task.title {
//                                        Text(title)
//                                    }
//                                    HStack {
//                                        if let subtitle = task.subtitle {
//                                            Text(subtitle)
//                                        } else {
//                                            Text("")
//                                        }
//                                    }
//                                    .font(.footnote)
//                                    
//                                    if let themes = task.themes, !themes.isEmpty {
//                                        HStack {
//                                            ForEach(themes, id: \.self) { theme in
//                                                Text(theme)
//                                                    .padding(2)
//                                                    .background(Capsule()
//                                                        .fill(Color(.tertiarySystemBackground)))
//                                            }
//                                        }
//                                        .font(.footnote)
//
//                                    }
//                                }
//                                .listRowBackground(task.id == selectedSuggestion?.id ? Color.green.opacity(0.3) : Color(.systemBackground))
////                                .listRowBackground(task.id == selectedSuggestion.id ? Color.green : Color.clear)
//                                .onTapGesture {
//                                    selectedSuggestion = task
//                                }
//                            }
//                        }
//                    }
//                } header: {
//                    if session.isResponding {
//                        Text("Loading suggestions")
//                    } else {
//                        Text("Suggestions")
//                    }
//                }
//                Button("Generate Tasks") {
//                    generateChecklist(for: userInput)
//                }
//                .disabled(session.isResponding)
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
                        .background(buttonEnabled && !isGeneratingSuggestions ? Color.accentColor : Color.gray)
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
            return !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .duration:
            return true
        }
    }
    
    func handleButtonTap() {
        switch currentStage {
        case .name:
            // Generate AI suggestions before moving to duration stage
            Task {
                await generateAISuggestions()
                await MainActor.run {
                    withAnimation {
                        currentStage = .duration
                    }
                }
            }
        case .duration:
            saveGoal()
        }
    }
    
    /// Generate AI-powered suggestions for duration, theme, and HealthKit metric
    func generateAISuggestions() async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
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
