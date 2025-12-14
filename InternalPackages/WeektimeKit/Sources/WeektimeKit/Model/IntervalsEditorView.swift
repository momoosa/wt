import SwiftUI
import SwiftData

public struct IntervalsEditorView: View {
    @Bindable var list: IntervalList
    let session: IntervalListSession?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var warmupSeconds: Int = 0
    @State private var workSeconds: Int = 30
    @State private var breakSeconds: Int = 10
    @State private var repeatCount: Int = 1

    @State private var intervalName: String = ""
    @FocusState private var nameFieldFocused: Bool

    public init(list: IntervalList, goalSession: GoalSession) {
        self.list = list
        let session = IntervalListSession(list: list, goal: goalSession)
        self.session = session
    }
    
    public init(list: IntervalList, session: IntervalListSession) {
        self.list = list
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            List {
                
                TextField("Name", text: $list.name)

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Name", text: $intervalName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(false)
                                .focused($nameFieldFocused)
                                .submitLabel(.done)
                            HStack {
                                Text("Warmup")
                                Spacer()
                                Stepper(value: $warmupSeconds, in: 0...3600) {
                                    Text("\(warmupSeconds)s").monospacedDigit()
                                }
                            }
                            HStack {
                                Text("Work")
                                Spacer()
                                Stepper(value: $workSeconds, in: 1...3600) {
                                    Text("\(workSeconds)s").monospacedDigit()
                                }
                            }
                            HStack {
                                Text("Break")
                                Spacer()
                                Stepper(value: $breakSeconds, in: 0...3600) {
                                    Text("\(breakSeconds)s").monospacedDigit()
                                }
                            }
                            HStack {
                                Text("Repeats")
                                Spacer()
                                Stepper(value: $repeatCount, in: 1...200) {
                                    Text("\(repeatCount)").monospacedDigit()
                                }
                            }
                        }

                    } header: {
                        Text("Test") // TODO:
                    }

            }
            .task {
                await MainActor.run {
                    nameFieldFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        generateIntervalsAndSessions() // TODO:
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Intervals")
        }
    }



    private func generateIntervalsAndSessions() {
        // Remove existing intervals for a clean regeneration
        var order = 0
        func makeInterval(name: String, seconds: Int, kind: Interval.Kind, list: IntervalList?, session: IntervalListSession?) {
            guard seconds > 0 else { return }
            let list = IntervalList(name: "test")
            modelContext.insert(list)
            
            let interval = Interval(name: name, durationSeconds: seconds, orderIndex: order, list: list, kind: kind)
            interval.list = list
            modelContext.insert(interval)
            if let session {
                let intervalSession = IntervalSession(interval: interval)
                session.intervals.append(intervalSession)
                modelContext.insert(intervalSession)
            }
            order += 1
        }

        if warmupSeconds > 0 { // TODO:
            makeInterval(name: "Warmup", seconds: warmupSeconds, kind: .work, list: list, session: session)
        }

        // TODO: 
        for i in 1...repeatCount {
            makeInterval(name: intervalName.isEmpty ? "Work \(i)" : intervalName, seconds: workSeconds, kind: .work, list: list, session: session)
            if breakSeconds > 0 {
                makeInterval(name: "Break \(i)", seconds: breakSeconds, kind: .breakTime, list: list, session: session)
            }
        }

        try? modelContext.save()
        intervalName = ""
    }
}
