import SwiftUI
import FoundationModels
import WeektimeKit
import SwiftData
import UserNotifications

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
                        Section(header: Text("Duration")) {
                            Picker("Duration (minutes)", selection: $durationInMinutes) {
                                ForEach([5, 10, 15, 20, 30, 45, 60, 90], id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        
                        Section(header: Text("Notifications")) {
                            Toggle("Notify when target is reached", isOn: $notificationsEnabled)
                        }
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
                        Text(currentStage == .name ? "Next" : "Save")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonEnabled ? Color.accentColor : Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!buttonEnabled)
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
            withAnimation {
                currentStage = .duration
            }
        case .duration:
            saveGoal()
        }
    }
    
    func saveGoal() {
        let goal: Goal
        if let selectedSuggestion, let title = selectedSuggestion.title {
            let newItem = GoalTheme(title: selectedSuggestion.themes![0], color: themes.randomElement()!)
            goal = Goal(title: title, primaryTheme: newItem, weeklyTarget: TimeInterval(durationInMinutes * 60), notificationsEnabled: notificationsEnabled)
        } else {
            goal = Goal(title: userInput, primaryTheme: GoalTheme(title: "", color: themes.randomElement()!), weeklyTarget: TimeInterval(durationInMinutes * 60), notificationsEnabled: notificationsEnabled)
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
