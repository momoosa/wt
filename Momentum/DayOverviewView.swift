import SwiftUI
import SwiftData
import Charts
import MomentumKit
import OSLog

struct DayOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    let day: Day
    let sessions: [GoalSession]
    let goals: [Goal]
    let animation: Namespace.ID
    
    // Additional parameters for plan view
    let timerManager: SessionTimerManager?
    let healthKitManager: HealthKitManager?
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    
    @Environment(\.sessionActions) private var sessionActions
    
    @State private var selectedTab: DayTab = .today
    @State private var yesterdaySessions: [GoalSession] = []
    @State private var removedSessionIDs: Set<String> = []
    @State private var todayHourlyHealthData: [HealthKitManager.HourlyStatistic] = []
    @State private var yesterdayHourlyHealthData: [HealthKitManager.HourlyStatistic] = []

    private var progressViewModel: DailyProgressViewModel {
        DailyProgressViewModel(sessions: sessions)
    }
    
    enum DayTab: String, CaseIterable {
        case yesterday = "Yesterday"
        case today = "Today"
    }

    /// Minimum duration (in seconds) for a session to be shown individually.
    /// Sessions shorter than this are grouped into a summary row.
    private static let minSessionDuration: TimeInterval = 5
    
    // Get all historical sessions from all goals, grouped by hour with time ranges
    private var groupedHistoricalSessions: [GroupedHourSessions] {
        Self.groupSessionsByHour(sessions.flatMap { $0.historicalSessions })
    }
    
    // MARK: - Plan View Helpers
    
    private var recommendedSessions: [GoalSession] {
        sessions.filter { session in
            session.status == .active && 
            session.plannedPriority != nil &&
            session.unifiedTargetValue > 0 &&
            !removedSessionIDs.contains(session.id.uuidString)
        }
    }
    
    private var orderedRecommendedSessions: [GoalSession] {
        recommendedSessions.sorted { s1, s2 in
            let p1 = s1.plannedPriority ?? 999
            let p2 = s2.plannedPriority ?? 999
            return p1 < p2
        }
    }
    
    private var totalPlannedMinutes: Int {
        Int(orderedRecommendedSessions.reduce(0.0) { $0 + $1.unifiedTargetValue } / 60)
    }
    
    // MARK: - Yesterday Helpers
    
    private var yesterdayGroupedSessions: [GroupedHourSessions] {
        Self.groupSessionsByHour(yesterdaySessions.flatMap { $0.historicalSessions })
    }
    
    /// Groups historical sessions by hour, filtering tiny sessions into a summary
    private static func groupSessionsByHour(_ allSessions: [HistoricalSession]) -> [GroupedHourSessions] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: allSessions) { session -> Int in
            calendar.component(.hour, from: session.startDate)
        }
        
        return grouped.sorted { $0.key < $1.key }
            .compactMap { hour, sessions in
                let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
                
                // Separate significant sessions from tiny ones
                let significant = sortedSessions.filter {
                    $0.endDate.timeIntervalSince($0.startDate) >= minSessionDuration
                }
                let tiny = sortedSessions.filter {
                    $0.endDate.timeIntervalSince($0.startDate) < minSessionDuration
                }
                
                // If all sessions are tiny, show a single summary for the group
                // If there are some significant ones, show those + a summary of the tiny ones
                let earliestStartDate = sortedSessions.compactMap { $0.startDate }.min() ?? Date()
                let latestEndDate = sortedSessions.compactMap { $0.endDate }.max() ?? Date()
                
                let tinyCount = tiny.count
                let tinyTotalDuration = tiny.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                return GroupedHourSessions(
                    startDate: earliestStartDate,
                    endDate: latestEndDate,
                    sessions: significant,
                    groupedSmallSessionCount: tinyCount,
                    groupedSmallSessionDuration: tinyTotalDuration
                )
            }
            .filter { !$0.sessions.isEmpty || $0.groupedSmallSessionCount > 0 }
    }
    
    // MARK: - Activity Goal Hourly Summaries
    
    /// Groups hourly HealthKit data by goal for display in the sessions list
    private var todayActivityGoalSummaries: [ActivityGoalSummary] {
        buildActivityGoalSummaries(from: todayHourlyHealthData, goalSessions: sessions)
    }
    
    private var yesterdayActivityGoalSummaries: [ActivityGoalSummary] {
        buildActivityGoalSummaries(from: yesterdayHourlyHealthData, goalSessions: yesterdaySessions)
    }
    
    /// Minimum hourly value thresholds below which entries are grouped into a summary
    private static func minHourlyThreshold(for unit: Goal.TargetUnit) -> Double {
        switch unit {
        case .kilocalories: return 5
        case .steps: return 50
        case .seconds: return 30
        }
    }
    
    private func buildActivityGoalSummaries(
        from hourlyData: [HealthKitManager.HourlyStatistic],
        goalSessions: [GoalSession]
    ) -> [ActivityGoalSummary] {
        guard !hourlyData.isEmpty else { return [] }
        
        var summaries: [ActivityGoalSummary] = []
        let statsByMetric = Dictionary(grouping: hourlyData, by: \.metric)
        
        for gs in goalSessions {
            guard !gs.targetUnit.isTimeBased,
                  gs.status == .active,
                  gs.unifiedTargetValue > 0,
                  let metric = gs.goal?.healthKitMetric,
                  let stats = statsByMetric[metric],
                  !stats.isEmpty else { continue }
            
            let total = stats.reduce(0) { $0 + $1.value }
            let threshold = Self.minHourlyThreshold(for: gs.targetUnit)
            
            let significant = stats.filter { $0.value >= threshold }
                .sorted { $0.hour < $1.hour }
            let small = stats.filter { $0.value < threshold }
            let smallTotal = small.reduce(0.0) { $0 + $1.value }
            
            summaries.append(ActivityGoalSummary(
                goalTitle: gs.goal?.title ?? "Activity",
                metric: metric,
                targetUnit: gs.targetUnit,
                currentValue: total,
                targetValue: gs.unifiedTargetValue,
                theme: gs.theme,
                hourlyData: significant,
                groupedSmallHourCount: small.count,
                groupedSmallHourValue: smallTotal
            ))
        }
        
        return summaries
    }
    
    // MARK: - Activity Chart Data
    
    private var todayActivityEntries: [HourlyActivityEntry] {
        buildHourlyActivityData(
            from: sessions.flatMap(\.historicalSessions),
            goalSessions: sessions,
            hourlyHealthData: todayHourlyHealthData
        )
    }
    
    private var yesterdayActivityEntries: [HourlyActivityEntry] {
        buildHourlyActivityData(
            from: yesterdaySessions.flatMap(\.historicalSessions),
            goalSessions: yesterdaySessions,
            hourlyHealthData: yesterdayHourlyHealthData
        )
    }
    
    private var yesterdayInsights: [String] {
        var insights: [String] = []
        
        let completed = yesterdaySessions.filter { $0.hasMetDailyTarget }
        let total = yesterdaySessions.filter { $0.status == .active && $0.unifiedTargetValue > 0 }
        
        guard !total.isEmpty else { return insights }
        
        let completionRate = Double(completed.count) / Double(total.count)
        
        if completionRate >= 0.8 {
            insights.append("Great work! You completed \(Int(completionRate * 100))% of your planned goals")
        } else if completionRate >= 0.5 {
            insights.append("You completed \(completed.count) of \(total.count) planned goals")
        }
        
        if completed.count >= 3 {
            insights.append("You're building great momentum!")
        }
        
        return insights
    }
    
    private func yesterdayGoalTitle(for historicalSession: HistoricalSession) -> String? {
        guard let firstGoalID = historicalSession.goalIDs.first,
              let uuid = UUID(uuidString: firstGoalID),
              let goal = goals.first(where: { $0.id == uuid }) else {
            return nil
        }
        return goal.title
    }
    
    // Helper to get goal title for a historical session
    private func goalTitle(for historicalSession: HistoricalSession) -> String? {
        // Get the first goal ID from the session
        guard let firstGoalID = historicalSession.goalIDs.first,
              let uuid = UUID(uuidString: firstGoalID),
              let goal = goals.first(where: { $0.id == uuid }) else {
            return nil
        }
        return goal.title
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("Day", selection: $selectedTab) {
                    ForEach(DayTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    yesterdayView
                        .tag(DayTab.yesterday)
                    
                    todayView
                        .tag(DayTab.today)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Day Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await loadYesterdayData()
                await loadHourlyHealthData()
            }
        }
        .navigationTransition(
            .zoom(sourceID: "dayOverviewCard", in: animation)
        )
    }
    
    // MARK: - Yesterday View
    
    private var yesterdayView: some View {
        List {
            // Yesterday's Summary Card
            if !yesterdaySessions.isEmpty {
                Section {
                    yesterdayStatsCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listSectionSpacing(.compact)
                
                // Hourly Activity Chart
                if !yesterdayActivityEntries.isEmpty {
                    Section {
                        HourlyActivityChart(entries: yesterdayActivityEntries)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listSectionSpacing(.compact)
                }
                
                // Insights
                if !yesterdayInsights.isEmpty {
                    Section {
                        ForEach(yesterdayInsights, id: \.self) { insight in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.body)
                                    .foregroundStyle(.yellow)
                                
                                Text(insight)
                                    .font(.subheadline)
                            }
                        }
                    } header: {
                        Text("Insights")
                    }
                }
                
                // Historical sessions grouped by hour
                if !yesterdayGroupedSessions.isEmpty {
                    ForEach(yesterdayGroupedSessions.indices, id: \.self) { index in
                        let group = yesterdayGroupedSessions[index]
                        Section {
                            ForEach(group.sessions) { historicalSession in
                                HistoricalSessionRow(
                                    session: historicalSession,
                                    showsTimeSummaryInsteadOfTitle: false,
                                    allSessions: group.sessions,
                                    goalTitle: yesterdayGoalTitle(for: historicalSession)
                                )
                            }
                            if group.hasGroupedSessions {
                                GroupedSmallSessionsRow(
                                    count: group.groupedSmallSessionCount,
                                    totalDuration: group.groupedSmallSessionDuration
                                )
                            }
                        } header: {
                            Text(formatTimeRange(startDate: group.startDate, endDate: group.endDate))
                        }
                    }
                }
                
                // Activity Goal Hourly Breakdowns (steps, calories, etc.)
                ForEach(yesterdayActivityGoalSummaries) { summary in
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: summary.icon)
                                .font(.title3)
                                .foregroundStyle(summary.theme.color(for: colorScheme))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.goalTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(summary.formattedCurrent) / \(summary.formattedTarget) \(summary.unitLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(summary.progress * 100))%")
                                .font(.headline)
                                .foregroundStyle(summary.progress >= 1.0 ? .green : summary.theme.color(for: colorScheme))
                        }
                        
                        ForEach(summary.hourlyData) { stat in
                            ActivityGoalHourlyRow(stat: stat, summary: summary)
                        }
                        
                        // Grouped small hours summary
                        if summary.groupedSmallHourCount > 0 {
                            GroupedSmallActivityRow(
                                count: summary.groupedSmallHourCount,
                                totalValue: summary.groupedSmallHourValue,
                                summary: summary
                            )
                        }
                    } header: {
                        Text(summary.metric.displayName)
                    }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("No Activity Yesterday", systemImage: "moon.zzz")
                    } description: {
                        Text("Complete some goals today and check back tomorrow to review your progress")
                    }
                    .frame(minHeight: 300)
                }
                .listRowBackground(Color.clear)
            }
        }
        .refreshable {
            await loadYesterdayData()
        }
    }
    
    // MARK: - Today View
    
    private var todayView: some View {
        List {
            // Progress Summary Card
            Section {
                progressSummaryCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listSectionSpacing(.compact)
            
            // Hourly Activity Chart
            if !todayActivityEntries.isEmpty {
                Section {
                    HourlyActivityChart(entries: todayActivityEntries)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listSectionSpacing(.compact)
            }
            
            // Historical Sessions by Hour
            if !groupedHistoricalSessions.isEmpty {
                ForEach(groupedHistoricalSessions.indices, id: \.self) { index in
                    let group = groupedHistoricalSessions[index]
                    Section {
                        ForEach(group.sessions) { historicalSession in
                            HistoricalSessionRow(
                                session: historicalSession,
                                showsTimeSummaryInsteadOfTitle: false,
                                allSessions: group.sessions,
                                goalTitle: goalTitle(for: historicalSession)
                            )
                        }
                        if group.hasGroupedSessions {
                            GroupedSmallSessionsRow(
                                count: group.groupedSmallSessionCount,
                                totalDuration: group.groupedSmallSessionDuration
                            )
                        }
                    } header: {
                        Text(formatTimeRange(startDate: group.startDate, endDate: group.endDate))
                    }
                }
            } else if recommendedSessions.isEmpty && todayActivityGoalSummaries.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Activity Yet", systemImage: "clock")
                    } description: {
                        Text("Start a timer or log progress on one of your goals to see your activity here")
                    }
                    .frame(minHeight: 300)
                }
                .listRowBackground(Color.clear)
            }
            
            // Activity Goal Hourly Breakdowns (steps, calories, etc.)
            ForEach(todayActivityGoalSummaries) { summary in
                Section {
                    // Summary header row
                    HStack(spacing: 12) {
                        Image(systemName: summary.icon)
                            .font(.title3)
                            .foregroundStyle(summary.theme.color(for: colorScheme))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.goalTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(summary.formattedCurrent) / \(summary.formattedTarget) \(summary.unitLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(summary.progress * 100))%")
                            .font(.headline)
                            .foregroundStyle(summary.progress >= 1.0 ? .green : summary.theme.color(for: colorScheme))
                    }
                    
                    // Hourly breakdown rows
                    ForEach(summary.hourlyData) { stat in
                        ActivityGoalHourlyRow(stat: stat, summary: summary)
                    }
                    
                    // Grouped small hours summary
                    if summary.groupedSmallHourCount > 0 {
                        GroupedSmallActivityRow(
                            count: summary.groupedSmallHourCount,
                            totalValue: summary.groupedSmallHourValue,
                            summary: summary
                        )
                    }
                } header: {
                    Text(summary.metric.displayName)
                }
            }
        }
        .refreshable {
            sessionActions.onSyncHealthKit?()
        }
    }

    private var progressSummaryCard: some View {
        let viewModel = progressViewModel
        return VStack(spacing: 20) {
            GradientProgressRing(
                progress: viewModel.dailyProgress,
                gradientColors: [.blue, .cyan],
                animated: true
            )

            // Stats
            HStack(spacing: 30) {
                StatItem(value: "\(viewModel.totalDailyMinutes)", label: "Minutes")
                StatItem(value: "\(viewModel.completedGoalsCount)", label: "Goals Done")
                StatItem(value: "\(viewModel.totalActiveGoals)", label: "Total Goals")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .glassCardStyle(cornerRadius: 16)
    }

    // MARK: - Yesterday Stats Card
    
    private var yesterdayStatsCard: some View {
        let completed = yesterdaySessions.filter { $0.hasMetDailyTarget }
        let skipped = yesterdaySessions.filter { $0.status == .skipped }
        let totalMinutes = Int(yesterdaySessions.reduce(0.0) { $0 + $1.elapsedTime } / 60)
        let total = yesterdaySessions.filter { $0.status == .active && $0.unifiedTargetValue > 0 }.count
        let progress = total > 0 ? Double(completed.count) / Double(total) : 0.0
        
        return VStack(spacing: 20) {
            GradientProgressRing(
                progress: progress,
                gradientColors: [.green, .mint]
            )

            // Stats
            HStack(spacing: 30) {
                StatItem(value: "\(completed.count)", label: "Completed", color: .green)
                StatItem(value: "\(skipped.count)", label: "Skipped", color: .orange)
                StatItem(value: "\(totalMinutes)", label: "Minutes", color: .blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Data Loading
    
    private func loadYesterdayData() async {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day.startDate) else {
            return
        }
        
        let yesterdayID = yesterday.yearMonthDayID(with: calendar)
        
        let descriptor = FetchDescriptor<GoalSession>(
            predicate: #Predicate<GoalSession> { session in
                session.day?.id == yesterdayID
            }
        )
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            await MainActor.run {
                self.yesterdaySessions = sessions
            }
        } catch {
            AppLogger.app.error("Failed to load yesterday's sessions: \(error)")
        }
    }

    private func loadHourlyHealthData() async {
        guard let manager = healthKitManager else { return }
        
        // Collect non-time-based metrics from active goals
        let healthMetrics: [(metric: HealthKitMetric, goalSession: GoalSession)] = sessions.compactMap { gs in
            guard !gs.targetUnit.isTimeBased,
                  gs.status == .active,
                  gs.unifiedTargetValue > 0,
                  let metric = gs.goal?.healthKitMetric else { return nil }
            return (metric: metric, goalSession: gs)
        }
        
        guard !healthMetrics.isEmpty else { return }
        
        // Deduplicate metrics (multiple goals might share a metric)
        let uniqueMetrics = Set(healthMetrics.map(\.metric))
        
        // Fetch today's hourly data
        var todayData: [HealthKitManager.HourlyStatistic] = []
        var yesterdayData: [HealthKitManager.HourlyStatistic] = []
        
        for metric in uniqueMetrics {
            // Today
            do {
                let stats = try await manager.fetchHourlyStatistics(for: metric, on: day.startDate)
                todayData.append(contentsOf: stats)
            } catch {
                AppLogger.healthKit.error("Failed to fetch hourly stats for \(metric.displayName): \(error)")
            }
            
            // Yesterday
            let calendar = Calendar.current
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: day.startDate) {
                do {
                    let stats = try await manager.fetchHourlyStatistics(for: metric, on: yesterday)
                    yesterdayData.append(contentsOf: stats)
                } catch {
                    AppLogger.healthKit.error("Failed to fetch yesterday hourly stats for \(metric.displayName): \(error)")
                }
            }
        }
        
        await MainActor.run {
            self.todayHourlyHealthData = todayData
            self.yesterdayHourlyHealthData = yesterdayData
        }
    }
    
    private static let timeRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private func formatTimeRange(startDate: Date, endDate: Date) -> String {
        let startString = Self.timeRangeFormatter.string(from: startDate)
        let endString = Self.timeRangeFormatter.string(from: endDate)
        return "\(startString) - \(endString)"
    }

}

// MARK: - Plan Session Card

private struct PlanSessionCard: View {
    let session: GoalSession
    let timerManager: SessionTimerManager?
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    let onRemove: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sessionActions) private var sessionActions
    @State private var showingReason = false
    
    private var themeColor: Color {
        session.theme.color(for: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Goal info
                HStack(spacing: 12) {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.goal?.title ?? "Unknown")
                            .font(.headline)
                        
                        Text("\(Int(session.unifiedTargetValue / 60)) min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Recommendation reasons
            if !session.safeRecommendationReasons.isEmpty {
                Button {
                    showingReason.toggle()
                } label: {
                    HStack(spacing: 8) {
                        if let firstReason = session.safeRecommendationReasons.first {
                            Image(systemName: firstReason.icon)
                                .font(.caption)
                            
                            Text(firstReason.displayName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        
                        if session.safeRecommendationReasons.count > 1 {
                            Text("+\(session.safeRecommendationReasons.count - 1)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: showingReason ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                if showingReason {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.safeRecommendationReasons, id: \.self) { reason in
                            HStack(spacing: 8) {
                                Image(systemName: reason.icon)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(reason.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // Quick action buttons
            HStack(spacing: 12) {
                Button {
                    HapticFeedbackManager.trigger(.medium)
                    if let day = session.day {
                        timerManager?.toggleTimer(for: session, in: day)
                    }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                
                Button {
                    HapticFeedbackManager.trigger(.light)
                    sessionActions.onSkip(session)
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Reusable Components

private struct GradientProgressRing: View {
    let progress: Double
    let gradientColors: [Color]
    var size: CGFloat = 120
    var animated: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: LayoutConstants.ProgressCircle.standardLineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: LayoutConstants.ProgressCircle.standardLineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(animated ? AnimationPresets.slowSpring : nil, value: progress)
            
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(progress * 100)) percent complete")
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    var color: Color? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color ?? .primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Hourly Activity Bar Chart

/// A data point for one goal's contribution within a single hour.
private struct HourlyActivityEntry: Identifiable {
    let id = UUID()
    let hour: Int
    let goalTitle: String
    let minutes: Double
    let themePreset: ThemePreset
}

/// Builds hourly activity data from historical sessions and HealthKit hourly stats.
/// Time-based goals are bucketed from HistoricalSession timestamps.
/// Non-time-based goals (steps, calories) use real hourly HealthKit data when available.
private func buildHourlyActivityData(
    from historicalSessions: [HistoricalSession],
    goalSessions: [GoalSession],
    hourlyHealthData: [HealthKitManager.HourlyStatistic]
) -> [HourlyActivityEntry] {
    let calendar = Calendar.current
    var entries: [HourlyActivityEntry] = []
    
    // Build a lookup from goalID -> GoalSession for theme/title resolution
    var goalSessionByID: [String: GoalSession] = [:]
    for gs in goalSessions {
        if !gs.goalID.isEmpty {
            goalSessionByID[gs.goalID] = gs
        }
    }
    
    // 1. Time-based goals: bucket historical sessions into hours
    for historical in historicalSessions {
        let start = historical.startDate
        let end = historical.endDate
        guard end > start else { continue }
        
        let goalSession = historical.goalIDs.compactMap({ goalSessionByID[$0] }).first
        let theme = goalSession?.theme ?? ThemeStore.defaultPreset
        let title = goalSession?.goal?.title ?? historical.title
        
        var cursor = start
        while cursor < end {
            let hour = calendar.component(.hour, from: cursor)
            let currentHourStart = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: cursor))!
            let nextHourStart = calendar.date(byAdding: .hour, value: 1, to: currentHourStart)!
            let bucketEnd = min(nextHourStart, end)
            
            let minutes = bucketEnd.timeIntervalSince(cursor) / 60
            if minutes > 0.1 {
                entries.append(HourlyActivityEntry(
                    hour: hour,
                    goalTitle: title,
                    minutes: minutes,
                    themePreset: theme
                ))
            }
            
            cursor = bucketEnd
        }
    }
    
    // 2. Non-time-based goals: use real hourly HealthKit data
    // Group hourly stats by metric, then match to goal sessions
    let statsByMetric = Dictionary(grouping: hourlyHealthData, by: \.metric)
    
    for gs in goalSessions {
        guard !gs.targetUnit.isTimeBased,
              gs.status == .active,
              gs.unifiedTargetValue > 0,
              let metric = gs.goal?.healthKitMetric else { continue }
        
        let title = gs.goal?.title ?? "Activity"
        let theme = gs.theme
        
        guard let hourlyStats = statsByMetric[metric] else { continue }
        
        for stat in hourlyStats {
            // Scale the value relative to the target so bars are visually comparable
            // A full target maps to 60 min equivalent height
            let proportion = min(stat.value / gs.unifiedTargetValue, 1.0)
            let equivalentMinutes = proportion * 60.0
            
            if equivalentMinutes > 0.1 {
                entries.append(HourlyActivityEntry(
                    hour: stat.hour,
                    goalTitle: title,
                    minutes: equivalentMinutes,
                    themePreset: theme
                ))
            }
        }
    }
    
    return entries
}

private struct HourlyActivityChart: View {
    let entries: [HourlyActivityEntry]
    @Environment(\.colorScheme) private var colorScheme
    
    // Aggregate entries by (hour, goalTitle) so each bar segment is one goal per hour
    private var aggregatedEntries: [HourlyActivityEntry] {
        var dict: [String: (minutes: Double, theme: ThemePreset)] = [:]
        var order: [(hour: Int, goalTitle: String)] = []
        
        for entry in entries {
            let key = "\(entry.hour)-\(entry.goalTitle)"
            if dict[key] != nil {
                dict[key]!.minutes += entry.minutes
            } else {
                dict[key] = (minutes: entry.minutes, theme: entry.themePreset)
                order.append((hour: entry.hour, goalTitle: entry.goalTitle))
            }
        }
        
        return order.map { item in
            let key = "\(item.hour)-\(item.goalTitle)"
            let data = dict[key]!
            return HourlyActivityEntry(
                hour: item.hour,
                goalTitle: item.goalTitle,
                minutes: data.minutes,
                themePreset: data.theme
            )
        }
    }
    
    // Unique goal titles in the order they first appear, for consistent stacking
    private var goalTitles: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in entries {
            if seen.insert(entry.goalTitle).inserted {
                result.append(entry.goalTitle)
            }
        }
        return result
    }
    
    // Map goal titles to their theme color
    private var goalColors: [String: Color] {
        var colors: [String: Color] = [:]
        for entry in entries {
            if colors[entry.goalTitle] == nil {
                colors[entry.goalTitle] = entry.themePreset.color(for: colorScheme)
            }
        }
        return colors
    }
    
    // Map goal titles to their theme gradient
    private var goalGradients: [String: LinearGradient] {
        var gradients: [String: LinearGradient] = [:]
        for entry in entries {
            if gradients[entry.goalTitle] == nil {
                gradients[entry.goalTitle] = entry.themePreset.gradient(for: colorScheme)
            }
        }
        return gradients
    }
    
    private var totalMinutes: Int {
        Int(entries.reduce(0) { $0 + $1.minutes })
    }
    
    private var activeHours: Int {
        Set(entries.map(\.hour)).count
    }
    
    private var maxHourlyTotal: Double {
        let totals = Dictionary(grouping: aggregatedEntries, by: \.hour)
            .mapValues { $0.reduce(0) { $0 + $1.minutes } }
        return totals.values.max() ?? 60
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            HStack(alignment: .center, spacing: 16) {
                // Chart icon
                ZStack {
                    Circle()
                        .fill(.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("\(totalMinutes)")
                                .fontWeight(.semibold)
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("·")
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 4) {
                            Text("\(activeHours)")
                                .fontWeight(.semibold)
                            Text(activeHours == 1 ? "hour" : "hours")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("·")
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 4) {
                            Text("\(goalTitles.count)")
                                .fontWeight(.semibold)
                            Text(goalTitles.count == 1 ? "goal" : "goals")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
                .opacity(0.5)
            
            // Chart
            VStack(alignment: .leading, spacing: 12) {
                Chart(aggregatedEntries) { entry in
                    BarMark(
                        x: .value("Hour", entry.hour),
                        y: .value("Minutes", entry.minutes)
                    )
                    .foregroundStyle(entry.themePreset.gradient(for: colorScheme))
                }
                .chartYScale(domain: 0...(max(maxHourlyTotal, 1) * 1.2))
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(hourLabel(hour))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes))m")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(.quaternary)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 160)
                
                // Legend
                FlowLayout(spacing: 8) {
                    ForEach(goalTitles, id: \.self) { title in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(goalColors[title] ?? .gray)
                                .frame(width: 10, height: 10)
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding()
        }
        .glassCardStyle(cornerRadius: 16)
    }
    
    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 6: return "6a"
        case 12: return "12p"
        case 18: return "6p"
        case 23: return "11p"
        default: return "\(hour)"
        }
    }
}

// MARK: - Grouped Hour Sessions

/// Groups historical sessions for an hour, separating significant sessions from tiny ones
private struct GroupedHourSessions {
    let startDate: Date
    let endDate: Date
    let sessions: [HistoricalSession]
    let groupedSmallSessionCount: Int
    let groupedSmallSessionDuration: TimeInterval
    
    var hasGroupedSessions: Bool { groupedSmallSessionCount > 0 }
}

// MARK: - Grouped Small Sessions Row

private struct GroupedSmallSessionsRow: View {
    let count: Int
    let totalDuration: TimeInterval
    
    private var formattedDuration: String {
        let seconds = Int(totalDuration)
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(seconds)s"
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ellipsis.circle")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Text("\(count) brief \(count == 1 ? "session" : "sessions") · \(formattedDuration) total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Grouped Small Activity Row

private struct GroupedSmallActivityRow: View {
    let count: Int
    let totalValue: Double
    let summary: ActivityGoalSummary
    
    private var formattedValue: String {
        let value = Int(totalValue)
        switch summary.targetUnit {
        case .steps: return value.formatted()
        case .kilocalories: return "\(value)"
        case .seconds: return "\(value)"
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ellipsis.circle")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Text("\(count) other \(count == 1 ? "hour" : "hours") · \(formattedValue) \(summary.unitLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Activity Goal Summary Model

private struct ActivityGoalSummary: Identifiable {
    let id = UUID()
    let goalTitle: String
    let metric: HealthKitMetric
    let targetUnit: Goal.TargetUnit
    let currentValue: Double
    let targetValue: Double
    let theme: ThemePreset
    let hourlyData: [HealthKitManager.HourlyStatistic]
    /// Number of hours with negligible values that were grouped
    let groupedSmallHourCount: Int
    /// Total value across all grouped small hours
    let groupedSmallHourValue: Double
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
    
    var formattedCurrent: String {
        let value = Int(currentValue)
        switch targetUnit {
        case .steps: return value.formatted()
        case .kilocalories: return "\(value)"
        case .seconds: return "\(value)"
        }
    }
    
    var formattedTarget: String {
        let value = Int(targetValue)
        switch targetUnit {
        case .steps: return value.formatted()
        case .kilocalories: return "\(value)"
        case .seconds: return "\(value)"
        }
    }
    
    var unitLabel: String { targetUnit.label }
    
    var icon: String { metric.symbolName }
}

// MARK: - Activity Goal Hourly Row

private struct ActivityGoalHourlyRow: View {
    let stat: HealthKitManager.HourlyStatistic
    let summary: ActivityGoalSummary
    @Environment(\.colorScheme) private var colorScheme
    
    private var formattedValue: String {
        let value = Int(stat.value)
        switch summary.targetUnit {
        case .steps: return value.formatted()
        case .kilocalories: return "\(value)"
        case .seconds: return "\(value)"
        }
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var calendar = Calendar.current
        calendar.timeZone = .current
        let date = calendar.date(bySettingHour: stat.hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(hourString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(summary.theme.color(for: colorScheme))
                .frame(width: 3, height: 20)
            
            Text("\(formattedValue) \(summary.unitLabel)")
                .font(.subheadline)
            
            Spacer()
        }
    }
}

/// Simple flow layout that wraps content to the next line when it runs out of horizontal space.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
