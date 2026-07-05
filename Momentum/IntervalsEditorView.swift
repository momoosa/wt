import SwiftUI
import SwiftData
import MomentumKit

/// Represents an editable interval row in the editor
struct EditableInterval: Identifiable {
    let id = UUID()
    var name: String = ""
    var durationSeconds: Int = 30
}

public struct IntervalsEditorView: View {
    @Bindable var list: IntervalList
    let session: IntervalListSession?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var intervals: [EditableInterval] = [EditableInterval()]
    @State private var restBetweenSeconds: Int = 15
    @State private var draggingIntervalID: UUID?
    @FocusState private var focusedIntervalID: UUID?

    public init(list: IntervalList) {
        self.list = list
        self.session = nil
    }
    
    public init(list: IntervalList, goalSession: GoalSession) {
        self.list = list
        let session = IntervalListSession(list: list, goal: goalSession)
        self.session = session
    }
    
    public init(list: IntervalList, session: IntervalListSession) {
        self.list = list
        self.session = session
    }

    // MARK: - Computed

    private var totalMovingTime: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }

    private var totalTime: Int {
        let restCount = max(intervals.count - 1, 0)
        return totalMovingTime + restCount * restBetweenSeconds
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    headerCard

                    // Interval rows
                    VStack(spacing: 0) {
                        ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                            intervalRow(index: index, interval: interval)
                                .draggable(interval.id.uuidString) {
                                    // Drag preview
                                    intervalRow(index: index, interval: interval)
                                        .frame(width: 340)
                                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                                        .shadow(radius: 4)
                                        .onAppear { draggingIntervalID = interval.id }
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    guard let draggedID = items.first,
                                          let draggedUUID = UUID(uuidString: draggedID),
                                          let fromIndex = intervals.firstIndex(where: { $0.id == draggedUUID }),
                                          let toIndex = intervals.firstIndex(where: { $0.id == interval.id }),
                                          fromIndex != toIndex else {
                                        draggingIntervalID = nil
                                        return false
                                    }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        intervals.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                                    }
                                    draggingIntervalID = nil
                                    return true
                                }
                                .opacity(draggingIntervalID == interval.id ? 0.4 : 1.0)
                            
                            if index < intervals.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Add button
                    Button {
                        withAnimation {
                            let newInterval = EditableInterval()
                            intervals.append(newInterval)
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                focusedIntervalID = newInterval.id
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add a stretch")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Rest between
                    restBetweenRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        generateIntervalsAndSessions()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadExistingIntervals()
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INTERVAL SESSION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            TextField("Routine Name", text: $list.name)
                .font(.title2.bold())
                .textInputAutocapitalization(.words)
            
            HStack(spacing: 4) {
                Text("\(intervals.count) stretches")
                Text("·")
                Text("\(formatDuration(totalMovingTime)) moving")
                Text("·")
                Text("\(formatDuration(totalTime)) total")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.mint.opacity(colorScheme == .dark ? 0.25 : 0.15),
                    Color.green.opacity(colorScheme == .dark ? 0.15 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - Interval Row

    private func intervalRow(index: Int, interval: EditableInterval) -> some View {
        HStack(spacing: 12) {
            // Reorder buttons
            VStack(spacing: 0) {
                Button {
                    guard index > 0 else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        intervals.swapAt(index, index - 1)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index > 0 ? .secondary : .quaternary)
                        .frame(width: 28, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                
                Button {
                    guard index < intervals.count - 1 else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        intervals.swapAt(index, index + 1)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index < intervals.count - 1 ? .secondary : .quaternary)
                        .frame(width: 28, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index >= intervals.count - 1)
            }
            
            Text("\(index + 1)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            // Name and duration
            VStack(alignment: .leading, spacing: 2) {
                if let binding = bindingForInterval(id: interval.id) {
                    TextField("Interval name", text: binding.name)
                        .font(.subheadline.weight(.medium))
                        .focused($focusedIntervalID, equals: interval.id)
                        .submitLabel(.done)
                    
                    Text(formatTimestamp(binding.durationSeconds.wrappedValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
            
            // Duration stepper (compact)
            if let binding = bindingForInterval(id: interval.id) {
                HStack(spacing: 4) {
                    Button {
                        binding.durationSeconds.wrappedValue = max(binding.durationSeconds.wrappedValue - 15, 5)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Text(formatTimestamp(binding.durationSeconds.wrappedValue))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .frame(width: 44)
                    
                    Button {
                        binding.durationSeconds.wrappedValue = min(binding.durationSeconds.wrappedValue + 15, 3600)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Delete
            Button {
                withAnimation {
                    intervals.removeAll { $0.id == interval.id }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Rest Between

    private var restBetweenRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest between")
                    .font(.subheadline.weight(.medium))
                Text("A \"get ready\" gap before each next stretch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button {
                    restBetweenSeconds = max(restBetweenSeconds - 5, 0)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                
                Text(formatTimestamp(restBetweenSeconds))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
                
                Button {
                    restBetweenSeconds = min(restBetweenSeconds + 5, 300)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func bindingForInterval(id: UUID) -> Binding<EditableInterval>? {
        guard let index = intervals.firstIndex(where: { $0.id == id }) else { return nil }
        return $intervals[index]
    }

    private func formatDuration(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        if min > 0 && sec > 0 {
            return "\(min) min \(sec)s"
        } else if min > 0 {
            return "\(min) min"
        } else {
            return "\(sec)s"
        }
    }

    private func formatTimestamp(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d", min, sec)
    }

    // MARK: - Load Existing

    private func loadExistingIntervals() {
        guard let existing = list.intervals, !existing.isEmpty else { return }
        
        let sorted = existing.sorted { $0.orderIndex < $1.orderIndex }
        
        // Extract rest duration from the first break interval (if any)
        if let firstBreak = sorted.first(where: { $0.kind == .breakTime }) {
            restBetweenSeconds = firstBreak.durationSeconds
        }
        
        // Load only work intervals as editable rows
        intervals = sorted
            .filter { $0.kind == .work }
            .map { EditableInterval(name: $0.name, durationSeconds: $0.durationSeconds) }
        
        if intervals.isEmpty {
            intervals = [EditableInterval()]
        }
    }

    // MARK: - Save

    private func generateIntervalsAndSessions() {
        // Clear existing intervals from the list
        if let existing = list.intervals {
            for interval in existing {
                modelContext.delete(interval)
            }
        }
        list.intervals?.removeAll()
        
        // Clear existing interval sessions if they exist
        if let session = session {
            if let sessionIntervals = session.intervals {
                for intervalSession in sessionIntervals {
                    modelContext.delete(intervalSession)
                }
            }
            session.intervals?.removeAll()
        }
        
        var order = 0
        func makeInterval(name: String, seconds: Int, kind: Interval.Kind) {
            guard seconds > 0 else { return }
            
            let interval = Interval(name: name, durationSeconds: seconds, orderIndex: order, list: list, kind: kind)
            if list.intervals == nil {
                list.intervals = []
            }
            list.intervals?.append(interval)
            modelContext.insert(interval)
            
            if let session = session {
                let intervalSession = IntervalSession(interval: interval)
                if session.intervals == nil {
                    session.intervals = []
                }
                session.intervals?.append(intervalSession)
                modelContext.insert(intervalSession)
            }
            order += 1
        }

        // Generate intervals with rest between each
        for (index, editable) in intervals.enumerated() {
            let name = editable.name.isEmpty ? "Interval \(index + 1)" : editable.name
            
            // Add rest before this interval (except the first one)
            if index > 0 && restBetweenSeconds > 0 {
                makeInterval(name: "Rest", seconds: restBetweenSeconds, kind: .breakTime)
            }
            
            makeInterval(name: name, seconds: editable.durationSeconds, kind: .work)
        }

        modelContext.safeSave()
    }
}

#Preview {
    IntervalsEditorView(list: IntervalList(name: "Morning Mobility"))
        .modelContainer(for: IntervalList.self, inMemory: true)
}
