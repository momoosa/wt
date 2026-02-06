import SwiftUI
import SwiftData
import MomentumKit
import UserNotifications

struct ChecklistDetailView: View {
    var session: GoalSession
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    var animation: Namespace.ID
    var timerManager: SessionTimerManager
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
    
    // Card tilt and shimmer states
    @State private var cardRotationY: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    var tintColor: Color {
        colorScheme == .dark ? session.goal.primaryTag.theme.neon : session.goal.primaryTag.theme.dark
    }
    
    // Weekly progress calculation
    var weeklyProgress: Double {
        let target = session.goal.weeklyTarget
        guard target > 0 else { return 0 }
        return weeklyElapsedTime / target
    }
    
    var weeklyElapsedTime: TimeInterval {
        // Placeholder - would need to sum all sessions in the week
        return session.elapsedTime
    }
    
    var body: some View {
        List {
            // Progress Summary Card
            Section {
            } header: {
                ProgressSummaryCardWrapper(
                    session: session,
                    weeklyProgress: weeklyProgress,
                    weeklyElapsedTime: weeklyElapsedTime,
                    cardRotationY: $cardRotationY,
                    shimmerOffset: $shimmerOffset,
                    timerManager: timerManager
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
            }
            
            // Action Buttons
            Section {
                HStack(spacing: 12) {
                    // Mark as Done button
                    Button {
                        markGoalAsDone()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                            Text("Done")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tintColor.opacity(0.15))
                        .foregroundStyle(tintColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    // Start/Stop button
                    Button {
                        timerManager.toggleTimer(for: session, in: session.day)
                    } label: {
                        let isActive = timerManager.isActive(session)
                        VStack(spacing: 4) {
                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                            Text(isActive ? "Pause" : "Start")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tintColor.opacity(0.15))
                        .foregroundStyle(tintColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    // Skip button
                    Button {
                        toggleSkip()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "forward.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                            Text(session.status == .skipped ? "Undo Skip" : "Skip")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listRowBackground(Color.clear)
            
            // Schedule Display
            if session.goal.hasSchedule {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Compact weekly schedule grid
                        VStack(spacing: 8) {
                            // Header row
                            HStack(spacing: 4) {
                                Text("")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .frame(width: 35, alignment: .leading)
                                
                                ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                                    Image(systemName: timeOfDay.icon)
                                        .font(.caption2)
                                        .frame(maxWidth: .infinity)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Day rows
                            let weekdays: [(Int, String)] = [
                                (2, "Mon"), (3, "Tue"), (4, "Wed"),
                                (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
                            ]
                            
                            ForEach(weekdays, id: \.0) { weekday, name in
                                HStack(spacing: 4) {
                                    Text(name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(width: 35, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                    
                                    ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                                        let isScheduled = session.goal.isScheduled(weekday: weekday, time: timeOfDay)
                                        Circle()
                                            .fill(isScheduled ? tintColor : Color.secondary.opacity(0.2))
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                            .frame(maxHeight: 20)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    HStack {
                        Text("Schedule")
                        Spacer()
                        Text(currentDayTimeStatus)
                            .font(.caption)
                            .foregroundStyle(isCurrentlyScheduled ? tintColor : .secondary)
                    }
                }
            }
            
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
                        .background(Capsule().fill(session.goal.primaryTag.theme.dark))
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
        .background(session.goal.primaryTag.theme.dark.opacity(0.1))
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
        .sheet(isPresented: $isShowingEditScreen) {
            GoalEditorView(existingGoal: session.goal)
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
//                            .fill(session.goal.primaryTag.theme.light.opacity(0.25))
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
//                        .fill(session.goal.primaryTag.theme.dark))
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
    
    // MARK: - Schedule Helpers
    
    /// Check if the goal is currently scheduled based on current day and time
    private var isCurrentlyScheduled: Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        let currentTime: TimeOfDay = {
            switch hour {
            case 6..<11: return .morning
            case 11..<14: return .midday
            case 14..<17: return .afternoon
            default: return .evening
            }
        }()
        
        return session.goal.isScheduled(weekday: weekday, time: currentTime)
    }
    
    /// Get a human-readable status of current schedule
    private var currentDayTimeStatus: String {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        let currentTime: TimeOfDay = {
            switch hour {
            case 6..<11: return .morning
            case 11..<14: return .midday
            case 14..<17: return .afternoon
            default: return .evening
            }
        }()
        
        if session.goal.isScheduled(weekday: weekday, time: currentTime) {
            return "Active now"
        } else {
            // Find next scheduled time
            let times = session.goal.timesForWeekday(weekday)
            if !times.isEmpty {
                return "Scheduled today"
            } else {
                return "Not today"
            }
        }
    }
    
    // MARK: - Goal Actions
    
    private func markGoalAsDone() {
        timerManager.markGoalAsDone(session: session, day: session.day, context: context)
    }
    
    private func toggleSkip() {
        withAnimation {
            // Mark session as skipped
            if session.status == .skipped {
                session.status = .active
            } else {
                session.status = .skipped
            }
        }
        
        try? context.save()
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

