//
//  WeeklyRecapView.swift
//  Momentum
//
//  Weekly recap showing total focused time, streaks, and per-goal breakdown.
//

import SwiftUI
import SwiftData
import MomentumKit

struct WeeklyRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("weekStartDay") private var weekStartDay: Int = Calendar.current.firstWeekday
    
    @Query(sort: \Goal.title) private var goals: [Goal]
    @Query private var allSessions: [GoalSession]
    @Query private var allDays: [Day]
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartDay
        return cal
    }
    
    // MARK: - Week Date Range
    
    private var weekStart: Date {
        Date().startOfWeek(in: calendar) ?? calendar.startOfDay(for: Date())
    }
    
    private var weekEnd: Date {
        Date().endOfWeek(in: calendar) ?? Date()
    }
    
    private var previousWeekStart: Date {
        calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
    }
    
    private var weekDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: weekEnd)
        return "\(start) – \(end)"
    }
    
    // MARK: - Computed Data
    
    /// Sessions grouped by day ID for the current week
    private var weekSessions: [GoalSession] {
        let dayIDs = dayIDsForWeek(starting: weekStart)
        return allSessions.filter { session in
            guard let dayID = session.day?.id else { return false }
            guard session.goal?.status != .archived else { return false }
            return dayIDs.contains(dayID)
        }
    }
    
    private var previousWeekSessions: [GoalSession] {
        let dayIDs = dayIDsForWeek(starting: previousWeekStart)
        return allSessions.filter { session in
            guard let dayID = session.day?.id else { return false }
            guard session.goal?.status != .archived else { return false }
            return dayIDs.contains(dayID)
        }
    }
    
    /// Total focused time this week (seconds)
    private var totalFocusedTime: TimeInterval {
        weekSessions.reduce(0) { $0 + $1.elapsedTime }
    }
    
    private var previousWeekTotalTime: TimeInterval {
        previousWeekSessions.reduce(0) { $0 + $1.elapsedTime }
    }
    
    /// Change vs last week
    private var weekOverWeekDelta: TimeInterval {
        totalFocusedTime - previousWeekTotalTime
    }
    
    /// Per-day totals for the bar chart (7 entries, Mon-Sun or Sun-Sat)
    private var dailyTotals: [(label: String, seconds: TimeInterval, isFuture: Bool)] {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return (label: "?", seconds: 0, isFuture: false)
            }
            let dayID = date.yearMonthDayID(with: calendar)
            let weekday = calendar.component(.weekday, from: date)
            let total = weekSessions
                .filter { $0.day?.id == dayID }
                .reduce(0.0) { $0 + $1.elapsedTime }
            let isFuture = date > today
            return (label: dayLabels[weekday - 1], seconds: total, isFuture: isFuture)
        }
    }
    
    /// Longest streak of consecutive days with at least one completed session
    private var longestStreak: (days: Int, goalTitle: String) {
        var best = (days: 0, goalTitle: "")
        
        for goal in activeGoals {
            var streak = 0
            var maxStreak = 0
            
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                let dayID = date.yearMonthDayID(with: calendar)
                let hasSession = weekSessions.contains { session in
                    session.goal?.id == goal.id && session.day?.id == dayID && session.elapsedTime > 0
                }
                if hasSession {
                    streak += 1
                    maxStreak = max(maxStreak, streak)
                } else {
                    streak = 0
                }
            }
            if maxStreak > best.days {
                best = (days: maxStreak, goalTitle: goal.title)
            }
        }
        
        return best.days > 0 ? best : (days: 0, goalTitle: "—")
    }
    
    /// Day with the most total focused time
    private var biggestDay: (time: TimeInterval, dayName: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        var best: (time: TimeInterval, dayName: String) = (0, "—")
        
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let dayID = date.yearMonthDayID(with: calendar)
            let total = weekSessions
                .filter { $0.day?.id == dayID }
                .reduce(0.0) { $0 + $1.elapsedTime }
            if total > best.time {
                best = (time: total, dayName: formatter.string(from: date))
            }
        }
        return best
    }
    
    /// Total completed sessions this week
    private var totalSessions: Int {
        weekSessions.filter { $0.elapsedTime > 0 }.count
    }
    
    /// Active (non-archived) goals sorted by weekly time
    private var activeGoals: [Goal] {
        goals.filter { $0.status != .archived }
    }
    
    /// Per-goal weekly breakdown, sorted by time descending
    private var goalBreakdown: [(goal: Goal, time: TimeInterval, progress: Double)] {
        activeGoals.compactMap { goal in
            let time = weekSessions
                .filter { $0.goal?.id == goal.id }
                .reduce(0.0) { $0 + $1.elapsedTime }
            guard time > 0 else { return nil }
            let weeklyTarget = goal.unifiedWeeklyTarget
            let progress = weeklyTarget > 0 ? time / weeklyTarget : 0
            return (goal: goal, time: time, progress: progress)
        }
        .sorted { $0.time > $1.time }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date label
                    Text("THIS WEEK · \(weekDateLabel.uppercased())")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                    
                    // Hero headline
                    Text("You kept the **momentum.**")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.horizontal, 20)
                    
                    // Hero stats card with bar chart
                    heroCard
                        .padding(.horizontal, 16)
                    
                    // 3 stat pills
                    statPills
                        .padding(.horizontal, 16)
                    
                    // Goal breakdown
                    if !goalBreakdown.isEmpty {
                        goalBreakdownSection
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(.secondarySystemBackground))
            .navigationTitle("Weekly recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Hero Card
    
    private var heroCard: some View {
        let maxSeconds = dailyTotals.map(\.seconds).max() ?? 1
        
        return VStack(alignment: .leading, spacing: 16) {
            // Total focused label + delta
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL FOCUSED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(totalFocusedTime.formatted(style: .hourMinute))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Delta vs last week
                VStack(alignment: .trailing, spacing: 2) {
                    let isPositive = weekOverWeekDelta >= 0
                    Text("\(isPositive ? "↑" : "↓") \(abs(weekOverWeekDelta).formatted(style: .hourMinute))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text("VS LAST WEEK")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // Bar chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(dailyTotals.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(day.isFuture ? .white.opacity(0.15) : .white.opacity(day.seconds > 0 ? 0.85 : 0.2))
                            .frame(height: max(8, day.seconds > 0 ? CGFloat(day.seconds / maxSeconds) * 60 : 8))
                        
                        Text(day.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80, alignment: .bottom)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: heroGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    /// Gradient colors derived from the most-used goal's theme
    private var heroGradientColors: [Color] {
        if let topGoal = goalBreakdown.first?.goal {
            let theme = topGoal.resolvedTheme
            let base = theme.color(for: colorScheme)
            return [
                base.opacity(0.9),
                base,
                base.opacity(0.7),
            ]
        }
        return [
            Color(red: 0.85, green: 0.65, blue: 0.85),
            Color(red: 0.90, green: 0.70, blue: 0.75),
            Color(red: 0.95, green: 0.80, blue: 0.70),
        ]
    }
    
    // MARK: - Stat Pills
    
    private var statPills: some View {
        HStack(spacing: 10) {
            statPill(
                icon: "flame.fill",
                value: "\(longestStreak.days)d",
                label: "Longest streak",
                detail: longestStreak.goalTitle
            )
            
            statPill(
                icon: "chart.bar.fill",
                value: biggestDay.time.formatted(style: .hourMinute),
                label: "Biggest day",
                detail: biggestDay.dayName
            )
            
            statPill(
                icon: "checkmark.circle.fill",
                value: "\(totalSessions)",
                label: "Sessions",
                detail: "across 7 days"
            )
        }
    }
    
    private func statPill(icon: String, value: String, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Goal Breakdown
    
    private var goalBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE IT WENT")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(goalBreakdown.enumerated()), id: \.element.goal.id) { index, entry in
                    goalRow(entry: entry)
                    
                    if index < goalBreakdown.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
        }
    }
    
    private func goalRow(entry: (goal: Goal, time: TimeInterval, progress: Double)) -> some View {
        let theme = entry.goal.resolvedTheme
        let goalColor = theme.color(for: colorScheme)
        let iconName = entry.goal.iconName ?? "target"
        
        return HStack(spacing: 12) {
            // Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(goalColor.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(goalColor)
                }
            
            // Title
            Text(entry.goal.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            // Time
            Text(entry.time.formatted(style: .hourMinute))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Progress bar
            progressBar(progress: min(entry.progress, 1.0), color: goalColor)
                .frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func progressBar(progress: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * progress))
            }
        }
        .frame(height: 6)
    }
    
    // MARK: - Helpers
    
    private func dayIDsForWeek(starting start: Date) -> Set<String> {
        var ids = Set<String>()
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            ids.insert(date.yearMonthDayID(with: calendar))
        }
        return ids
    }
}

#Preview("Weekly Recap") {
    WeeklyRecapView()
        .modelContainer(for: [Goal.self, GoalSession.self, Day.self], inMemory: true)
}
