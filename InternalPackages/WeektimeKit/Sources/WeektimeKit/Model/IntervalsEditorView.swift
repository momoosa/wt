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
        let sortedIntervals = goal.intervals.sorted(by: { $0.orderIndex < $1.orderIndex })
        for offset in offsets {
            let interval = sortedIntervals[offset]
            goal.intervals.removeAll(where: { $0.id == interval.id })
            modelContext.delete(interval)
        }
        reindexIntervals()
        try? modelContext.save()
    }

    private func moveIntervals(from source: IndexSet, to destination: Int) {
        var sortedIntervals = goal.intervals.sorted(by: { $0.orderIndex < $1.orderIndex })
        sortedIntervals.move(fromOffsets: source, toOffset: destination)

        goal.intervals.removeAll()
        for interval in sortedIntervals {
            goal.intervals.append(interval)
        }
        reindexIntervals()
        try? modelContext.save()
    }

    private func addInterval(kind: Interval.Kind) {
        let nameToUse = intervalName.isEmpty ? "Interval \(goal.intervals.count + 1)" : intervalName
        let newInterval = Interval(name: nameToUse, durationSeconds: 10, orderIndex: goal.intervals.count, kind: kind)
        newInterval.goal = goal

        goal.intervals.append(newInterval)
        modelContext.insert(newInterval)

        // If a current goal session is active, also create a matching IntervalSession
        if let session = currentSession {
            // Create an IntervalSession associated to this new interval and goal session
            let newIntervalSession = IntervalSession(interval: newInterval, session: session)
            // If your IntervalSession needs order or duration mirroring, set them here
            modelContext.insert(newIntervalSession)
        }

        try? modelContext.save()
        intervalName = ""
    }

    private func reindexIntervals() {
        let sorted = goal.intervals.sorted(by: { $0.orderIndex < $1.orderIndex })
        for (index, interval) in sorted.enumerated() {
            interval.orderIndex = index
        }
    }

    private func generateIntervalsAndSessions() {
        // Remove existing intervals for a clean regeneration
        let existing = goal.intervals
        for interval in existing {
            modelContext.delete(interval)
        }
        goal.intervals.removeAll()

        var order = 0
        func makeInterval(name: String, seconds: Int, kind: Interval.Kind) {
            guard seconds > 0 else { return }
            let interval = Interval(name: name, durationSeconds: seconds, orderIndex: order, goal: goal, kind: kind)
            interval.goal = goal
            goal.intervals.append(interval)
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
