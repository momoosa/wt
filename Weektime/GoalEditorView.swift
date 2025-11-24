import SwiftUI
import FoundationModels
import WeektimeKit
import SwiftData

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var userInput: String = ""
    @State private var result: GoalEditorSuggestionsResult.PartiallyGenerated?
    @State private var errorMessage: String?
    @State private var session = LanguageModelSession(instructions: "Come up with up to three separate goals for the user to add based on their input, including how long to spend on each goal. Return the goals as a list of dictionaries with the title + duration.")
    @State var selectedSuggestion: GoalSuggestion.PartiallyGenerated?
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Describe your goal")) {
                    TextField("What do you want to do?", text: $userInput)
                }
                
            

                Section {
                    if session.isResponding {
                        ProgressView("Generating suggestions...")
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if let suggestions = result?.suggestions {
                        if suggestions.isEmpty {
                            
                        } else {
                            ForEach(suggestions.prefix(5)) { task in
                                VStack(alignment: .leading) {
                                    if let title = task.title {
                                        Text(title)
                                    }
                                    HStack {
                                        if let subtitle = task.subtitle {
                                            Text(subtitle)
                                        } else {
                                            Text("")
                                        }
                                    }
                                    .font(.footnote)
                                    
                                    if let themes = task.themes, !themes.isEmpty {
                                        HStack {
                                            ForEach(themes, id: \.self) { theme in
                                                Text(theme)
                                                    .padding(2)
                                                    .background(Capsule()
                                                        .fill(Color(.tertiarySystemBackground)))
                                            }
                                        }
                                        .font(.footnote)

                                    }
                                }
                                .listRowBackground(task.id == selectedSuggestion?.id ? Color.green.opacity(0.3) : Color(.systemBackground))
//                                .listRowBackground(task.id == selectedSuggestion.id ? Color.green : Color.clear)
                                .onTapGesture {
                                    selectedSuggestion = task
                                }
                            }
                        }
                    }
                } header: {
                    if session.isResponding {
                        Text("Loading suggestions")
                    } else {
                        Text("Suggestions")
                    }
                }
                Button("Generate Tasks") {
                    generateChecklist(for: userInput)
                }
                .disabled(session.isResponding)
            }
            .animation(.spring(), value: result)
            .navigationTitle("Goal Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }

                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let goal: Goal
                        if let selectedSuggestion, let title = selectedSuggestion.title {
                            let newItem = GoalTheme(title: selectedSuggestion.themes![0], color: themes.randomElement()! ) // TOOD:
                            goal = Goal(title: title, primaryTheme: newItem)

                        } else {
                            goal = Goal(title: userInput, primaryTheme: GoalTheme(title: "", color: themes.randomElement()!))
                        }
                        modelContext.insert(goal)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
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

    func prewarm() {
//        session.prewarm()
    }
    
    func generateChecklist(for input: String) {
        return
        errorMessage = nil
//        result = []

        Task {
            do {
                // Replace this part with proper FoundationModels API usage as needed
                // This is a placeholder showing where you would use your LLM
//                let response = try await generateTasksWithLLM(prompt: input)
                
                try await generateStreamedSuggestions()
                await MainActor.run {
//                    self.result = response.asPartiallyGenerated()
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
            result = partialResponse.content
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
