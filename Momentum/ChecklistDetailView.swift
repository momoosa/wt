import SwiftUI
import SwiftData
import MomentumKit
import UserNotifications
import Charts

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
    
    // Notification manager (created as needed)
    private let notificationManager = GoalNotificationManager()

    var tintColor: Color {
        let theme = session.goal.primaryTag.theme
        return colorScheme == .dark ? theme.light : theme.dark
    }
    
    // Schedule data for chart
    struct SchedulePoint: Identifiable {
        let id = UUID()
        let weekday: String
        let timeOfDay: String
    }
    
    var schedulePoints: [SchedulePoint] {

        let weekdays: [(Int, String)] = [
            (2, "M"), (3, "T"), (4, "W"),
            (5, "T"), (6, "F"), (7, "S"), (1, "S")
        ]

        var points: [SchedulePoint] = []
        for (weekdayNum, dayLabel) in weekdays {
            for timeOfDay in TimeOfDay.allCases {
                if session.goal.isScheduled(weekday: weekdayNum, time: timeOfDay) {
                    points.append(SchedulePoint(weekday: dayLabel, timeOfDay: timeOfDay.displayName))
                }
            }
        }
        return points
    }
    
    var scheduleChartView: some View {
        let weekdays: [(Int, String)] = [
            (2, "M"), (3, "T"), (4, "W"),
            (5, "T"), (6, "F"), (7, "S"), (1, "S")
        ]
        let times = Array(TimeOfDay.allCases)
        let theme = session.goal.primaryTag.theme
        let goal = session.goal
        
        return VStack(spacing: 4) {
            // Header row with day labels
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.0) { _, label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid with gradient overlay
            ZStack {
                // Icons on the left
                
                // Gradient with mask
                HStack(spacing: 6) {
                    LinearGradient(
                        colors: [theme.dark, theme.neon],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask {
                        VStack(spacing: 2) {
                            ForEach(times, id: \.self) { time in
                                HStack(spacing: 8) {
                                    ForEach(weekdays, id: \.0) { weekday, _ in
                                        let isScheduled = session.goal.isScheduled(weekday: weekday, time: time)
                                        
                                        Image(systemName: time.icon)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(isScheduled ? Color.white : Color.clear)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .frame(height: 20)
                                    }
                                }
                                .frame(height: 20)
                            }
                        }
                    }
                }
                
                // Unscheduled cells overlay
                HStack(spacing: 6) {
                    VStack(spacing: 2) {
                        ForEach(times, id: \.self) { time in
                            HStack(spacing: 8) {
                                ForEach(weekdays, id: \.0) { weekday, _ in
                                    let isScheduled = session.goal.isScheduled(weekday: weekday, time: time)
                                    
                                    Image(systemName: time.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(isScheduled ? Color.clear : Color.secondary.opacity(0.15))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .frame(height: 20)
                                }
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
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
                    timerManager: timerManager,
                    onDone: markGoalAsDone,
                    onSkip: toggleSkip
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
            }
            
            // Schedule Display
            if session.goal.hasSchedule {
                Section {
                    scheduleChartView
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
            
            // Goal Settings Info
            Section {
                // HealthKit Integration
                if session.goal.healthKitSyncEnabled, let metric = session.goal.healthKitMetric {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HealthKit Sync")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(metric.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: metric.symbolName)
                                .foregroundStyle(tintColor)
                        }
                        
                        Spacer()
                        
                        if metric.supportsWrite {
                            Text("Read & Write")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tintColor.opacity(0.15))
                                .clipShape(Capsule())
                        } else {
                            Text("Read")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                // Schedule Notifications Toggle
                Toggle(isOn: Binding(
                    get: { session.goal.scheduleNotificationsEnabled },
                    set: { newValue in
                        session.goal.scheduleNotificationsEnabled = newValue
                        try? context.save()
                        
                        // Schedule or cancel schedule notifications
                        Task {
                            if newValue {
                                try? await notificationManager.scheduleNotifications(for: session.goal)
                            } else {
                                await notificationManager.cancelScheduleNotifications(for: session.goal)
                            }
                        }
                    }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Notifications")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if session.goal.hasSchedule {
                                Text(session.goal.scheduleNotificationsEnabled ? "Notify when starting sessions" : "Tap to enable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(session.goal.scheduleNotificationsEnabled ? "Notify when starting sessions" : "Tap to enable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: session.goal.scheduleNotificationsEnabled ? "bell.badge.fill" : "bell.badge")
                            .foregroundStyle(session.goal.scheduleNotificationsEnabled ? tintColor : .secondary)
                    }
                }
                .tint(tintColor)
                
                // Completion Notifications Toggle
                Toggle(isOn: Binding(
                    get: { session.goal.completionNotificationsEnabled },
                    set: { newValue in
                        session.goal.completionNotificationsEnabled = newValue
                        try? context.save()
                    }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Finish Notifications")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(session.goal.completionNotificationsEnabled ? "Notify when goal is completed" : "Tap to enable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: session.goal.completionNotificationsEnabled ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundStyle(session.goal.completionNotificationsEnabled ? tintColor : .secondary)
                    }
                }
                .tint(tintColor)
            } header: {
                Text("Settings")
            }
            
            // History section remains as-is
            Section {
                if !session.historicalSessions.isEmpty {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { historicalSession in
                        HistoricalSessionRow(session: historicalSession, showsTimeSummaryInsteadOfTitle: true, allSessions: Array(session.historicalSessions))
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
                            Text("Lists")
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
        .tint(tintColor)
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
        }
    }
  


    
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
    
    // MARK: - Chart Helpers
}

