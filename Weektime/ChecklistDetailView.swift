import SwiftUI
import SwiftData
import WeektimeKit
import UserNotifications

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

    @State private var selectedListID: String?
    @State private var isShowingListsOverview = false

    var tintColor: Color {
        session.goal.primaryTheme.theme.dark
    }
    
    var body: some View {
        List {
            // History section remains as-is
            Section {
                if !session.historicalSessions.isEmpty {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { historicalSession in
                        HistoricalSessionRow(session: historicalSession, showsTimeSummaryInsteadOfTitle: true)
                            .foregroundStyle(.primary)
                            .swipeActions {
                                // Only allow deletion of manual entries, not HealthKit synced ones
                                if historicalSession.healthKitType == nil {
                                    Button {
                                        withAnimation {
                                            context.delete(historicalSession)
                                            Task { try context.save() }
                                        }
                                    } label: {
                                        Label { Text("Delete") } icon: { Image(systemName: "xmark.bin") }
                                    }
                                    .tint(.red)
                                }
                            }
                    }
                } else {
                    ContentUnavailableView {
                        Text("No progress for this goal today.")
                    } description: { } actions: {
                        Button { } label: { Text("Add manual entry") }
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
                        .background(Capsule().fill(session.goal.primaryTheme.theme.dark))
                    Spacer()
                    Button { } label: { Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical) }
                }
            } footer: {
                if session.historicalSessions.count > historicalSessionLimit {
                    HStack { Spacer(); Button { } label: { Text("View all") }; Spacer() }
                }
            }

            // NEW: Horizontal tabs for lists
            Section {
                TabView(selection: $selectedListID) {
                    ForEach(session.intervalLists) { listSession in
                        IntervalListView(listSession: listSession, activeIntervalID: $activeIntervalID, intervalStartDate: $intervalStartDate, intervalElapsed: $intervalElapsed, uiTimer: $uiTimer, limit: 3)
                            .tag(listSession.id)
                    }
                }
                .tabViewStyle(.page)
                .frame(minHeight: 200)
                .onAppear {
                    if selectedListID == nil {
                        selectedListID = session.intervalLists.first?.id
                    }
                }
            } header: {
                VStack {
                    HStack {
                        Button {
                            isShowingListsOverview = true
                        } label: {
                            Text("Lists") // TODO: Naming
                            Text("\(session.intervalLists.count)")
                                .font(.caption2)
                                .foregroundStyle(Color(.systemBackground))
                                .padding(2)
                                .frame(minWidth: 15)
                                .background(Capsule().fill(tintColor))
                            Image(systemName: "chevron.right")
                                .tint(tintColor)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        Button {
                            isShowingIntervalsEditor = true
                        } label: { Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical) }
                    }
                    
                    IntervalListSelector(lists: session.intervalLists, selectedListID: $selectedListID, tintColor: tintColor)
                }

            }
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
        .navigationDestination(isPresented: $isShowingListsOverview) {
            ListsOverviewView(session: session, selectedListID: $selectedListID, tintColor: tintColor)
        }
        .navigationTransition(.zoom(sourceID: session.id, in: animation))
        .sheet(isPresented: $isShowingIntervalsEditor) {
            let list = IntervalList(name: "", goal: session.goal)
            IntervalsEditorView(list: list, goalSession: session)
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
//            stopUITimer() // TODO:
        }
    }
  

    
    // TODO:
//    var intervalSection: some View {
//        Section {
//            ForEach(session.intervals.sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex }), id: \.id) { item in
//                let filteredSorted = session.intervals
//                    .filter { $0.interval.kind == item.interval.kind && $0.interval.name == item.interval.name }
//                    .sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex })
//                let totalCount = filteredSorted.count
//                let currentIndex = (filteredSorted.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
//
//                ZStack(alignment: .leading) {
//                    // Background progress bar filling full row height
//                    let duration = TimeInterval(item.interval.durationSeconds)
//                    let isActive = activeIntervalID == item.id
//                    let elapsed = isActive ? intervalElapsed : 0
//                    let progress = min(max(elapsed / max(duration, 0.001), 0), 1)
//
//                    GeometryReader { geo in
//                        let width = geo.size.width * progress
//                        Rectangle()
//                            .fill(session.goal.primaryTheme.theme.light.opacity(0.25))
//                            .frame(width: width)
//                            .animation(.easeInOut(duration: 0.2), value: progress)
//                    }
//                    .allowsHitTesting(false)
//
//                    HStack {
//                        VStack(alignment: .leading, spacing: 4) {
//                            let isCompleted = item.isCompleted
//                            let displayElapsed: TimeInterval = {
//                                if isCompleted { return TimeInterval(item.interval.durationSeconds) }
//                                return isActive ? min(elapsed, duration) : 0
//                            }()
//                            let total = TimeInterval(item.interval.durationSeconds)
//
//                            Text("\(item.interval.name) \(currentIndex)/\(totalCount)")
//                                .fontWeight(.semibold)
//                                .strikethrough(isCompleted, pattern: .solid, color: .primary)
//                                .opacity(isCompleted ? 0.6 : 1)
//
//                            if isCompleted {
//                                Text("\(Duration.seconds(displayElapsed).formatted(.time(pattern: .minuteSecond)))/\(Duration.seconds(total).formatted(.time(pattern: .minuteSecond)))")
//                                    .font(.caption)
//                                    .opacity(0.7)
//                            } else {
//                                let remaining = max(total - displayElapsed, 0)
//                                Text("\(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond))) remaining")
//                                    .font(.caption)
//                                    .opacity(0.7)
//                            }
//                        }
//                        Spacer()
//                        Button {
////                            toggleIntervalPlayback(for: item, in: session)
//                        } label: {
//                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
//                                .symbolRenderingMode(.hierarchical)
//                                .font(.title2)
//                        }
//                        .buttonStyle(.plain)
//                    }
//                    .padding(.vertical, 8)
//                }
//                .contentShape(Rectangle())
//                .onTapGesture {
//                    withAnimation {
//                        item.isCompleted.toggle()
//                    }
//                }
//            }
//        } header: {
//            HStack {
//                Text("To do")
//                Text("\(session.intervals.filter { $0.isCompleted }.count)/\(session.intervals.count)")
//                    .font(.caption2)
//                    .foregroundStyle(Color(.systemBackground))
//                    .padding(4)
//                    .background(Capsule()
//                        .fill(session.goal.primaryTheme.theme.dark))
//                Spacer()
//                Button {
//                    addChecklistItem(to: session)
//                } label: {
//                    Image(systemName: "plus.circle.fill")
//                        .symbolRenderingMode(.hierarchical)
//                }
//            }
//        } footer: {
//            if session.intervals.count > historicalSessionLimit {
//                HStack {
//                    Spacer()
//                    Button {
//                        //                            dayToEdit = day
//                    } label: {
//                        Text("View all")
//                    }
//                    //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
//                    Spacer()
//                }
//            }
//        }
//    }
    
    private func addChecklistItem(to session: GoalSession) {
        let item = ChecklistItem(title: "")
        let checklistSession = ChecklistItemSession(checklistItem: item, isCompleted: false, session: session)
        session.checklist.append(checklistSession)
        context.insert(checklistSession)
    }
    
    // MARK: - Notifications
    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }

    private func notificationIdentifier(for interval: IntervalSession) -> String {
        return "interval_\(interval.id)"
    }
// TODO: 
//    private func cancelAllIntervalNotifications(for session: GoalSession) {
//        let ids = session.intervals.map { notificationIdentifier(for: $0) }
//        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
//    }
//
//    private func scheduleNotifications(from current: IntervalSession, in session: GoalSession, startingIn secondsOffset: TimeInterval = 0) {
//        // Schedule notification for current interval end and all subsequent intervals
//        requestNotificationAuthorizationIfNeeded()
//        let sorted = session.intervals.sorted { $0.interval.orderIndex < $1.interval.orderIndex }
//        guard let startIndex = sorted.firstIndex(where: { $0.id == current.id }) else { return }
//        var cumulative: TimeInterval = secondsOffset
//        for idx in startIndex..<sorted.count {
//            let item = sorted[idx]
//            let duration = TimeInterval(item.interval.durationSeconds)
//            cumulative += duration
//            let content = UNMutableNotificationContent()
//            content.title = session.goal.title
//            content.body = "\(item.interval.name) complete"
//            content.sound = .default
//
//            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(cumulative, 0.5), repeats: false)
//            let request = UNNotificationRequest(identifier: notificationIdentifier(for: item), content: content, trigger: trigger)
//            UNUserNotificationCenter.current().add(request)
//        }
//    }
}

