import SwiftUI
import SwiftData

public struct IntervalsEditorView: View {
    @Bindable var goal: Goal
    var currentSession: GoalSession?

    @Environment(\.modelContext) private var modelContext

    public init(goal: Goal, currentSession: GoalSession? = nil) {
        self._goal = Bindable(wrappedValue: goal)
        self.currentSession = currentSession
    }

    public var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(goal.intervals.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.self) { interval in
                        HStack {
                            TextField("Interval Name", text: Binding(
                                get: { interval.name },
                                set: { newValue in
                                    interval.name = newValue
                                    try? modelContext.save()
                                }
                            ))
                            Spacer()
                            Stepper(value: Binding(
                                get: { interval.durationSeconds },
                                set: { newValue in
                                    interval.durationSeconds = max(1, newValue)
                                    try? modelContext.save()
                                }
                            ), in: 1...Int.max) {
                                Text("\(interval.durationSeconds)s")
                                    .monospacedDigit()
                            }
                            Spacer()
                            Text("#\(interval.orderIndex)")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteIntervals)
                    .onMove(perform: moveIntervals)
                }
                .listStyle(.insetGrouped)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .none) {
                        addInterval()
                    } label: {
                        Label("Add Interval", systemImage: "plus")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                ToolbarSpacer(placement: .bottomBar)                
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

    private func addInterval() {
        let newInterval = Interval(name: "Interval \(goal.intervals.count + 1)", durationSeconds: 10, orderIndex: goal.intervals.count)
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
    }

    private func reindexIntervals() {
        let sorted = goal.intervals.sorted(by: { $0.orderIndex < $1.orderIndex })
        for (index, interval) in sorted.enumerated() {
            interval.orderIndex = index
        }
    }
}

