import SwiftUI
import SwiftData
import WeektimeKit

struct ChecklistDetailView: View {
    var session: GoalSession
    @Environment(\.editMode) private var editMode
    @Environment(\.modelContext) private var context
    var animation: Namespace.ID
    let historicalSessionLimit = 3
    @State var isShowingEditScreen = false
    @State private var isShowingIntervalsEditor = false
    // Interval playback state
    @State private var activeIntervalID: String? = nil
    @State private var intervalStartDate: Date? = nil
    @State private var intervalElapsed: TimeInterval = 0
    @State private var uiTimer: Timer? = nil
    var body: some View {
        List {
            
            Section {
                if !session.historicalSessions.isEmpty {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { session in
                        HistoricalSessionRow(session: session, showsRelativeTimeInsteadOfTitle: true)
                            .foregroundStyle(.primary)
                            .swipeActions {
                                Button {
                                    withAnimation {
                                        
                                        // TODO:
                                        //                                        session.day.delete(historicalSessionIDs: [session.id])
                                        
                                        context.delete(session)
                                        Task {
                                            try context.save()
                                        }
                                    }
                                } label: {
                                    Label {
                                        Text("Delete")
                                    } icon: {
                                        Image(systemName: "xmark.bin")
                                    }
                                    
                                }
                                .tint(.red)
                                
                            }
                    }
                } else {
                    ContentUnavailableView {
                        Text("No progress for this goal today.")
                    } description: {
                        
                    } actions: {
                        Button {
                            
                        } label: {
                            Text("Add manual entry")
                        }
                    }
                    
                }
            } header: {
                HStack {
                    Text("History")
                    Text("\(session.historicalSessions.count)")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(4)
                        .frame(minWidth: 20)
                        .background(Capsule()
                            .fill(session.goal.primaryTheme.theme.dark))
                    Spacer()
                    Button {
                        //                      TODO:  dayToEdit = day
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            } footer: {
                if session.historicalSessions.count > historicalSessionLimit {
                    HStack {
                        Spacer()
                        Button {
                            //                            dayToEdit = day
                        } label: {
                            Text("View all")
                        }
                        //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
                        Spacer()
                    }
                }
            }
            
            
            // Replaced calls to todoSection and intervalSection with combinedSection (always rendered)
            combinedSection
            
//            if !session.checklist.isEmpty {
//                todoSection
//            }
//
//            if !session.intervals.isEmpty {
//                intervalSection
//            }
        }
        
        .scrollContentBackground(.hidden)
        .background(session.goal.primaryTheme.theme.dark.opacity(0.1))
        .navigationTitle(session.goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    
                    Button {
                        withAnimation {
                            session.goal.status = .archived
                        }
                    } label: {
                        if session.goal.status == .archived {
                            Text("Unarchive")
                        } else {
                            Text("Archive")
                        }
                    }
                } label: {
                    
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                    
                }
                
                
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditScreen.toggle()
                    
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                    
                }
                
            }
            
        }
        
        .navigationTransition(.zoom(sourceID: session.id, in: animation))
        .sheet(isPresented: $isShowingEditScreen, content: {
            IntervalsEditorView(goal: session.goal, currentSession: session)
        })
        .sheet(isPresented: $isShowingIntervalsEditor) {
            IntervalsEditorView(goal: session.goal, currentSession: session)
        }
        .onDisappear {
            let emptyItems = session.checklist.filter { $0.checklistItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for item in emptyItems {
                if let index = session.checklist.firstIndex(where: { $0.id == item.id }) {
                    session.checklist.remove(at: index)
                }
                context.delete(item)
                context.delete(item.checklistItem)
            }
            stopUITimer()
        }
    }
    
    var combinedSection: some View {
        Section {
            ForEach(session.checklist, id: \.id) { item in
                ChecklistRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            item.isCompleted.toggle()
                        }
                    }
            }
            ForEach(session.intervals.sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex }), id: \.id) { item in
                let duration = TimeInterval(item.interval.durationSeconds)
                let isActive = activeIntervalID == item.id
                let elapsed = isActive ? intervalElapsed : 0
                let progress = min(max(elapsed / max(duration, 0.001), 0), 1)
                ZStack(alignment: .leading) {
                    // Background progress bar filling full row height

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            let isCompleted = item.isCompleted
                            let displayElapsed: TimeInterval = {
                                if isCompleted { return TimeInterval(item.interval.durationSeconds) }
                                return isActive ? min(elapsed, duration) : 0
                            }()
                            let total = TimeInterval(item.interval.durationSeconds)

                            Text(item.interval.name)
                                .fontWeight(.semibold)
                                .strikethrough(isCompleted, pattern: .solid, color: .primary)
                                .opacity(isCompleted ? 0.6 : 1)

                            if isCompleted {
                                Text("\(Duration.seconds(displayElapsed).formatted(.time(pattern: .minuteSecond)))/\(Duration.seconds(total).formatted(.time(pattern: .minuteSecond)))")
                                    .font(.caption)
                                    .opacity(0.7)
                            } else {
                                let remaining = max(total - displayElapsed, 0)
                                Text("\(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond))) remaining")
                                    .font(.caption)
                                    .opacity(0.7)
                            }
                        }
                        Spacer()
                        Button {
                            toggleIntervalPlayback(for: item, in: session)
                        } label: {
                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(
                    Color(.secondarySystemGroupedBackground)
                        .overlay {
                            GeometryReader { geo in
                                let width = geo.size.width * progress
                                Rectangle()
                                    .fill(session.goal.primaryTheme.theme.light.opacity(0.25))
                                    .frame(width: width)
                                    .animation(.easeInOut(duration: 0.2), value: progress)
                            }
                            .allowsHitTesting(false)
                        }

                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        item.isCompleted.toggle()
                    }
                }
            }
        } header: {
            let completed = session.checklist.filter { $0.isCompleted }.count + session.intervals.filter { $0.isCompleted }.count
            let total = session.checklist.count + session.intervals.count
            HStack {
                Text("Checklist")
                Text("\(completed)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemBackground))
                    .padding(4)
                    .background(Capsule()
                        .fill(session.goal.primaryTheme.theme.dark))
                Spacer()
                Menu {
                    Button {
                        addChecklistItem(to: session)
                    } label: {
                        Label("Add To-Do", systemImage: "checkmark.circle")
                    }
                    Button {
                        isShowingIntervalsEditor = true
                    } label: {
                        Label("Add Interval", systemImage: "timer")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } footer: {
            let total = session.checklist.count + session.intervals.count
            if total > historicalSessionLimit {
                HStack {
                    Spacer()
                    Button {
                        //                            dayToEdit = day
                    } label: {
                        Text("View all")
                    }
                    //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
                    Spacer()
                }
            }
        }
    }
    
    var todoSection: some View {
        Section {
            ForEach(session.checklist, id: \.id) { item in
                ChecklistRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            item.isCompleted.toggle()
                        }
                    }
            }
        } header: {
            HStack {
                Text("To do")
                Text("\(session.checklist.filter { $0.isCompleted }.count)/\(session.checklist.count)")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemBackground))
                    .padding(4)
                    .background(Capsule()
                        .fill(session.goal.primaryTheme.theme.dark))
                Spacer()
                Button {
                    addChecklistItem(to: session)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } footer: {
            if session.checklist.count > historicalSessionLimit {
                HStack {
                    Spacer()
                    Button {
                        //                            dayToEdit = day
                    } label: {
                        Text("View all")
                    }
                    //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
                    Spacer()
                }
            }
        }
    }
    
    var intervalSection: some View {
        Section {
            ForEach(session.intervals.sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex }), id: \.id) { item in
                ZStack(alignment: .leading) {
                    // Background progress bar filling full row height
                    let duration = TimeInterval(item.interval.durationSeconds)
                    let isActive = activeIntervalID == item.id
                    let elapsed = isActive ? intervalElapsed : 0
                    let progress = min(max(elapsed / max(duration, 0.001), 0), 1)

                    GeometryReader { geo in
                        let width = geo.size.width * progress
                        Rectangle()
                            .fill(session.goal.primaryTheme.theme.light.opacity(0.25))
                            .frame(width: width)
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }
                    .allowsHitTesting(false)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            let isCompleted = item.isCompleted
                            let displayElapsed: TimeInterval = {
                                if isCompleted { return TimeInterval(item.interval.durationSeconds) }
                                return isActive ? min(elapsed, duration) : 0
                            }()
                            let total = TimeInterval(item.interval.durationSeconds)

                            Text(item.interval.name)
                                .fontWeight(.semibold)
                                .strikethrough(isCompleted, pattern: .solid, color: .primary)
                                .opacity(isCompleted ? 0.6 : 1)

                            if isCompleted {
                                Text("\(Duration.seconds(displayElapsed).formatted(.time(pattern: .minuteSecond)))/\(Duration.seconds(total).formatted(.time(pattern: .minuteSecond)))")
                                    .font(.caption)
                                    .opacity(0.7)
                            } else {
                                let remaining = max(total - displayElapsed, 0)
                                Text("\(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond))) remaining")
                                    .font(.caption)
                                    .opacity(0.7)
                            }
                        }
                        Spacer()
                        Button {
                            toggleIntervalPlayback(for: item, in: session)
                        } label: {
                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        item.isCompleted.toggle()
                    }
                }
            }
        } header: {
            HStack {
                Text("To do")
                Text("\(session.intervals.filter { $0.isCompleted }.count)/\(session.intervals.count)")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemBackground))
                    .padding(4)
                    .background(Capsule()
                        .fill(session.goal.primaryTheme.theme.dark))
                Spacer()
                Button {
                    addChecklistItem(to: session)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } footer: {
            if session.intervals.count > historicalSessionLimit {
                HStack {
                    Spacer()
                    Button {
                        //                            dayToEdit = day
                    } label: {
                        Text("View all")
                    }
                    //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
                    Spacer()
                }
            }
        }
    }
    
    private func addChecklistItem(to session: GoalSession) {
        let item = ChecklistItem(title: "")
        let checklistSession = ChecklistItemSession(checklistItem: item, isCompleted: false, session: session)
        session.checklist.append(checklistSession)
        context.insert(checklistSession)
    }
    
    // MARK: - Interval Playback Logic
    private func toggleIntervalPlayback(for item: IntervalSession, in session: GoalSession) {
        if activeIntervalID == item.id {
            stopUITimer()
        } else {
            startInterval(item: item, in: session)
        }
    }

    private func startInterval(item: IntervalSession, in session: GoalSession) {
        stopUITimer() // ensure only one timer
        activeIntervalID = item.id
        intervalStartDate = Date()
        intervalElapsed = 0
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            tickCurrentInterval(in: session)
        }
        RunLoop.current.add(uiTimer!, forMode: .common)
    }

    private func tickCurrentInterval(in session: GoalSession) {
        guard let activeIntervalID, let start = intervalStartDate,
              let current = session.intervals.first(where: { $0.id == activeIntervalID }) else { return }
        let duration = TimeInterval(current.interval.durationSeconds)
        intervalElapsed = Date().timeIntervalSince(start)
        if intervalElapsed >= duration {
            // mark completed
            current.isCompleted = true
            intervalElapsed = TimeInterval(current.interval.durationSeconds)
            // advance to next
            advanceToNextInterval(after: current, in: session)
        }
    }

    private func advanceToNextInterval(after current: IntervalSession, in session: GoalSession) {
        stopUITimer()
        let sorted = session.intervals.sorted { $0.interval.orderIndex < $1.interval.orderIndex }
        guard let idx = sorted.firstIndex(where: { $0.id == current.id }) else { return }
        let nextIndex = sorted.index(after: idx)
        if nextIndex < sorted.endIndex {
            let next = sorted[nextIndex]
            startInterval(item: next, in: session)
        } else {
            // finished all intervals
            activeIntervalID = nil
            intervalElapsed = 0
            intervalStartDate = nil
        }
    }

    private func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }
}
