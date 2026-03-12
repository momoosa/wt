//
//  GoalDetailView.swift
//  Momentum
//
//  Created by Assistant on 10/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit
import Charts

struct GoalDetailView: View {
    let goal: Goal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var allDays: [Day]
    @State private var showingEditSheet = false
    
    init(goal: Goal) {
        self.goal = goal
        
        // Fetch all days for historical data
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let startDayID = thirtyDaysAgo.yearMonthDayID(with: calendar)
        let endDayID = today.yearMonthDayID(with: calendar)
        
        _allDays = Query(
            filter: #Predicate<Day> { day in
                day.id >= startDayID && day.id <= endDayID
            },
            sort: \Day.id
        )
    }
    
    private var tintColor: Color {
        goal.primaryTag?.themePreset.color(for: colorScheme) ?? .blue
    }
    
    private var chartGradient: LinearGradient {
        let theme = goal.primaryTag?.theme ?? Theme.default
        return LinearGradient(
            colors: [theme.dark, theme.neon],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        List {
            // Overview Section
            Section {
                overviewCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // Weekly Progress Chart
            Section {
                weeklyProgressChart
                    .frame(height: 180)
            } header: {
                Text("Last 4 Weeks")
                    .font(.headline)
            }
            
            // Schedule Section
            if goal.hasSchedule {
                Section {
                    scheduleGridView
                } header: {
                    Text("Schedule")
                        .font(.headline)
                }
            }
            
            // Settings Section
            Section {
                settingsRows
            } header: {
                Text("Settings")
                    .font(.headline)
            }
            
            // Stats Section
            Section {
                statsRows
            } header: {
                Text("Statistics")
                    .font(.headline)
            }
            
            // Tags Section
            if let otherTags = goal.otherTags, !otherTags.isEmpty {
                Section {
                    tagsList(tags: otherTags)
                } header: {
                    Text("Tags")
                        .font(.headline)
                }
            }
            
            // Notes & Link Section
            if goal.notes != nil || goal.link != nil {
                Section {
                    notesAndLinkRows
                } header: {
                    Text("Resources")
                        .font(.headline)
                }
            }
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            GoalEditorView(existingGoal: goal)
        }
    }
    
    // MARK: - Overview Card
    
    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                // Icon
                if let iconName = goal.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(chartGradient)
                }
                
                Spacer()
                
                // Weekly Progress Ring
                ZStack {
                    Circle()
                        .stroke(tintColor.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: weeklyProgress)
                        .stroke(chartGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(Int(weeklyProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("this week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
            }
            
            Divider()
            
            // Stats Row
            HStack(spacing: 0) {
                statItem(title: "Target", value: "\(Int(goal.weeklyTarget / 60))m")
                Divider()
                statItem(title: "Completed", value: "\(weeklyElapsedMinutes)m")
                Divider()
                statItem(title: "Remaining", value: "\(max(0, Int(goal.weeklyTarget / 60) - weeklyElapsedMinutes))m")
            }
            .frame(height: 60)
        }
        .padding()
        .background(tintColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(tintColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Weekly Progress
    
    private var weeklyProgress: Double {
        guard goal.weeklyTarget > 0 else { return 0 }
        return min(1.0, Double(weeklyElapsedMinutes * 60) / goal.weeklyTarget)
    }
    
    private var weeklyElapsedMinutes: Int {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return 0
        }
        
        var total: TimeInterval = 0
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            let dayID = date.yearMonthDayID(with: calendar)
            
            if let day = allDays.first(where: { $0.id == dayID }),
               let session = day.sessions?.first(where: { $0.goal?.id == goal.id }) {
                total += session.elapsedTime
                total += session.healthKitTime
                
                let manualHistorical = session.historicalSessions.filter { $0.healthKitType == nil }
                    .reduce(0.0) { $0 + $1.duration }
                total += manualHistorical
            }
        }
        
        return Int(total / 60)
    }
    
    // MARK: - Chart
    
    struct WeeklyData: Identifiable {
        let id = UUID()
        let weekLabel: String
        let minutes: Double
        let weekOffset: Int
    }
    
    private var weeklyProgressChart: some View {
        let data = last4WeeksData
        let maxValue = data.map { $0.minutes }.max() ?? 1
        
        return Chart {
            ForEach(data.filter { $0.weekOffset == 0 }) { item in
                BarMark(
                    x: .value("Week", item.weekLabel),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(chartGradient)
            }
            
            ForEach(data.filter { $0.weekOffset != 0 }) { item in
                BarMark(
                    x: .value("Week", item.weekLabel),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(Color.secondary.opacity(0.5))
            }
            
            // Target line
            RuleMark(y: .value("Target", goal.weeklyTarget / 60))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(tintColor.opacity(0.5))
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
    
    private var last4WeeksData: [WeeklyData] {
        let calendar = Calendar.current
        let today = Date()
        
        var data: [WeeklyData] = []
        
        for weekOffset in (0..<4).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today),
                  let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)) else {
                continue
            }
            
            var weekTotal: TimeInterval = 0
            
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
                let dayID = date.yearMonthDayID(with: calendar)
                
                if let day = allDays.first(where: { $0.id == dayID }),
                   let session = day.sessions?.first(where: { $0.goal?.id == goal.id }) {
                    weekTotal += session.elapsedTime
                    weekTotal += session.healthKitTime
                    
                    let manualHistorical = session.historicalSessions.filter { $0.healthKitType == nil }
                        .reduce(0.0) { $0 + $1.duration }
                    weekTotal += manualHistorical
                }
            }
            
            let weekLabel = weekOffset == 0 ? "This Week" : "\(weekOffset)w ago"
            data.append(WeeklyData(weekLabel: weekLabel, minutes: weekTotal / 60, weekOffset: weekOffset))
        }
        
        return data
    }
    
    // MARK: - Schedule Grid
    
    private var scheduleGridView: some View {
        let weekdays: [(Int, String)] = [
            (2, "M"), (3, "T"), (4, "W"),
            (5, "T"), (6, "F"), (7, "S"), (1, "S")
        ]
        let times = Array(TimeOfDay.allCases)
        let theme = goal.primaryTag?.theme ?? Theme.default
        
        return VStack(spacing: 4) {
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
                }
                
                // Unscheduled overlay
                HStack(spacing: 6) {
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
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Settings Rows
    
    @ViewBuilder
    private var settingsRows: some View {
        // HealthKit
        if goal.healthKitSyncEnabled, let metric = goal.healthKitMetric {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HealthKit Sync")
                            .font(.subheadline)
                        Text(metric.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: metric.symbolName)
                        .foregroundStyle(.pink)
                }
                
                Spacer()
                
                Text(metric.supportsWrite ? "Read & Write" : "Read")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        
        // Notifications
        if goal.scheduleNotificationsEnabled {
            Label {
                Text("Start Notifications")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(tintColor)
            }
        }
        
        if goal.completionNotificationsEnabled {
            Label {
                Text("Finish Notifications")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tintColor)
            }
        }
        
        // Weather
        if goal.weatherEnabled {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather-Based Visibility")
                        .font(.subheadline)
                    if let conditions = goal.weatherConditionsTyped, !conditions.isEmpty {
                        Text(conditions.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "cloud.sun.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
    
    // MARK: - Stats Rows
    
    @ViewBuilder
    private var statsRows: some View {
        HStack {
            Text("Daily Target")
            Spacer()
            Text("\(Int(goal.weeklyTarget / 60 / 7))m")
                .foregroundStyle(.secondary)
        }
        
        HStack {
            Text("Weekly Target")
            Spacer()
            Text("\(Int(goal.weeklyTarget / 60))m")
                .foregroundStyle(.secondary)
        }
        
        if let dailyMin = goal.dailyMinimum {
            HStack {
                Text("Daily Minimum")
                Spacer()
                Text("\(Int(dailyMin / 60))m")
                    .foregroundStyle(.secondary)
            }
        }
        
        HStack {
            Text("Status")
            Spacer()
            Text(goal.status == .active ? "Active" : "Archived")
                .foregroundStyle(goal.status == .active ? .green : .secondary)
        }
    }
    
    // MARK: - Tags List
    
    private func tagsList(tags: [GoalTag]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.themeID) { tag in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tag.themePreset.light)
                            .frame(width: 8, height: 8)
                        Text(tag.title)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tag.themePreset.light.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Notes & Link
    
    @ViewBuilder
    private var notesAndLinkRows: some View {
        if let notes = goal.notes {
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
            }
            .padding(.vertical, 4)
        }
        
        if let link = goal.link, let url = URL(string: link) {
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
    }
}
