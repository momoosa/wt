import SwiftUI
import SwiftData
import MomentumKit
import UserNotifications
import Charts
#if canImport(WidgetKit)
import WidgetKit
#endif

struct GoalSessionDetailView: View {
    var session: GoalSession
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    var animation: Namespace.ID
    var timerManager: SessionTimerManager
    var onMarkedComplete: (() -> Void)? = nil
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
    
    // Historical session editing
    @State private var editingHistoricalSession: HistoricalSession?
    @State private var isShowingHistoricalSessionEditor = false
    @State private var isCreatingNewHistoricalSession = false
    
    // Card tilt and shimmer states
    @State private var cardRotationY: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    
    // Chart tab selection
    @State private var selectedChartTab: ChartTab = .daily
    
    enum ChartTab: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }
    
    // Notification manager (created as needed)
    private let notificationManager = GoalNotificationManager()
    
    // Delete confirmation
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var tintColor: Color {
        let theme = session.theme
        return colorScheme == .dark ? theme.light : theme.dark
    }
    
    var chartGradient: LinearGradient {
        let theme = session.theme
        return LinearGradient(
            colors: [theme.dark, theme.neon],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Schedule data for chart
    struct SchedulePoint: Identifiable {
        let id = UUID()
        let weekday: String
        let timeOfDay: String
    }
    
    // Weekly progress data
    struct DailyProgress: Identifiable {
        let id = UUID()
        let weekday: String
        let weekdayShort: String
        let minutes: Double
        let week: String // "This Week" or "Last Week"
        let date: Date
        let weekdayNumber: Int
        let dailyGoal: Double
    }
    
    // Hourly progress data for daily chart
    struct HourlyProgress: Identifiable {
        let id = UUID()
        let hour: Int
        let minutes: Double
        let isScheduled: Bool
    }
    
    private var weeklyProgressData: [DailyProgress] {
        guard let goal = session.goal else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of this week (Monday)
        var thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        // Adjust to Monday if needed (calendar default might be Sunday)
        let weekday = calendar.component(.weekday, from: thisWeekStart)
        if weekday == 1 { // Sunday
            thisWeekStart = calendar.date(byAdding: .day, value: 1, to: thisWeekStart)!
        }
        
        // Get start of last week
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        
        // Calculate daily goal per weekday based on schedule
        var scheduledDaysCount = 0
        for wd in 1...7 {
            if goal.hasSchedule {
                // Check if this weekday is scheduled
                let times = goal.timesForWeekday(wd)
                if !times.isEmpty {
                    scheduledDaysCount += 1
                }
            }
        }
        
        // If no schedule or all days scheduled, divide evenly
        let hasSchedule = goal.hasSchedule && scheduledDaysCount > 0
        let defaultDailyGoal = (goal.weeklyTarget / 60.0) / 7.0
        
        var progressData: [DailyProgress] = []
        
        // Process both weeks
        for (weekLabel, weekStart) in [("This Week", thisWeekStart), ("Last Week", lastWeekStart)] {
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                
                let weekdayNum = calendar.component(.weekday, from: date)
                let weekdayShort = calendar.shortWeekdaySymbols[weekdayNum - 1]
                
                // Calculate daily goal for this specific weekday
                let dailyGoal: Double
                if hasSchedule {
                    let times = goal.timesForWeekday(weekdayNum)
                    if !times.isEmpty && scheduledDaysCount > 0 {
                        // This day is scheduled, allocate portion of weekly target
                        dailyGoal = (goal.weeklyTarget / 60.0) / Double(scheduledDaysCount)
                    } else {
                        // Not scheduled, no goal
                        dailyGoal = 0
                    }
                } else {
                    // No schedule, divide evenly
                    dailyGoal = defaultDailyGoal
                }
                
                // Get all historical sessions for this goal on this day
                let dayID = date.yearMonthDayID(with: calendar)
                
                // Find the day and its sessions
                let dayMinutes: Double
                if let day = try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })).first,
                   let historicalSessions = day.historicalSessions {
                    // Sum up time for this goal
                    let goalIDString = goal.id.uuidString
                    let totalSeconds = historicalSessions
                        .filter { $0.goalIDs.contains(goalIDString) }
                        .reduce(0.0) { $0 + $1.duration }
                    dayMinutes = totalSeconds / 60.0
                } else {
                    dayMinutes = 0
                }
                
                progressData.append(DailyProgress(
                    weekday: calendar.weekdaySymbols[weekdayNum - 1],
                    weekdayShort: weekdayShort,
                    minutes: dayMinutes,
                    week: weekLabel,
                    date: date,
                    weekdayNumber: weekdayNum,
                    dailyGoal: dailyGoal
                ))
            }
        }
        
        return progressData
    }
    
    private var dailyTargetMinutes: Double {
        return (session.dailyTarget / 60.0)
    }
    
    private var dailyProgressData: [HourlyProgress] {
        guard let goal = session.goal else { return [] }
        
        let calendar = Calendar.current
        let today = session.day?.startDate ?? Date()
        let dayID = today.yearMonthDayID(with: calendar)
        
        // Get today's weekday for schedule checking
        let weekdayNum = calendar.component(.weekday, from: today)
        
        // Get all historical sessions for this goal on this day
        let historicalSessions: [HistoricalSession]
        if let day = try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })).first,
           let sessions = day.historicalSessions {
            let goalIDString = goal.id.uuidString
            historicalSessions = sessions.filter { $0.goalIDs.contains(goalIDString) }
        } else {
            historicalSessions = []
        }
        
        // Create hourly buckets (0-23)
        var hourlyData: [HourlyProgress] = []
        
        for hour in 0..<24 {
            // Calculate minutes in this hour
            var minutesInHour: Double = 0
            
            for session in historicalSessions {
                let sessionStart = session.startDate
                let sessionEnd = session.endDate
                
                let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
                let hourEnd = calendar.date(bySettingHour: hour, minute: 59, second: 59, of: today)!
                
                // Check if session overlaps with this hour
                if sessionEnd > hourStart && sessionStart < hourEnd {
                    // Calculate overlap
                    let overlapStart = max(sessionStart, hourStart)
                    let overlapEnd = min(sessionEnd, hourEnd)
                    let overlapSeconds = overlapEnd.timeIntervalSince(overlapStart)
                    minutesInHour += overlapSeconds / 60.0
                }
            }
            
            // Determine if this hour is scheduled
            let timeOfDay: TimeOfDay? = {
                switch hour {
                case 6..<11: return .morning
                case 11..<14: return .midday
                case 14..<17: return .afternoon
                case 17..<22: return .evening
                default: return nil
                }
            }()
            
            let isScheduled = timeOfDay != nil && goal.isScheduled(weekday: weekdayNum, time: timeOfDay!)
            
            hourlyData.append(HourlyProgress(
                hour: hour,
                minutes: minutesInHour,
                isScheduled: isScheduled
            ))
        }
        
        return hourlyData
    }
    
    private var dailyProgressChart: some View {
        let data = dailyProgressData
        let maxValue = data.map { $0.minutes }.max() ?? 1
        
        return Chart {
            ForEach(data.filter { $0.isScheduled }) { item in
                BarMark(
                    x: .value("Hour", item.hour),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(chartGradient)
            }
            
            ForEach(data.filter { !$0.isScheduled }) { item in
                BarMark(
                    x: .value("Hour", item.hour),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(Color.secondary.opacity(0.7))
            }
            
            // Add target line if there's a daily target
            if dailyTargetMinutes > 0 {
                let targetPerHour = dailyTargetMinutes / 24.0
                RuleMark(y: .value("Target", targetPerHour))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(tintColor.opacity(0.5))
            }
        }
        .chartYScale(domain: 0...(max(maxValue, dailyTargetMinutes / 24.0) * 1.2))
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))m")
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartLegend(.hidden)
    }
    
    private var weeklyProgressChart: some View {
        let data = weeklyProgressData
        let maxGoal = data.map { $0.dailyGoal }.max() ?? 0
        let maxActual = data.map { $0.minutes }.max() ?? 0
        let maxValue = max(maxGoal, maxActual)
        
        return Chart {
            // Bar marks for this week
            ForEach(data.filter { $0.week == "This Week" }) { item in
                BarMark(
                    x: .value("Day", item.weekdayShort),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(chartGradient)
                .position(by: .value("Week", item.week))
            }
            
            // Bar marks for last week
            ForEach(data.filter { $0.week == "Last Week" }) { item in
                BarMark(
                    x: .value("Day", item.weekdayShort),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(Color.secondary.opacity(0.5))
                .position(by: .value("Week", item.week))
            }
        }
        .chartYScale(domain: 0...(maxValue * 1.2))
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let day = value.as(String.self) {
                        Text(day)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))m")
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartLegend(.hidden)
    }
    
    var schedulePoints: [SchedulePoint] {

        let weekdays: [(Int, String)] = [
            (2, "M"), (3, "T"), (4, "W"),
            (5, "T"), (6, "F"), (7, "S"), (1, "S")
        ]

        var points: [SchedulePoint] = []
        for (weekdayNum, dayLabel) in weekdays {
            for timeOfDay in TimeOfDay.allCases {
                if session.isScheduled(weekday: weekdayNum, time: timeOfDay) {
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
        let theme = session.theme
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
                                        let isScheduled = session.isScheduled(weekday: weekday, time: time)
                                        
                                        Image(systemName: time.icon)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(isScheduled ? Color.white : Color.clear)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .frame(height: LayoutConstants.Heights.iconPlaceholder)
                                    }
                                }
                                .frame(height: LayoutConstants.Heights.iconPlaceholder)
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
                                    let isScheduled = session.isScheduled(weekday: weekday, time: time)
                                    
                                    Image(systemName: time.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(isScheduled ? Color.clear : Color.secondary.opacity(0.15))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .frame(height: LayoutConstants.Heights.iconPlaceholder)
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
        let target = session.goal?.weeklyTarget ?? 0
        guard target > 0 else { return 0 }
        return weeklyElapsedTime / target
    }
    
    var weeklyElapsedTime: TimeInterval {
        // Placeholder - would need to sum all sessions in the week
        return session.elapsedTime
    }
    
    /// Calculates the total amount of overlapping time in minutes
    private var overlappingMinutes: Int {
        let sessions = session.historicalSessions
        guard sessions.count > 1 else { return 0 }
        
        // Calculate total time without deduplication
        let totalWithoutDedup = sessions.reduce(0.0) { $0 + $1.duration }
        
        // Calculate deduplicated time (using same algorithm as elapsedTime)
        let dedupTime = session.elapsedTime
        
        // Difference is the overlapping time
        let overlapSeconds = totalWithoutDedup - dedupTime
        
        return Int(overlapSeconds / 60)
    }
    
    @ViewBuilder
    private var progressSection: some View {
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
                    onSkip: toggleSkip,
                    onManualLog: {
                        isCreatingNewHistoricalSession = true
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
            }
            
            // Progress Charts (Daily & Weekly)
            Section {
                TabView(selection: $selectedChartTab) {
                    // Daily Chart
                    VStack(spacing: 12) {
                        dailyProgressChart
                            .frame(height: 140)
                        
                        HStack(spacing: 16) {
                            if session.goal?.hasSchedule == true {
                                Label("Scheduled", systemImage: "circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(tintColor)
                            }
                            Label("Unscheduled", systemImage: "circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .tag(ChartTab.daily)
                    
                    // Weekly Chart
                    VStack(spacing: 12) {
                        weeklyProgressChart
                            .frame(height: 140)
                        
                        HStack(spacing: 16) {
                            Label("This Week", systemImage: "circle.fill")
                                .font(.caption2)
                                .foregroundStyle(tintColor)
                            Label("Last Week", systemImage: "circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .tag(ChartTab.weekly)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 200)
            } header: {
                HStack {
                    Text("Progress")
                    Spacer()
                    Picker("Chart Type", selection: $selectedChartTab) {
                        ForEach(ChartTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
            
            // Schedule Display
            if session.goal?.hasSchedule == true {
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
    }
    
    @ViewBuilder
    private var settingsSection: some View {
            // Goal Settings Info
            Section {
                // HealthKit Integration
                if let goal = session.goal, goal.healthKitSyncEnabled == true, let metric = goal.healthKitMetric {
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
                if let goal = session.goal {
                    Toggle(isOn: Binding(
                        get: { goal.scheduleNotificationsEnabled },
                        set: { newValue in
                            goal.scheduleNotificationsEnabled = newValue
                            try? context.save()
                            
                            // Schedule or cancel schedule notifications
                            Task {
                                if newValue {
                                    try? await notificationManager.scheduleNotifications(for: goal)
                                } else {
                                    await notificationManager.cancelScheduleNotifications(for: goal)
                                }
                            }
                        }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Notifications")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if goal.hasSchedule {
                                    Text(goal.scheduleNotificationsEnabled ? "Notify when starting sessions" : "Tap to enable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(goal.scheduleNotificationsEnabled ? "Notify when starting sessions" : "Tap to enable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: goal.scheduleNotificationsEnabled ? "bell.badge.fill" : "bell.badge")
                            .foregroundStyle(goal.scheduleNotificationsEnabled ? tintColor : .secondary)
                    }
                    }
                    .tint(tintColor)
                }
                
                // Completion Notifications Toggle
                if let goal = session.goal {
                    Toggle(isOn: Binding(
                        get: { goal.completionNotificationsEnabled },
                        set: { newValue in
                            goal.completionNotificationsEnabled = newValue
                            try? context.save()
                        }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Finish Notifications")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(goal.completionNotificationsEnabled ? "Notify when goal is completed" : "Tap to enable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: goal.completionNotificationsEnabled ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundStyle(goal.completionNotificationsEnabled ? tintColor : .secondary)
                        }
                    }
                    .tint(tintColor)
                }
            } header: {
                Text("Settings")
            }
            
            // Notes and Link section
            if session.goal?.notes != nil || session.goal?.link != nil {
                Section {
                    if let notes = session.goal?.notes {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text("Notes")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "note.text")
                                    .foregroundStyle(tintColor)
                            }
                            
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let link = session.goal?.link, let url = URL(string: link) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reference Link")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(link)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: "link")
                                    .foregroundStyle(tintColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Resources")
                }
            }
    }
    
    @ViewBuilder
    private var historySection: some View {
            // History section remains as-is
            Section {
                if !session.historicalSessions.isEmpty {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { historicalSession in
                        HStack {
                            HistoricalSessionRow(session: historicalSession, showsTimeSummaryInsteadOfTitle: true, allSessions: Array(session.historicalSessions))
                                .foregroundStyle(.primary)
                            
                            // Show edit button for non-HealthKit sessions
                            if historicalSession.healthKitType == nil {
                                Spacer()
                                Button {
                                    editingHistoricalSession = historicalSession
                                    isShowingHistoricalSessionEditor = true
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundStyle(tintColor)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                        Button {
                            isCreatingNewHistoricalSession = true
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
                        .background(Capsule().fill(session.theme.dark))
                    Spacer()
                    Button {
                        isCreatingNewHistoricalSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(tintColor)
                    }
                }
            } footer: {
                VStack(spacing: 8) {
                    // Show deduplication explanation if there are overlapping sessions
                    let overlap = overlappingMinutes
                    if overlap > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(overlap) min of overlapping time merged to avoid double-counting")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if session.historicalSessions.count > historicalSessionLimit {
                        HStack { Spacer(); Button { } label: { Text("View all") }; Spacer() }
                    }
                }
            }
    }
    
    @ViewBuilder
    private var checklistSection: some View {
        if let goal = session.goal, let checklistItems = goal.checklistItems, !checklistItems.isEmpty {
            Section {
                ForEach(session.checklist ?? []) { itemSession in
                    ChecklistRow(item: itemSession)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                itemSession.isCompleted.toggle()
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Checklist")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    let completedCount = session.checklist?.filter { $0.isCompleted }.count ?? 0
                    let totalCount = session.checklist?.count ?? 0
                    
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    @ViewBuilder
    private var listsSection: some View {
            // NEW: Horizontal tabs for lists
            Section {
                TabView(selection: $selectedListID) {
                    ForEach(session.intervalLists ?? []) { listSession in
                        IntervalListView(listSession: listSession, activeIntervalID: $activeIntervalID, intervalStartDate: $intervalStartDate, intervalElapsed: $intervalElapsed, uiTimer: $uiTimer, timerManager: timerManager, goalSession: session, limit: 3)
                            .tag(listSession.id)
                    }
                }
                .tabViewStyle(.page)
                .frame(minHeight: 200)
                .onAppear {
                    if selectedListID == nil {
                        selectedListID = session.intervalLists?.first?.id
                    }
                }
            } header: {
                VStack {
                    HStack {
                        Button {
                            isShowingListsOverview = true
                        } label: {
                            Text("Lists")
                            Text("\(session.intervalLists?.count ?? 0)")
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
                    
                    IntervalListSelector(lists: session.intervalLists ?? [], selectedListID: $selectedListID, tintColor: tintColor)
                }

            }
    }
    
    var body: some View {
        let list = List {
            progressSection
            settingsSection
            historySection
            checklistSection
            // listsSection // Disabled for now
        }
        
        let backgroundColor = session.theme.dark.opacity(0.1)
        
        return list
        .scrollContentBackground(.hidden)
        .background(backgroundColor)
        .navigationTitle(session.goal?.title ?? "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Interval feature disabled for now
                    // Button {
                    //     isShowingIntervalsEditor.toggle()
                    // } label: {
                    //     Label("Add Interval List", systemImage: "list.bullet.circle")
                    // }
                    
                    Button {
                        withAnimation {
                            session.pinnedInWidget.toggle()
                        }
                        #if canImport(WidgetKit)
                        WidgetCenter.shared.reloadAllTimelines()
                        #endif
                    } label: {
                        Label(
                            session.pinnedInWidget ? "Unpin from Widget" : "Pin to Widget",
                            systemImage: session.pinnedInWidget ? "pin.slash.fill" : "pin.fill"
                        )
                    }
                    
                    Divider()
                    
                    if let goal = session.goal {
                        Button {
                            withAnimation {
                                goal.status = .archived
                            }
                        } label: {
                            if goal.status == .archived {
                                Text("Unarchive")
                            } else {
                                Text("Archive")
                            }
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Goal", systemImage: "trash")
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
            ListsOverviewView(session: session, selectedListID: $selectedListID, tintColor: tintColor, timerManager: timerManager)
        }
        .navigationTransition(.zoom(sourceID: session.id, in: animation))
        .alert("Delete Goal?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("This will permanently delete \"\(session.goal?.title ?? "this goal")\" and all its data. This action cannot be undone.")
        }
        .sheet(isPresented: $isShowingIntervalsEditor) {
            if let goal = session.goal {
                let list = IntervalList(name: "", goal: goal)
                IntervalsEditorView(list: list, goalSession: session)
            }
        }
        .sheet(isPresented: $isShowingEditScreen) {
            if let goal = session.goal {
                GoalEditorView(existingGoal: goal)
            }
        }
        .sheet(item: $editingHistoricalSession, content: { session in
            HistoricalSessionEditorView(session: session)
        })
        .sheet(isPresented: $isCreatingNewHistoricalSession) {
            if let goal = session.goal, let day = session.day {
                NavigationStack {
                    HistoricalSessionEditorView(
                        session: HistoricalSession(
                            title: goal.title,
                            start: Date(),
                            end: Date().addingTimeInterval(1800), // Default 30 min session
                            needsHealthKitRecord: false
                        ),
                        goalSession: session,
                        day: day,
                        isNewSession: true
                    )
                }
            }
        }
        .onDisappear {
            let emptyItems = session.checklist?.filter { $0.checklistItem?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true } ?? []
            for item in emptyItems {
                if let index = session.checklist?.firstIndex(where: { $0.id == item.id }) {
                    session.checklist?.remove(at: index)
                }
                context.delete(item)
                if let checklistItem = item.checklistItem {
                    context.delete(checklistItem)
                }
            }
        }
    }
  


    
    private func addChecklistItem(to session: GoalSession) {
        let item = ChecklistItem(title: "")
        let checklistSession = ChecklistItemSession(checklistItem: item, isCompleted: false, session: session)
        if session.checklist == nil {
            session.checklist = []
        }
        session.checklist?.append(checklistSession)
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
        
        return session.isScheduled(weekday: weekday, time: currentTime)
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
        
        if session.isScheduled(weekday: weekday, time: currentTime) {
            return "Active now"
        } else {
            // Find next scheduled time
            let times = session.goal?.timesForWeekday(weekday) ?? []
            if !times.isEmpty {
                return "Scheduled today"
            } else {
                return "Not today"
            }
        }
    }
    
    // MARK: - Goal Actions
    
    private func markGoalAsDone() {
        withAnimation {
            guard let day = session.day else { return }
            timerManager.markGoalAsDone(session: session, day: day, context: context)
        }
        
        // Provide haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        // Notify parent and dismiss
        onMarkedComplete?()
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
    
    private func deleteGoal() {
        guard let goal = session.goal else { return }
        
        withAnimation {
            context.delete(goal)
        }
        
        try? context.save()
        dismiss()
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

// MARK: - Convenience Extensions
private extension GoalSession {
    func isScheduled(weekday: Int, time: TimeOfDay) -> Bool {
        goal?.isScheduled(weekday: weekday, time: time) ?? false
    }
}

