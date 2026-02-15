import SwiftUI
import SwiftData

/// Represents a group of intervals (e.g., "4x Heel Stretch, 30s work, 10s break")
struct IntervalGroup: Identifiable {
    let id = UUID()
    var name: String = ""
    var workSeconds: Int = 30
    var breakSeconds: Int = 10
    var repeatCount: Int = 1
}

public struct IntervalsEditorView: View {
    @Bindable var list: IntervalList
    let session: IntervalListSession?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var warmupSeconds: Int = 0
    @State private var intervalGroups: [IntervalGroup] = [IntervalGroup()]
    @FocusState private var focusedGroupID: UUID?

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
                Section {
                    TextField("List Name (e.g., Foot Stretches)", text: $list.name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                } header: {
                    Text("List Info")
                }
                
                Section {
                    HStack {
                        Text("Warmup Duration")
                        Spacer()
                        Stepper(value: $warmupSeconds, in: 0...3600) {
                            Text("\(warmupSeconds)s").monospacedDigit()
                        }
                    }
                } header: {
                    Text("Warmup (Optional)")
                }

                ForEach($intervalGroups) { $group in
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Exercise Name")
                                Spacer()
                                TextField("e.g., Heel Stretch", text: $group.name)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(false)
                                    .focused($focusedGroupID, equals: group.id)
                                    .submitLabel(.done)
                                    .multilineTextAlignment(.trailing)
                            }
                            HStack {
                                Text("Work Duration")
                                Spacer()
                                Stepper(value: $group.workSeconds, in: 1...3600) {
                                    Text("\(group.workSeconds)s").monospacedDigit()
                                }
                            }
                            HStack {
                                Text("Break Duration")
                                Spacer()
                                Stepper(value: $group.breakSeconds, in: 0...3600) {
                                    Text("\(group.breakSeconds)s").monospacedDigit()
                                }
                            }
                            HStack {
                                Text("Repetitions")
                                Spacer()
                                Stepper(value: $group.repeatCount, in: 1...200) {
                                    Text("\(group.repeatCount)").monospacedDigit()
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Exercise \(intervalGroupIndex(group) + 1)")
                            Spacer()
                            if intervalGroups.count > 1 {
                                Button(role: .destructive) {
                                    withAnimation {
                                        intervalGroups.removeAll { $0.id == group.id }
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        if let index = intervalGroups.firstIndex(where: { $0.id == group.id }),
                           index == intervalGroups.count - 1 {
                            Button {
                                withAnimation {
                                    let newGroup = IntervalGroup()
                                    intervalGroups.append(newGroup)
                                    // Focus the new group's text field after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        focusedGroupID = newGroup.id
                                    }
                                }
                            } label: {
                                Label("Add Another Interval", systemImage: "plus.circle.fill")
                            }
                        }
                    }
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
        // Clear existing intervals from the list
        for interval in list.intervals {
            modelContext.delete(interval)
        }
        list.intervals.removeAll()
        
        // Clear existing interval sessions if they exist
        if let session = session {
            for intervalSession in session.intervals {
                modelContext.delete(intervalSession)
            }
            session.intervals.removeAll()
        }
        
        var order = 0
        func makeInterval(name: String, seconds: Int, kind: Interval.Kind) {
            guard seconds > 0 else { return }
            
            let interval = Interval(name: name, durationSeconds: seconds, orderIndex: order, list: list, kind: kind)
            list.intervals.append(interval)
            modelContext.insert(interval)
            
            if let session = session {
                let intervalSession = IntervalSession(interval: interval)
                session.intervals.append(intervalSession)
                modelContext.insert(intervalSession)
            }
            order += 1
        }

        // Add warmup if specified
        if warmupSeconds > 0 {
            makeInterval(name: "Warmup", seconds: warmupSeconds, kind: .work)
        }

        // Add work/break intervals for each group
        for group in intervalGroups {
            for i in 1...group.repeatCount {
                let workName = group.name.isEmpty ? "Exercise" : group.name
                makeInterval(name: "\(workName) \(i)", seconds: group.workSeconds, kind: .work)
                if group.breakSeconds > 0 {
                    makeInterval(name: "Break \(i)", seconds: group.breakSeconds, kind: .breakTime)
                }
            }
        }

        try? modelContext.save()
    }
    
    private func intervalGroupIndex(_ group: IntervalGroup) -> Int {
        intervalGroups.firstIndex(where: { $0.id == group.id }) ?? 0
    }
}
