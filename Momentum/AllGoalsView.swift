//
//  AllGoalsView.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct AllGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let goals: [Goal]
    var timerManager: SessionTimerManager?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var goalToDelete: Goal?
    @State private var showingDeleteConfirmation = false
    @State private var selectedGoal: Goal?
    @AppStorage("weekStartDay") private var weekStartDay: Int = Calendar.current.firstWeekday
    
    var activeGoals: [Goal] {
        goals.filter { $0.status == .active }
    }
    
    var archivedGoals: [Goal] {
        goals.filter { $0.status == .archived }
    }
    
    // MARK: - Stats
    
    private var totalDailyTarget: TimeInterval {
        activeGoals.reduce(0) { $0 + $1.unifiedWeeklyTarget / 7 }
    }
    
    private var daysActiveThisWeek: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartDay
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return 0 }
        
        let scheduledCount = activeGoals.isEmpty ? 0 : (0..<7).filter { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return false }
            let weekday = calendar.component(.weekday, from: date)
            return activeGoals.contains { $0.isScheduledDay(weekday) }
        }.count
        return scheduledCount
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerView
                    
                    // Stats row
                    statsRow
                    
                    // Active goals
                    if !activeGoals.isEmpty {
                        sectionHeader(title: "ACTIVE", count: activeGoals.count)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(activeGoals.sorted { $0.title < $1.title }) { goal in
                                Button {
                                    selectedGoal = goal
                                } label: {
                                    GoalCardView(goal: goal)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        goalToDelete = goal
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    // Archived goals
                    if !archivedGoals.isEmpty {
                        sectionHeader(title: "ARCHIVED", count: archivedGoals.count)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(archivedGoals.sorted { $0.title < $1.title }) { goal in
                                Button {
                                    selectedGoal = goal
                                } label: {
                                    GoalCardView(goal: goal)
                                        .opacity(0.7)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        goalToDelete = goal
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    if goals.isEmpty {
                        ContentUnavailableView(
                            "No Goals",
                            systemImage: "target",
                            description: Text("Create your first goal to get started")
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("YOUR GOALS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete Goal",
                isPresented: $showingDeleteConfirmation,
                presenting: goalToDelete
            ) { goal in
                Button("Delete \"\(goal.title)\"", role: .destructive) {
                    deleteGoal(goal)
                }
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
            } message: { goal in
                Text("Are you sure you want to delete \"\(goal.title)\"? This action cannot be undone.")
            }
            .navigationDestination(item: $selectedGoal) { goal in
                GoalSessionDetailView(goal: goal, timerManager: timerManager)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .bottom) {
            Text("All goals")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            statCapsule(value: "\(activeGoals.count)", label: "ACTIVE")
            statCapsule(value: totalDailyTarget.formatted(style: .hourMinute), label: "DAILY GOAL")
            statCapsule(value: "\(daysActiveThisWeek)/7", label: "DAYS ACTIVE")
        }
    }
    
    private func statCapsule(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
    }
    
    private func deleteGoal(_ goal: Goal) {
        withAnimation {
            GoalManager.delete(goal, from: modelContext)
            goalToDelete = nil
        }
    }
}

// MARK: - Goal Card View

struct GoalCardView: View {
    let goal: Goal
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("weekStartDay") private var weekStartDay: Int = Calendar.current.firstWeekday
    @Query private var weekDays: [Day]
    @Query private var lastWeekDays: [Day]
    
    init(goal: Goal) {
        self.goal = goal
        
        var calendar = Calendar.current
        let storedWeekStartDay = UserDefaults.standard.integer(forKey: "weekStartDay")
        calendar.firstWeekday = storedWeekStartDay == 0 ? Calendar.current.firstWeekday : storedWeekStartDay
        
        let today = Date()
        
        // This week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            _weekDays = Query(filter: #Predicate<Day> { _ in false })
            _lastWeekDays = Query(filter: #Predicate<Day> { _ in false })
            return
        }
        
        let startID = startOfWeek.yearMonthDayID(with: calendar)
        let endID = endOfWeek.yearMonthDayID(with: calendar)
        
        _weekDays = Query(
            filter: #Predicate<Day> { day in
                day.id >= startID && day.id <= endID
            },
            sort: \.id
        )
        
        // Last week
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: startOfWeek),
              let lastWeekEnd = calendar.date(byAdding: .day, value: -1, to: startOfWeek) else {
            _lastWeekDays = Query(filter: #Predicate<Day> { _ in false })
            return
        }
        
        let lastStartID = lastWeekStart.yearMonthDayID(with: calendar)
        let lastEndID = lastWeekEnd.yearMonthDayID(with: calendar)
        
        _lastWeekDays = Query(
            filter: #Predicate<Day> { day in
                day.id >= lastStartID && day.id <= lastEndID
            },
            sort: \.id
        )
    }
    
    private var theme: ThemePreset { goal.resolvedTheme }
    private var foreground: Color { theme.foregroundColor(for: colorScheme) }
    
    private var thisWeekElapsed: TimeInterval {
        weekDays.reduce(0.0) { total, day in
            guard let sessions = day.sessions,
                  let session = sessions.first(where: { $0.goal?.id == goal.id }) else { return total }
            return total + session.elapsedTime
        }
    }
    
    private var lastWeekElapsed: TimeInterval {
        lastWeekDays.reduce(0.0) { total, day in
            guard let sessions = day.sessions,
                  let session = sessions.first(where: { $0.goal?.id == goal.id }) else { return total }
            return total + session.elapsedTime
        }
    }
    
    private var vsLastWeekPercent: Int? {
        guard lastWeekElapsed >= 60, thisWeekElapsed >= 60 else { return nil }
        let diff = thisWeekElapsed - lastWeekElapsed
        let pct = Int((diff / lastWeekElapsed) * 100)
        guard pct != 0 else { return nil }
        return pct
    }
    
    private var frequencyLabel: String {
        let tagTitle = goal.primaryTag?.title.uppercased() ?? ""
        let schedule: String
        if goal.hasSchedule {
            let count = goal.scheduledWeekdays.count
            schedule = count == 7 ? "EVERY DAY" : "\(count)× / WEEK"
        } else {
            schedule = "EVERY DAY"
        }
        return tagTitle.isEmpty ? schedule : "\(tagTitle) · \(schedule)"
    }
    
    // Daily data for bar chart
    private var dailyData: [(day: String, progress: TimeInterval, date: Date)] {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartDay
        
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        
        let daysByID = Dictionary(weekDays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        
        return (0..<7).map { dayOffset -> (String, TimeInterval, Date) in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                return ("", 0, Date())
            }
            
            let dayID = date.yearMonthDayID(with: calendar)
            let session = daysByID[dayID]?.sessions?.first(where: { $0.goal?.id == goal.id })
            let totalProgress: TimeInterval = session?.elapsedTime ?? 0
            let weekdaySymbol = calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            
            return (weekdaySymbol, totalProgress, date)
        }
    }
    
    private var dailyTarget: TimeInterval {
        goal.unifiedWeeklyTarget / 7
    }
    
    private var maxBarValue: TimeInterval {
        max(dailyData.map { $0.progress }.max() ?? 0, dailyTarget)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Title + vs last week
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(foreground)
                    
                    Text(frequencyLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(foreground.opacity(0.6))
                }
                
                Spacer()
                
                if let pct = vsLastWeekPercent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(pct > 0 ? "↑" : "↓") \(abs(pct)) %")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(foreground.opacity(0.7))
                        Text("VS LAST WEEK")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(foreground.opacity(0.45))
                    }
                }
            }
            
            // Row 2: Weekly time
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(thisWeekElapsed.formatted(style: .hourMinute))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
                
                Text("THIS WEEK")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(foreground.opacity(0.5))
            }
            
            // Row 3: Bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(dailyData.enumerated()), id: \.offset) { _, data in
                    VStack(spacing: 3) {
                        let height: CGFloat = maxBarValue > 0 ? CGFloat(data.progress / maxBarValue) * 32 : 0
                        let isToday = Calendar.current.isDateInToday(data.date)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: data.progress))
                            .frame(height: max(height, 3))
                        
                        Text(data.day)
                            .font(.system(size: 9, weight: isToday ? .bold : .regular))
                            .foregroundStyle(foreground.opacity(isToday ? 0.8 : 0.45))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
        }
        .padding(20)
        .background(
            theme.gradient(for: colorScheme)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
    }
    
    private func barColor(for progress: TimeInterval) -> Color {
        if progress >= dailyTarget {
            return foreground.opacity(0.85)
        } else if progress > 0 {
            return foreground.opacity(0.45)
        } else {
            return foreground.opacity(0.12)
        }
    }
}
