import SwiftUI
import SwiftData

public struct IntervalsEditorView: View {
    @Bindable var goal: Goal
    var currentSession: GoalSession?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var warmupSeconds: Int = 0
    @State private var workSeconds: Int = 30
    @State private var breakSeconds: Int = 10
    @State private var repeatCount: Int = 1

    @State private var intervalName: String = ""
    @FocusState private var nameFieldFocused: Bool

    public init(goal: Goal, currentSession: GoalSession? = nil) {
        self._goal = Bindable(wrappedValue: goal)
        self.currentSession = currentSession
    }

    public var body: some View {
        NavigationStack {
            VStack {
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
                .padding([.horizontal, .top])
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
                        generateIntervalsAndSessions()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Intervals")
        }
    }

    private func deleteIntervals(at offsets: IndexSet) {
        let sortedIntervals = goal.intervalLists.sorted(by: { $0.orderIndex < $1.orderIndex })
        for offset in offsets {
            let interval = sortedIntervals[offset]
            goal.intervalLists.removeAll(where: { $0.id == interval.id })
            modelContext.delete(interval)
        }
        reindexIntervals()
        try? modelContext.save()
    }

    private func moveIntervals(from source: IndexSet, to destination: Int) {
        var sortedIntervals = goal.intervalLists.sorted(by: { $0.orderIndex < $1.orderIndex })
        sortedIntervals.move(fromOffsets: source, toOffset: destination)

        goal.intervalLists.removeAll()
        for interval in sortedIntervals {
            goal.intervalLists.append(interval)
        }
        reindexIntervals()
        try? modelContext.save()
    }

    private func reindexIntervals() {
        let sorted = goal.intervalLists.sorted(by: { $0.orderIndex < $1.orderIndex })
        for (index, interval) in sorted.enumerated() {
            interval.orderIndex = index
        }
    }

    private func generateIntervalsAndSessions() {
        // Remove existing intervals for a clean regeneration
        let existing = goal.intervalLists
        for interval in existing {
            modelContext.delete(interval)
        }
        goal.intervalLists.removeAll()

        var order = 0
        func makeInterval(name: String, seconds: Int, kind: Interval.Kind) {
            guard seconds > 0 else { return }
            let list = IntervalList(name: "test")
            list.goal = goal
            modelContext.insert(list)
            
            let interval = Interval(name: name, durationSeconds: seconds, orderIndex: order, list: list, kind: kind)
            interval.list = list
            goal.intervalLists.append(list)
            modelContext.insert(interval)

            if let session = currentSession {
                let sessionItem = IntervalSession(interval: interval, session: session)
                modelContext.insert(sessionItem)
            }
            order += 1
        }

        if warmupSeconds > 0 { 
            makeInterval(name: "Warmup", seconds: warmupSeconds, kind: .work)
        }

        for i in 1...repeatCount {
            makeInterval(name: intervalName.isEmpty ? "Work \(i)" : intervalName, seconds: workSeconds, kind: .work)
            if breakSeconds > 0 {
                makeInterval(name: "Break \(i)", seconds: breakSeconds, kind: .breakTime)
            }
        }

        reindexIntervals()
        try? modelContext.save()
        intervalName = ""
    }
}
