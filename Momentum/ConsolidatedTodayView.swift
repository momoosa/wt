import SwiftUI
import SwiftData
import MomentumKit

/// Experimental consolidated view combining DayOverview + DailyPlanner
/// Shows both deterministic and AI recommendations in a unified interface
struct ConsolidatedTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [Goal]
    
    private var activeGoals: [Goal] {
        allGoals.filter { $0.status == .active }
    }
    
    @Query private var allGoalSessions: [GoalSession]
    
    @StateObject private var permissionsHandler = PermissionsHandler()
    @StateObject private var planner = GoalSessionPlanner()
    
    @State private var selectedTab: PlanningMode = .today
    @State private var showingPlannerConfig = false
    @State private var isGeneratingPlan = false
    @State private var aiGeneratedPlan: [(goal: Goal, duration: TimeInterval, reason: String)] = []
    @State private var selectedDate = Date()
    @State private var weekDates: [Date] = []
    
    enum PlanningMode: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case goals = "Goals"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Planning Mode", selection: $selectedTab) {
                    ForEach(PlanningMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .today:
                            todayView
                        case .week:
                            weekProgressView
                        case .goals:
                            goalsListView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingPlannerConfig = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingPlannerConfig) {
                NavigationStack {
                    Text("Planner Configuration")
                        .navigationTitle("Settings")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingPlannerConfig = false
                                }
                            }
                        }
                }
            }
            .task {
                setupWeekDates()
            }
        }
    }
    
    // MARK: - Today View (Combined)
    
    private var todayView: some View {
        VStack(spacing: 16) {
            // Context Cards
            contextCardsSection
            
            // Main Recommendations
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Recommended Now")
                        .font(.headline)
                    Spacer()
                    
                    // Show AI button if we have AI suggestions
                    if !aiGeneratedPlan.isEmpty || isGeneratingPlan {
                        Button {
                            Task {
                                await generateAIPlan()
                            }
                        } label: {
                            if isGeneratingPlan {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isGeneratingPlan)
                    }
                }
                
                // Show AI plan if available, otherwise quick recommendations
                if !aiGeneratedPlan.isEmpty {
                    ForEach(Array(aiGeneratedPlan.enumerated()), id: \.offset) { index, item in
                        recommendationRow(
                            goal: item.goal,
                            duration: item.duration,
                            reason: item.reason
                        )
                    }
                    
                    // Option to try AI suggestions
                    Button {
                        aiGeneratedPlan = []
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Show Quick Suggestions Instead")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    let recommendations = getQuickRecommendations()
                    
                    if recommendations.isEmpty {
                        emptyRecommendationsCard
                    } else {
                        ForEach(recommendations, id: \.goal.id) { item in
                            recommendationRow(
                                goal: item.goal,
                                duration: nil,
                                reason: item.reason
                            )
                        }
                        
                        // Option to try AI suggestions
                        Button {
                            Task {
                                await generateAIPlan()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Get AI Suggestions")
                            }
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
    
    // MARK: - Goals List View
    
    private var goalsListView: some View {
        VStack(spacing: 16) {
            // Summary Card
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(activeGoals.count)")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    Text("Active Goals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalWeeklyTargetHours)")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    Text("Hours/Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Goals grouped by tag
            let groupedGoals = Dictionary(grouping: activeGoals) { goal in
                goal.primaryTag?.title ?? "Other"
            }
            
            ForEach(groupedGoals.keys.sorted(), id: \.self) { tagName in
                if let goals = groupedGoals[tagName] {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tagName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        ForEach(goals.sorted(by: { $0.title < $1.title })) { goal in
                            goalCard(goal)
                        }
                    }
                }
            }
        }
    }
    
    private func goalCard(_ goal: Goal) -> some View {
        let themePreset = goal.primaryTag?.themePreset ?? themePresets[0]
        let weeklyProgress = calculateWeeklyProgress(for: goal)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        if goal.hasSchedule {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(scheduleText(for: goal))
                                .font(.caption)
                        }
                        
                        if let metric = goal.healthKitMetric, goal.healthKitSyncEnabled {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.pink)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(goal.weeklyTarget.formatted())
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("per week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themePreset.gradient)
                        .frame(width: geometry.size.width * min(weeklyProgress, 1.0), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(Int(weeklyProgress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    // Start session
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Week Progress View
    
    private var weekProgressView: some View {
        VStack(spacing: 16) {
            // Week Navigation
            HStack {
                Button {
                    moveWeek(by: -7)
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(weekRangeText)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    moveWeek(by: 7)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Daily Progress Cards
            ForEach(weekDates, id: \.self) { date in
                dayProgressCard(for: date)
            }
        }
    }
    
    // MARK: - Context Cards
    
    private var contextCardsSection: some View {
        HStack(spacing: 12) {

            
            // Calendar Availability Card
            if permissionsHandler.calendarAccessGranted {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.blue)
                        Text("Schedule")
                            .font(.caption)
                    }
                    Text(availabilitySummary)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Active Goals Card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.green)
                    Text("Active")
                        .font(.caption)
                }
                Text("\(activeGoalsCount)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var emptyRecommendationsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("All caught up!")
                .font(.headline)
            Text("No urgent goals right now")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    

    private func dayProgressCard(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let dayProgress = calculateDayProgress(for: date)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                        .foregroundStyle(isToday ? .blue : .primary)
                    Text(date.formatted(.dateTime.month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dayProgress.totalTime.formatted())
                        .font(.headline)
                    Text("\(dayProgress.sessionsCount) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if dayProgress.goalDetails.isEmpty {
                Text("No sessions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ForEach(dayProgress.goalDetails, id: \.goalTitle) { detail in
                    HStack {
                        Circle()
                            .fill(detail.gradient)
                            .frame(width: 8, height: 8)
                        Text(detail.goalTitle)
                            .font(.caption)
                        Spacer()
                        Text(detail.duration.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(isToday ? Color.accentColor.opacity(0.05) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Helper Methods
    
    private func recommendationRow(goal: Goal, duration: TimeInterval?, reason: String) -> some View {
        let themePreset = goal.primaryTag?.themePreset ?? themePresets[0]
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(themePreset.gradient)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let duration = duration {
                    Text(duration.formatted())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                // Start session action - would integrate with timer manager
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func getQuickRecommendations() -> [(goal: Goal, reason: String)] {
        let context = DeterministicRecommender.Context(
            currentDate: Date(),
            weather: nil,
            temperature: nil,
            weekdayAvailability: nil
        )
        
        let recommendations = DeterministicRecommender().recommend(
            goals: activeGoals,
            sessions: allGoalSessions,
            context: context,
            limit: 5
        )
        
        return recommendations.map { recommendation in
            (goal: recommendation.goal, reason: recommendation.reasons.first?.displayName ?? "Recommended")
        }
    }
    
    private func generateAIPlan() async {
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }
        
        do {
            let result = try await planner.generateDailyPlan(
                for: activeGoals,
                goalSessions: allGoalSessions,
                currentDate: Date()
            )
            
            aiGeneratedPlan = result.sessions.compactMap { session in
                guard let goal = activeGoals.first(where: { $0.id.uuidString == session.id }) else {
                    return nil
                }
                let duration = TimeInterval(session.suggestedDuration * 60) // Convert minutes to seconds
                return (goal: goal, duration: duration, reason: session.reasoning)
            }
        } catch {
            print("Failed to generate AI plan: \(error)")
        }
    }
    
    private func setupWeekDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        
        guard let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else {
            return
        }
        
        weekDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: sunday)
        }
    }
    
    private func moveWeek(by days: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            setupWeekDates()
        }
    }
    
    private var weekRangeText: String {
        guard let first = weekDates.first, let last = weekDates.last else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
    
    private var availabilitySummary: String {
        // Placeholder - would integrate with CalendarAvailabilityManager
        "2.5 hrs"
    }
    
    private var activeGoalsCount: Int {
        activeGoals.count
    }
    
    private var totalWeeklyTargetHours: String {
        let totalSeconds = activeGoals.reduce(0.0) { $0 + $1.weeklyTarget }
        let hours = totalSeconds / 3600
        return String(format: "%.1f", hours)
    }
    
    private func calculateWeeklyProgress(for goal: Goal) -> Double {
        // For now, return a placeholder - would need to calculate actual progress
        // from sessions in the current week
        return 0.0
    }
    
    private func scheduleText(for goal: Goal) -> String {
        let weekdays = goal.scheduledWeekdays.sorted()
        if weekdays.isEmpty {
            return "Anytime"
        }
        
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if weekdays.count == 7 {
            return "Every day"
        } else if weekdays.count <= 3 {
            return weekdays.map { dayNames[$0 - 1] }.joined(separator: ", ")
        } else {
            return "\(weekdays.count) days/week"
        }
    }
    
    private func calculateDayProgress(for date: Date) -> DayProgress {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        // For now, return empty progress - would need proper day/session relationship
        return DayProgress(
            totalTime: 0,
            sessionsCount: 0,
            goalDetails: []
        )
    }
}

// MARK: - Supporting Types

struct DayProgress {
    let totalTime: TimeInterval
    let sessionsCount: Int
    let goalDetails: [GoalDetail]
}

struct GoalDetail: Hashable {
    let goalTitle: String
    let duration: TimeInterval
    let gradient: AnyGradient
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(goalTitle)
        hasher.combine(duration)
    }
    
    static func == (lhs: GoalDetail, rhs: GoalDetail) -> Bool {
        lhs.goalTitle == rhs.goalTitle && lhs.duration == rhs.duration
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Goal.self, GoalSession.self, configurations: config)
    
    return ConsolidatedTodayView()
        .modelContainer(container)
}
