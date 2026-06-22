import SwiftUI
import SwiftData
import OSLog
import MomentumKit
import UserNotifications
import Charts
#if canImport(WidgetKit)
import WidgetKit
#endif

struct GoalSessionDetailView: View {
    // Core data — goal is always present, session may be resolved on appear
    let goal: Goal
    private var _initialSession: GoalSession?
    var animation: Namespace.ID?
    private var _externalTimerManager: SessionTimerManager?
    var onMarkedComplete: (() -> Void)? = nil
    @Namespace private var fallbackAnimation
    
    // Resolved session (populated on appear when entering via goal-only init)
    @State private var resolvedSession: GoalSession?
    @State private var localTimerManager: SessionTimerManager?
    
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    
    /// The active session — either the one passed in or resolved from today's Day
    var session: GoalSession? {
        _initialSession ?? resolvedSession
    }
    
    /// The active timer manager — either external or locally created
    var timerManager: SessionTimerManager? {
        _externalTimerManager ?? localTimerManager
    }
    
    /// Full init from planner (with session context)
    init(goal: Goal, session: GoalSession?, animation: Namespace.ID, timerManager: SessionTimerManager, onMarkedComplete: (() -> Void)? = nil) {
        self.goal = goal
        
        self._initialSession = session
        self.animation = animation
        self._externalTimerManager = timerManager
        self.onMarkedComplete = onMarkedComplete
    }
    
    /// Goal-only init from AllGoalsView (session resolved on appear, shares existing timer manager)
    init(goal: Goal, timerManager: SessionTimerManager? = nil) {
        self.goal = goal
        self._initialSession = nil
        self.animation = nil
        self._externalTimerManager = timerManager
        self.onMarkedComplete = nil
    }
    let historicalSessionLimit = 3
    @State private var isShowingIntervalsEditor = false
    @State private var editGoalViewModel: GoalEditorViewModel?
    // Interval playback state
    @State private var activeIntervalID: String? = nil
    @State private var intervalStartDate: Date? = nil
    @State private var intervalElapsed: TimeInterval = 0

    @State private var selectedListID: String?
    @State private var isShowingListsOverview = false
    
    // Historical session editing
    @State private var editingHistoricalSession: HistoricalSession?
    @State private var isShowingHistoricalSessionEditor = false
    @State private var isCreatingNewHistoricalSession = false
    
    // Tab selection
    @State private var selectedTab: DetailTab = .hero
    @State private var isScrollingFromTap = false
    
    // Card state
    @State private var cardRotationY: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var showingPremiumPaywall = false
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }
    
    enum DetailTab: String, CaseIterable {
        case hero = "Overview"
        case whyNow = "Why now"
        case atAGlance = "At a glance"
        case thisWeek = "This week"
        case consistency = "Consistency"
    }
    
    // Notification manager
    private let notificationManager = GoalNotificationManager()
    
    // Delete confirmation
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    private var hasSession: Bool { session != nil }
    
    private var themePreset: ThemePreset {
        goal.resolvedTheme
    }
    
    var tintColor: Color {
        themePreset.color(for: colorScheme)
    }
    
    var textColor: Color {
        themePreset.foregroundColor(for: colorScheme)
    }
    
    var chartGradient: LinearGradient {
        themePreset.gradient(for: colorScheme)
    }
    
    // MARK: - Data Helpers
    
    private var isTimerActive: Bool {
        guard let session, let timerManager else { return false }
        return timerManager.isActive(session)
    }
    
    private var currentElapsed: TimeInterval {
        if let session, let timerManager,
           let activeSession = timerManager.activeSession,
           timerManager.isActive(session) {
            return activeSession.currentValue
        }
        return session?.elapsedTime ?? 0
    }
    
    private var currentProgress: Double {
        let target = session?.effectiveTargetValue ?? goal.unifiedDailyTarget
        guard target > 0 else { return 0 }
        let isCountBasedMetric = goal.healthKitSyncEnabled && goal.healthKitMetric?.isCountBased == true
        if (session?.targetUnit ?? goal.targetUnit).isTimeBased && !isCountBasedMetric {
            return currentElapsed / target
        }
        return (session?.currentValue ?? 0) / target
    }
    
    private var dailyTargetMinutes: Double {
        (session?.effectiveTargetValue ?? goal.unifiedDailyTarget) / 60.0
    }
    
    private var formattedDailyTarget: String {
        let targetUnit = session?.targetUnit ?? goal.targetUnit
        if targetUnit.isTimeBased {
            return "\(Int(dailyTargetMinutes))m"
        } else {
            let target = Int(session?.effectiveTargetValue ?? goal.unifiedDailyTarget)
            return "\(target.formatted()) \(targetUnit.label)"
        }
    }
    
    private var isReadOnly: Bool {
        goal.healthKitSyncEnabled == true &&
        goal.healthKitMetric?.supportsWrite == false
    }
    
    // MARK: - Weekly Data
    
    struct DailyProgress: Identifiable {
        let id = UUID()
        let weekday: String
        let weekdayShort: String
        let minutes: Double
        let week: String
        let date: Date
        let weekdayNumber: Int
        let dailyGoal: Double
    }
    
    private var weeklyProgressData: [DailyProgress] {
        let goal = self.goal
        
        let calendar = Calendar.current
        let now = Date()
        
        var thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekday = calendar.component(.weekday, from: thisWeekStart)
        if weekday == 1 {
            thisWeekStart = calendar.date(byAdding: .day, value: 1, to: thisWeekStart)!
        }
        
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        
        var scheduledDaysCount = 0
        for wd in 1...7 {
            if goal.hasSchedule {
                let times = goal.timesForWeekday(wd)
                if !times.isEmpty { scheduledDaysCount += 1 }
            }
        }
        
        let hasSchedule = goal.hasSchedule && scheduledDaysCount > 0
        let defaultDailyGoal = (goal.unifiedWeeklyTarget / 60.0) / 7.0
        
        var progressData: [DailyProgress] = []
        
        for (weekLabel, weekStart) in [("This Week", thisWeekStart), ("Last Week", lastWeekStart)] {
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                
                let weekdayNum = calendar.component(.weekday, from: date)
                let weekdayShort = calendar.shortWeekdaySymbols[weekdayNum - 1]
                
                let dailyGoal: Double
                if hasSchedule {
                    let times = goal.timesForWeekday(weekdayNum)
                    if !times.isEmpty && scheduledDaysCount > 0 {
                        dailyGoal = (goal.unifiedWeeklyTarget / 60.0) / Double(scheduledDaysCount)
                    } else {
                        dailyGoal = 0
                    }
                } else {
                    dailyGoal = defaultDailyGoal
                }
                
                let dayID = date.yearMonthDayID(with: calendar)
                
                let dayMinutes: Double
                do {
                    if let day = try context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })).first,
                       let historicalSessions = day.historicalSessions {
                        let goalIDString = goal.id.uuidString
                        let totalSeconds = historicalSessions
                            .filter { $0.goalIDs.contains(goalIDString) }
                            .reduce(0.0) { $0 + $1.duration }
                        dayMinutes = totalSeconds / 60.0
                    } else {
                        dayMinutes = 0
                    }
                } catch {
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
    
    private var thisWeekMinutes: Double {
        weeklyProgressData
            .filter { $0.week == "This Week" }
            .reduce(0.0) { $0 + $1.minutes }
    }
    
    private var lastWeekMinutes: Double {
        weeklyProgressData
            .filter { $0.week == "Last Week" }
            .reduce(0.0) { $0 + $1.minutes }
    }
    
    private var weeklyDeltaMinutes: Double {
        thisWeekMinutes - lastWeekMinutes
    }
    
    private var thisWeekDailyMinutes: [Double] {
        let data = weeklyProgressData.filter { $0.week == "This Week" }
        guard data.count == 7 else { return Array(repeating: 0, count: 7) }
        return data.map { $0.minutes }
    }
    
    private var daysCompletedThisWeek: Int {
        let data = weeklyProgressData.filter { $0.week == "This Week" }
        return data.filter { $0.minutes > 0 }.count
    }
    
    private var totalDaysThisWeek: Int {
        let goal = self.goal
        if goal.hasSchedule {
            var count = 0
            for wd in 1...7 {
                if !goal.timesForWeekday(wd).isEmpty { count += 1 }
            }
            return max(count, 1)
        }
        return 7
    }
    
    private var currentStreak: Int {
        let goal = self.goal
        let calendar = Calendar.current
        var streak = 0
        var date = Date()
        
        for _ in 0..<365 {
            let dayID = date.yearMonthDayID(with: calendar)
            do {
                if let day = try context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })).first,
                   let sessions = day.historicalSessions {
                    let goalIDString = goal.id.uuidString
                    let totalSeconds = sessions
                        .filter { $0.goalIDs.contains(goalIDString) }
                        .reduce(0.0) { $0 + $1.duration }
                    if totalSeconds > 0 {
                        streak += 1
                    } else {
                        break
                    }
                } else {
                    break
                }
            } catch {
                break
            }
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return streak
    }
    
    private var bestDayMinutes: Double {
        weeklyProgressData
            .filter { $0.week == "This Week" }
            .map { $0.minutes }
            .max() ?? 0
    }
    
    private var bestDayName: String {
        guard let best = weeklyProgressData
            .filter({ $0.week == "This Week" })
            .max(by: { $0.minutes < $1.minutes }),
              best.minutes > 0 else { return "—" }
        return best.weekday
    }
    
    private var dailyAvgMinutes: Double {
        let data = weeklyProgressData.filter { $0.week == "This Week" }
        let activeDays = data.filter { $0.minutes > 0 }
        guard !activeDays.isEmpty else { return 0 }
        return activeDays.reduce(0.0) { $0 + $1.minutes } / Double(activeDays.count)
    }
    
    // MARK: - Consistency data (last 12 weeks grid)
    
    private var consistencyGrid: [[Double]] {
        let goal = self.goal
        let calendar = Calendar.current
        let today = Date()
        
        var weeks: [[Double]] = []
        
        for weekOffset in stride(from: -11, through: 0, by: 1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today) else { continue }
            var week: [Double] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!) else {
                    week.append(0)
                    continue
                }
                let dayID = date.yearMonthDayID(with: calendar)
                do {
                    if let day = try context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })).first,
                       let sessions = day.historicalSessions {
                        let goalIDString = goal.id.uuidString
                        let totalSeconds = sessions
                            .filter { $0.goalIDs.contains(goalIDString) }
                            .reduce(0.0) { $0 + $1.duration }
                        week.append(totalSeconds / 60.0)
                    } else {
                        week.append(0)
                    }
                } catch {
                    week.append(0)
                }
            }
            weeks.append(week)
        }
        return weeks
    }
    
    private var weeksCompleted: Int {
        consistencyGrid.filter { week in
            week.reduce(0, +) > 0
        }.count
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            
            ScrollView {
                VStack(spacing: 0) {

                    Spacer()
                        .frame(height: 60)
                        .id(DetailTab.hero)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .scrollView).minY
                        } action: { minY in
                            if !isScrollingFromTap && minY > -200 {
                                selectedTab = .hero
                            }
                        }
                    if let session, let timerManager {
                        ProgressSummaryCardWrapper(
                            session: session,
                            weeklyProgress: currentProgress,
                            weeklyElapsedTime: currentElapsed,
                            cardRotationY: $cardRotationY,
                            shimmerOffset: $shimmerOffset,
                            timerManager: timerManager,
                            onDone: { markGoalAsDone() },
                            onSkip: { toggleSkip() },
                            onManualLog: { isCreatingNewHistoricalSession = true },
                            onGoalTap: {
                                editGoalViewModel = GoalEditorViewModel(existingGoal: goal)
                            }
                        )
                        .padding(.horizontal, 16)
                    } else {
                        goalOverviewCard
                            .padding(.horizontal, 16)
                    }
                    
                    // All sections visible, scrollable
                    ForEach(availableTabs.filter { $0 != .hero }, id: \.self) { tab in
                        sectionHeader(tab)
                        sectionContent(tab)
                    }
                }
            }
            .overlay {
                VStack {
                    tabBar(scrollProxy: scrollProxy)
                    Spacer()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let session {
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
                    }
                    
                    Button {
                        withAnimation {
                            goal.status = goal.status == .archived ? .active : .archived
                        }
                    } label: {
                        Text(goal.status == .archived ? "Unarchive" : "Archive")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editGoalViewModel = GoalEditorViewModel(existingGoal: goal)
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .tint(tintColor)
        .navigationTransition(.zoom(sourceID: session?.id ?? goal.id, in: animation ?? fallbackAnimation))
        .alert("Delete Goal?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteGoal() }
        } message: {
            Text("This will permanently delete \"\(goal.title)\" and all its data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallSheet()
        }
        .sheet(item: $editGoalViewModel) { vm in
            GoalEditorView(viewModel: vm)
        }
        .sheet(item: $editingHistoricalSession) { historicalSession in
            HistoricalSessionEditorView(session: historicalSession)
        }
        .sheet(isPresented: $isCreatingNewHistoricalSession) {
            if let session, let day = session.day {
                NavigationStack {
                    HistoricalSessionEditorView(
                        session: HistoricalSession(
                            title: goal.title,
                            start: Date(),
                            end: Date().addingTimeInterval(1800),
                            needsHealthKitRecord: false
                        ),
                        goalSession: session,
                        day: day,
                        isNewSession: true
                    )
                }
            }
        }
        .onAppear {
            resolveSessionIfNeeded()
        }
    }
    
    /// When entering with just a Goal, look up today's session for this goal
    private func resolveSessionIfNeeded() {
        guard _initialSession == nil, resolvedSession == nil else { return }
        
        let calendar = Calendar.current
        let todayID = Date().yearMonthDayID(with: calendar)
        
        do {
            if let day = try context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == todayID })).first,
               let session = day.sessions?.first(where: { $0.goal?.id == goal.id }) {
                resolvedSession = session
            }
        } catch {
            // No session found for today — goal-only mode
        }
        
        // Create a local timer manager only if no external one was provided
        if _externalTimerManager == nil && localTimerManager == nil {
            localTimerManager = SessionTimerManager(goalStore: goalStore, modelContext: context)
        }
    }
    
    // MARK: - Tab Bar
    
    private func tabBar(scrollProxy: ScrollViewProxy) -> some View {
        ScrollViewReader { tabScrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Button {
                            isScrollingFromTap = true
                            selectedTab = tab
                            withAnimation(.snappy(duration: 0.35)) {
                                scrollProxy.scrollTo(tab, anchor: UnitPoint(x: 0.5, y: 0.08))
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                isScrollingFromTap = false
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedTab == tab ? tintColor : Color(.systemGray5))
                                )
                                .animation(.easeInOut(duration: 0.25), value: selectedTab)
                        }
                        .buttonStyle(.plain)
                        .id("pill_\(tab.rawValue)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: selectedTab) { _, newTab in
                withAnimation(.easeInOut(duration: 0.25)) {
                    tabScrollProxy.scrollTo("pill_\(newTab.rawValue)", anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Section Header (scroll anchor)
    
    private func sectionHeader(_ tab: DetailTab) -> some View {
        let isActive = selectedTab == tab
        
        return Text(tab.rawValue.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .tracking(1.2)
            .foregroundStyle(isActive ? tintColor : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .id(tab)
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .scrollView).minY
            } action: { minY in
                if !isScrollingFromTap && minY < 80 && minY > -20 {
                    selectedTab = tab
                }
            }
    }
    
    /// Tabs available for the current context
    private var availableTabs: [DetailTab] {
        if hasSession {
            return DetailTab.allCases
        } else {
            return DetailTab.allCases.filter { $0 != .whyNow }
        }
    }
    
    @ViewBuilder
    private func sectionContent(_ tab: DetailTab) -> some View {
        switch tab {
        case .hero:
            EmptyView()
        case .whyNow:
            if hasSession { whyNowTab }
        case .atAGlance:
            analyticsContent { atAGlanceTab }
        case .thisWeek:
            analyticsContent { thisWeekTab }
        case .consistency:
            analyticsContent { consistencyTab }
        }
    }
    
    @ViewBuilder
    private func analyticsContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isSubscribed {
            content()
        } else {
            content()
                .blur(radius: 6)
                .allowsHitTesting(false)
                .overlay {
                    Button {
                        showingPremiumPaywall = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                            Text("Unlock Analytics")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(textColor.opacity(0.8))
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }
                }
        }
    }
    
    // MARK: - Goal Overview Card (no session)
    
    private var goalOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TOTAL FOCUSED")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundStyle(textColor.opacity(0.8))
                
                Spacer()
                
                if weeklyDeltaMinutes != 0 {
                    let deltaSeconds = abs(weeklyDeltaMinutes) * 60
                    Text("\(weeklyDeltaMinutes > 0 ? "↑" : "↓") \(TimeInterval(deltaSeconds).formatted(style: .hourMinute))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor.opacity(0.9))
                }
            }
            
            Text(TimeInterval(thisWeekMinutes * 60).formatted(style: .hourMinute))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
            
            GoalWeeklyBarChart(dailyMinutes: thisWeekDailyMinutes, barColor: textColor)
            
            Button {
                editGoalViewModel = GoalEditorViewModel(existingGoal: goal)
            } label: {
                HStack {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(textColor.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background {
            themePreset.gradient(for: colorScheme)
        }
        .glassCardStyle(shadowColor: themePreset.color(for: colorScheme))
    }
    
    // MARK: - Why Now Tab
    
    private var whyNowTab: some View {
        VStack(spacing: 16) {
            let reasons = session?.safeRecommendationReasons ?? []
            
            if !reasons.isEmpty {
                // Callout banner
                if let topReason = reasons.first {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.right")
                            .font(.subheadline)
                            .foregroundStyle(tintColor)
                        Text(topReason.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(tintColor.opacity(0.08))
                    )
                }
                
                // Signal rows
                VStack(spacing: 0) {
                    ForEach(Array(reasons.enumerated()), id: \.element) { index, reason in
                        signalRow(reason: reason)
                        if index < reasons.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                
                // Footer
                if goal.hasSchedule {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Recommended by your schedule")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No recommendation signals yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Signals will appear as you build patterns")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
            
            // History section
            historySection
        }
        .padding(.horizontal, 16)
    }
    
    private func signalRow(reason: RecommendationReason) -> some View {
        HStack(spacing: 14) {
            Image(systemName: reason.icon)
                .font(.body)
                .foregroundStyle(tintColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(signalLabel(for: reason))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(reason.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            strengthBadge(for: reason)
        }
        .padding(.vertical, 10)
    }
    
    private func signalLabel(for reason: RecommendationReason) -> String {
        switch reason {
        case .preferredTime, .usualTime, .constrained: return "TIME OF DAY"
        case .availableTime: return "CALENDAR"
        case .weeklyProgress, .quickFinish: return "YOUR PATTERN"
        case .userPriority, .plannedTheme: return "PRIORITY"
        case .weather: return "WEATHER"
        case .goalSequence: return "GOAL SEQUENCE"
        }
    }
    
    private func strengthBadge(for reason: RecommendationReason) -> some View {
        let strength: (String, Color) = {
            switch reason {
            case .preferredTime, .weeklyProgress, .constrained, .goalSequence:
                return ("STRONG", Color(.systemGreen))
            case .availableTime, .quickFinish, .usualTime:
                return ("MEDIUM", Color(.systemOrange))
            case .weather, .userPriority, .plannedTheme:
                return ("SLIGHT", Color(.systemGray))
            }
        }()
        
        return HStack(spacing: 4) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 6))
            Text(strength.0)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundStyle(strength.1)
    }
    
    // MARK: - At a Glance Tab
    
    private var atAGlanceTab: some View {
        VStack(spacing: 16) {
            // Four stat cards in 2x2
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(
                    title: "STREAK",
                    value: "\(currentStreak)",
                    unit: "days",
                    footnote: currentStreak > 0 ? "KEEP GOING" : "START TODAY",
                    icon: "flame.fill"
                )
                
                statCard(
                    title: "THIS WEEK",
                    value: "\(Int(thisWeekMinutes))",
                    unit: "min",
                    footnote: weeklyDeltaMinutes >= 0 ? "+\(Int(weeklyDeltaMinutes)) VS LAST" : "\(Int(weeklyDeltaMinutes)) VS LAST",
                    icon: "chart.bar.fill"
                )
                
                statCard(
                    title: "DAILY AVG",
                    value: "\(Int(dailyAvgMinutes))",
                    unit: "min",
                    footnote: "STEADY",
                    icon: "equal.circle.fill"
                )
                
                statCard(
                    title: "BEST DAY",
                    value: "\(Int(bestDayMinutes))",
                    unit: "min",
                    footnote: bestDayName.uppercased(),
                    icon: "star.fill"
                )
            }
            
            // Daily progress bar strip
            dailyProgressStrip
            
            // Schedule grid
            if goal.hasSchedule {
                scheduleGridSection
            }
            
            // Settings section
            settingsSection
            
            // Tags
            if let otherTags = goal.otherTags, !otherTags.isEmpty {
                tagsSection(tags: otherTags)
            }
            
            // Stats
            goalStatsSection
            
            // Checklist
            checklistSection
        }
        .padding(.horizontal, 16)
    }
    
    private func statCard(title: String, value: String, unit: String, footnote: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                Text(unit)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(footnote)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(tintColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - This Week Tab
    
    private var thisWeekTab: some View {
        VStack(spacing: 16) {
            // Weekly summary header
            VStack(alignment: .leading, spacing: 8) {
                Text("DAILY PROGRESS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(thisWeekMinutes))")
                        .font(.system(size: 40, weight: .bold))
                    Text("min this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(weeklyDeltaMinutes >= 0 ? "+\(Int(weeklyDeltaMinutes))" : "\(Int(weeklyDeltaMinutes))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(weeklyDeltaMinutes >= 0 ? Color(.systemGreen) : Color(.systemOrange))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(weeklyDeltaMinutes >= 0 ? Color(.systemGreen).opacity(0.12) : Color(.systemOrange).opacity(0.12))
                        )
                }
                
                Text("Target is \(formattedDailyTarget) a day, \(daysCompletedThisWeek) of \(totalDaysThisWeek) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            
            // Weekly bar chart
            weeklyBarChart
            
            // History
            historySection
        }
        .padding(.horizontal, 16)
    }
    
    private var weeklyBarChart: some View {
        let data = weeklyProgressData.filter { $0.week == "This Week" }
        let maxVal = max(data.map(\.minutes).max() ?? 1, dailyTargetMinutes)
        
        return VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.minutes > 0 ? tintColor : Color(.systemGray5))
                            .frame(height: max(4, CGFloat(day.minutes / maxVal) * 100))
                        
                        Text(day.weekdayShort)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Consistency Tab
    
    private var consistencyTab: some View {
        VStack(spacing: 16) {
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("CONSISTENCY")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(weeksCompleted)")
                        .font(.system(size: 40, weight: .bold))
                    Text("completed of 12 weeks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            
            // Heatmap grid
            consistencyHeatmap
            
            // Records
            VStack(alignment: .leading, spacing: 12) {
                Text("HISTORICAL RECORDS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    recordPill(title: "Streak", value: "\(currentStreak) days", icon: "flame.fill")
                    recordPill(
                        title: "Best Day",
                        value: bestDayMinutes > 0 ? "\(Int(bestDayMinutes)) min" : "—",
                        icon: "star.fill"
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var consistencyHeatmap: some View {
        let grid = consistencyGrid
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        
        return VStack(spacing: 4) {
            // Day labels
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid rows (each row = 1 week)
            ForEach(0..<grid.count, id: \.self) { weekIndex in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let minutes = weekIndex < grid.count && dayIndex < grid[weekIndex].count ? grid[weekIndex][dayIndex] : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(minutes > 0 ? tintColor.opacity(min(0.3 + (minutes / 60.0) * 0.7, 1.0)) : Color(.systemGray5))
                            .frame(height: 16)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private func recordPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tintColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
    
    // MARK: - Shared Components
    
    private var dailyProgressStrip: some View {
        let data = weeklyProgressData.filter { $0.week == "This Week" }
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("DAILY PROGRESS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(day.minutes > 0 ? tintColor : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if day.minutes > 0 && day.dailyGoal > 0 && day.minutes >= day.dailyGoal {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        Text(day.weekdayShort)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - History Section
    
    @ViewBuilder
    private var historySection: some View {
        if let session {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("HISTORY")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text("\(session.historicalSessions.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tintColor))
                    
                    Spacer()
                    
                    Button {
                        isCreatingNewHistoricalSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(tintColor)
                    }
                }
                
                if session.historicalSessions.isEmpty {
                    Text("No sessions recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { historicalSession in
                        HStack {
                            HistoricalSessionRow(
                                session: historicalSession,
                                showsTimeSummaryInsteadOfTitle: true,
                                allSessions: Array(session.historicalSessions)
                            )
                            
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
                        .contextMenu {
                            if historicalSession.healthKitType == nil {
                                Button {
                                    editingHistoricalSession = historicalSession
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            
                            Button(role: .destructive) {
                                deleteHistoricalSession(historicalSession)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        if historicalSession.id != session.historicalSessions.prefix(historicalSessionLimit).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SETTINGS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            // HealthKit
            if goal.healthKitSyncEnabled == true, let metric = goal.healthKitMetric {
                HStack(spacing: 12) {
                    Image(systemName: metric.symbolName)
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("HealthKit Sync")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(metric.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(metric.supportsWrite ? "Read & Write" : "Read")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            
            // Notes
            if let notes = goal.notes, !notes.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundStyle(tintColor)
                        .frame(width: 24)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }
            
            // Notifications
            if goal.scheduleNotificationsEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(tintColor)
                        .frame(width: 24)
                    Text("Start Notifications")
                        .font(.subheadline)
                }
            }
            
            if goal.completionNotificationsEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tintColor)
                        .frame(width: 24)
                    Text("Finish Notifications")
                        .font(.subheadline)
                }
            }
            
            // Weather
            if goal.weatherEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Weather-Based Visibility")
                            .font(.subheadline)
                        if let conditions = goal.weatherConditionsTyped, !conditions.isEmpty {
                            Text(conditions.map { $0.displayName }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Link
            if let link = goal.link, let url = URL(string: link) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(tintColor)
                            .frame(width: 24)
                        Text(link)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Schedule Grid
    
    private var scheduleGridSection: some View {
        let weekdays: [(Int, String)] = [
            (2, "M"), (3, "T"), (4, "W"),
            (5, "T"), (6, "F"), (7, "S"), (1, "S")
        ]
        let times = Array(TimeOfDay.allCases)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("SCHEDULE")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                // Header row
                HStack(spacing: 6) {
                    ForEach(weekdays, id: \.0) { _, label in
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Grid with gradient
                ZStack {
                    themePreset.gradient(for: colorScheme)
                        .mask {
                            VStack(spacing: 2) {
                                ForEach(times, id: \.self) { time in
                                    HStack(spacing: 8) {
                                        ForEach(weekdays, id: \.0) { weekday, _ in
                                            let isScheduled = goal.isScheduled(weekday: weekday, time: time)
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
                    
                    // Unscheduled overlay
                    VStack(spacing: 2) {
                        ForEach(times, id: \.self) { time in
                            HStack(spacing: 8) {
                                ForEach(weekdays, id: \.0) { weekday, _ in
                                    let isScheduled = goal.isScheduled(weekday: weekday, time: time)
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
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Tags Section
    
    private func tagsSection(tags: [GoalTag]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAGS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.themeID) { tag in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tag.theme.color(for: colorScheme))
                                .frame(width: 8, height: 8)
                            Text(tag.title)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tag.theme.color(for: colorScheme).opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Goal Stats Section
    
    private var goalStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GOAL INFO")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("Daily Target")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(goal.unifiedWeeklyTarget / 60 / 7))m")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Weekly Target")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(goal.unifiedWeeklyTarget / 60))m")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let dailyMin = goal.dailyMinimum {
                HStack {
                    Text("Daily Minimum")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(dailyMin / 60))m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("Status")
                    .font(.subheadline)
                Spacer()
                Text(goal.status == .active ? "Active" : "Archived")
                    .font(.subheadline)
                    .foregroundStyle(goal.status == .active ? .green : .secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Checklist Section
    
    @ViewBuilder
    private var checklistSection: some View {
        if let checklist = session?.checklist, !checklist.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CHECKLIST")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    let completed = checklist.filter { $0.isCompleted }.count
                    Text("\(completed)/\(checklist.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                ForEach(checklist) { item in
                    ChecklistRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                item.isCompleted.toggle()
                            }
                        }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Actions
    
    private func markGoalAsDone() {
        guard let session, let timerManager else { return }
        withAnimation {
            guard let day = session.day else { return }
            timerManager.markGoalAsDone(session: session, day: day, context: context)
        }
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        onMarkedComplete?()
    }
    
    private func toggleSkip() {
        guard let session else { return }
        withAnimation {
            if session.status == .skipped {
                session.status = .active
            } else {
                session.status = .skipped
            }
        }
        context.safeSave()
    }
    
    private func deleteHistoricalSession(_ historicalSession: HistoricalSession) {
        withAnimation {
            session?.day?.historicalSessions?.removeAll { $0.id == historicalSession.id }
            context.delete(historicalSession)
        }
        context.safeSave()
    }
    
    private func deleteGoal() {
        HapticFeedbackManager.trigger(.warning)
        
        withAnimation {
            context.delete(goal)
        }
        
        if context.safeSave() {
            dismiss()
        }
    }
}

// MARK: - Weekly Bar Chart

private struct GoalWeeklyBarChart: View {
    let dailyMinutes: [Double]
    let barColor: Color
    let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    
    var body: some View {
        let maxMinutes = max(dailyMinutes.max() ?? 1, 1)
        
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                let minutes = index < dailyMinutes.count ? dailyMinutes[index] : 0
                let ratio = minutes / maxMinutes
                
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(minutes > 0 ? 0.3 + (ratio * 0.7) : 0.15))
                        .frame(height: max(barHeight(minutes, max: maxMinutes), 4))
                    
                    Text(dayLabels[index])
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(barColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60)
    }
    
    private func barHeight(_ value: Double, max maxValue: Double) -> CGFloat {
        guard maxValue > 0, value > 0 else { return 4 }
        return CGFloat(value / maxValue) * 48
    }
}

// MARK: - Convenience Extensions
private extension GoalSession {
    func isScheduled(weekday: Int, time: TimeOfDay) -> Bool {
        goal?.isScheduled(weekday: weekday, time: time) ?? false
    }
}

// MARK: - Preview

private struct GoalSessionDetailPreview: View {
    @Namespace private var animation
    let container: ModelContainer
    let session: GoalSession
    let store: GoalStore
    let timerManager: SessionTimerManager
    
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Day.self, Goal.self, GoalSession.self, GoalTag.self,
            configurations: config
        )
        self.container = container
        
        let goal = Goal(title: "Morning Meditation")
        goal.iconName = "brain.head.profile"
        goal.themeID = "ocean"
        
        let now = Date.now
        let day = Day(start: now.startOfDay()!, end: now.endOfDay()!)
        
        container.mainContext.insert(goal)
        container.mainContext.insert(day)
        
        let session = GoalSession(title: "Morning Meditation", goal: goal, day: day)
        container.mainContext.insert(session)
        
        try? container.mainContext.save()
        
        self.session = session
        self.store = GoalStore()
        self.timerManager = SessionTimerManager(goalStore: store, modelContext: container.mainContext)
    }
    
    var body: some View {
        NavigationStack {
            GoalSessionDetailView(
                goal: session.goal!, session: session,
                animation: animation,
                timerManager: timerManager
            )
        }
        .environment(store)
        .modelContainer(container)
    }
}

#Preview("Full Detail") {
    GoalSessionDetailPreview()
}

#Preview("Hero Card") {
    GoalSessionHeroCardPreview()
}

private struct GoalSessionHeroCardPreview: View {
    let container: ModelContainer
    let session: GoalSession
    let store: GoalStore
    let timerManager: SessionTimerManager
    @State private var cardRotationY: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Day.self, Goal.self, GoalSession.self, GoalTag.self,
            configurations: config
        )
        self.container = container
        
        let goal = Goal(title: "Ship the launch deck")
        goal.iconName = "doc.text.fill"
        goal.themeID = "ocean"
        goal.dailyMinimum = 5400 // 1h 30m
        
        let now = Date.now
        let day = Day(start: now.startOfDay()!, end: now.endOfDay()!)
        
        container.mainContext.insert(goal)
        container.mainContext.insert(day)
        
        let session = GoalSession(title: "Ship the launch deck", goal: goal, day: day)
        container.mainContext.insert(session)
        session.day?.add(historicalSession: HistoricalSession(title: "1", start: now, end: now.endOfDay()!, needsHealthKitRecord: false))
        try? container.mainContext.save()
        
        self.session = session
        self.store = GoalStore()
        self.timerManager = SessionTimerManager(goalStore: store, modelContext: container.mainContext)
    }
    
    var body: some View {
        ScrollView {
            ProgressSummaryCardWrapper(
                session: session,
                weeklyProgress: session.progress,
                weeklyElapsedTime: session.elapsedTime,
                cardRotationY: $cardRotationY,
                shimmerOffset: $shimmerOffset,
                timerManager: timerManager,
                onDone: {},
                onSkip: {},
                onManualLog: {}
            )
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
        .environment(store)
        .modelContainer(container)
    }
}
