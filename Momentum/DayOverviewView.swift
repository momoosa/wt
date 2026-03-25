import SwiftUI
import SwiftData
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
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    let onSkip: (GoalSession) -> Void
    let onSyncHealthKit: (() -> Void)?
    let isSyncingHealthKit: Bool
    
    @State private var selectedTab: DayTab = .today
    @State private var yesterdaySessions: [GoalSession] = []
    @State private var removedSessionIDs: Set<String> = []

    private var progressViewModel: DailyProgressViewModel {
        DailyProgressViewModel(sessions: sessions)
    }
    
    enum DayTab: String, CaseIterable {
        case yesterday = "Yesterday"
        case today = "Today"
    }

    // Get all historical sessions from all goals, grouped by hour with time ranges
    private var groupedHistoricalSessions: [(startDate: Date, endDate: Date, sessions: [HistoricalSession])] {
        let allHistoricalSessions = sessions.flatMap { $0.historicalSessions }
        let calendar = Calendar.current

        // Group by hour
        let grouped = Dictionary(grouping: allHistoricalSessions) { session -> Int in
            calendar.component(.hour, from: session.startDate)
        }

        // Sort by hour (numerically) and calculate time ranges
        return grouped.sorted { $0.key < $1.key }
            .map { hour, sessions in
                let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
                
                // Find the earliest start and latest end time in this hour group
                let earliestStartDate = sortedSessions.map { $0.startDate }.min() ?? Date()
                let latestEndDate = sortedSessions.map { $0.endDate }.max() ?? Date()
                
                return (startDate: earliestStartDate, endDate: latestEndDate, sessions: sortedSessions)
            }
    }
    
    // MARK: - Plan View Helpers
    
    private var recommendedSessions: [GoalSession] {
        sessions.filter { session in
            session.status == .active && 
            session.plannedPriority != nil &&
            session.dailyTarget > 0 &&
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
        Int(orderedRecommendedSessions.reduce(0.0) { $0 + $1.dailyTarget } / 60)
    }
    
    // MARK: - Yesterday Helpers
    
    private var yesterdayGroupedSessions: [(startDate: Date, endDate: Date, sessions: [HistoricalSession])] {
        let allHistoricalSessions = yesterdaySessions.flatMap { $0.historicalSessions }
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: allHistoricalSessions) { session -> Int in
            calendar.component(.hour, from: session.startDate)
        }

        return grouped.sorted { $0.key < $1.key }
            .map { hour, sessions in
                let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
                let earliestStartDate = sortedSessions.map { $0.startDate }.min() ?? Date()
                let latestEndDate = sortedSessions.map { $0.endDate }.max() ?? Date()
                return (startDate: earliestStartDate, endDate: latestEndDate, sessions: sortedSessions)
            }
    }
    
    private var yesterdayInsights: [String] {
        var insights: [String] = []
        
        let completed = yesterdaySessions.filter { $0.hasMetDailyTarget }
        let total = yesterdaySessions.filter { $0.status == .active && $0.dailyTarget > 0 }
        
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
                        } header: {
                            Text(formatTimeRange(startDate: group.startDate, endDate: group.endDate))
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("No Data", systemImage: "calendar")
                    } description: {
                        Text("Yesterday's activity will appear here")
                    }
                    .frame(minHeight: 300)
                }
                .listRowBackground(Color.clear)
            }
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
            
            // Today's Plan
            if !recommendedSessions.isEmpty {
                Section {
                    ForEach(orderedRecommendedSessions) { session in
                        PlanSessionCard(
                            session: session,
                            timerManager: timerManager,
                            selectedSession: $selectedSession,
                            sessionToLogManually: $sessionToLogManually,
                            onSkip: onSkip,
                            onSyncHealthKit: onSyncHealthKit,
                            isSyncingHealthKit: isSyncingHealthKit,
                            onRemove: {
                                withAnimation {
                                    _ = removedSessionIDs.insert(session.id.uuidString)
                                }
                            }
                        )
                    }
                } header: {
                    Text("Today's Plan (\(totalPlannedMinutes) min)")
                }
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
                    } header: {
                        Text(formatTimeRange(startDate: group.startDate, endDate: group.endDate))
                    }
                }
            } else if recommendedSessions.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Activity Yet", systemImage: "clock")
                    } description: {
                        Text("Start tracking your goals to see your progress here")
                    }
                    .frame(minHeight: 300)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var progressSummaryCard: some View {
        let viewModel = progressViewModel
        return VStack(spacing: 20) {
            // Large circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: LayoutConstants.ProgressCircle.standardLineWidth)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.dailyProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: LayoutConstants.ProgressCircle.standardLineWidth, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(AnimationPresets.slowSpring, value: viewModel.dailyProgress)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.dailyProgress * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("\(viewModel.totalDailyMinutes)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(viewModel.completedGoalsCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Goals Done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(viewModel.totalActiveGoals)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Total Goals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Yesterday Stats Card
    
    private var yesterdayStatsCard: some View {
        let completed = yesterdaySessions.filter { $0.hasMetDailyTarget }
        let skipped = yesterdaySessions.filter { $0.status == .skipped }
        let totalMinutes = Int(yesterdaySessions.reduce(0.0) { $0 + $1.elapsedTime } / 60)
        
        return VStack(spacing: 20) {
            // Large circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: LayoutConstants.ProgressCircle.standardLineWidth)
                    .frame(width: 120, height: 120)

                let total = yesterdaySessions.filter { $0.status == .active && $0.dailyTarget > 0 }.count
                let progress = total > 0 ? Double(completed.count) / Double(total) : 0.0
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: LayoutConstants.ProgressCircle.standardLineWidth, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("\(completed.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(skipped.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text("Skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(totalMinutes)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    Text("Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private func formatTimeRange(startDate: Date, endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        return "\(startString) - \(endString)"
    }

}

// MARK: - Plan Session Card

private struct PlanSessionCard: View {
    let session: GoalSession
    let timerManager: SessionTimerManager?
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    let onSkip: (GoalSession) -> Void
    let onSyncHealthKit: (() -> Void)?
    let isSyncingHealthKit: Bool
    let onRemove: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingReason = false
    
    private var themeColor: Color {
        session.themeNeon
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
                        
                        Text("\(Int(session.dailyTarget / 60)) min")
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
            if !session.recommendationReasons.isEmpty {
                Button {
                    showingReason.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: session.recommendationReasons.first!.icon)
                            .font(.caption)
                        
                        Text(session.recommendationReasons.first!.displayName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        if session.recommendationReasons.count > 1 {
                            Text("+\(session.recommendationReasons.count - 1)")
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
                        ForEach(session.recommendationReasons, id: \.self) { reason in
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
                    timerManager?.toggleTimer(for: session, in: session.day!)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                
                Button {
                    onSkip(session)
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
