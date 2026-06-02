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
    @State private var showingDeleteAlert = false
    @State private var editViewModel: GoalEditorViewModel?
    
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
        goal.resolvedTheme.color(for: colorScheme)
    }
    
    private var themePreset: ThemePreset {
        goal.resolvedTheme
    }
    
    private var chartGradient: LinearGradient {
        themePreset.gradient(for: colorScheme)
    }
    
    private var textColor: Color {
        themePreset.foregroundColor(for: colorScheme)
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
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Goal", systemImage: "pencil")
                    }
                    
                    Button {
                        withAnimation {
                            goal.status = goal.status == .archived ? .active : .archived
                        }
                    } label: {
                        Label(
                            goal.status == .archived ? "Unarchive" : "Archive",
                            systemImage: goal.status == .archived ? "tray.and.arrow.up" : "archivebox"
                        )
                    }
                    
                    Divider()
                    
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
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            editViewModel = nil
        }) {
            if let vm = editViewModel {
                GoalEditorView(viewModel: vm)
            }
        }
        .onChange(of: showingEditSheet) { _, show in
            if show {
                editViewModel = GoalEditorViewModel(existingGoal: goal)
            }
        }
        .alert("Delete Goal?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("This will permanently delete \"\(goal.title)\" and all its data. This action cannot be undone.")
        }
    }
    
    // MARK: - Overview Card
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: label + delta
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
            
            // Big time display
            Text(TimeInterval(Double(weeklyElapsedMinutes) * 60).formatted(style: .hourMinute))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
            
            // Weekly bar chart
            WeeklyBarChart(dailyMinutes: thisWeekDailyMinutes, barColor: textColor)
        }
        .padding()
        .background {
            themePreset.gradient(for: colorScheme)
        }
        .glassCardStyle(shadowColor: themePreset.color(for: colorScheme))
        .padding(.horizontal)
    }
    
    // MARK: - Weekly Progress
    
    private var weeklyProgress: Double {
        guard goal.unifiedWeeklyTarget > 0 else { return 0 }
        return min(1.0, Double(weeklyElapsedMinutes * 60) / goal.unifiedWeeklyTarget)
    }
    
    private var weeklyElapsedMinutes: Int {
        thisWeekDailyMinutes.reduce(0) { $0 + Int($1) }
    }
    
    /// Per-day minutes for the current week (7 values, Mon-Sun)
    private var thisWeekDailyMinutes: [Double] {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return Array(repeating: 0, count: 7)
        }
        
        var daily: [Double] = []
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                daily.append(0)
                continue
            }
            let dayID = date.yearMonthDayID(with: calendar)
            
            if let day = allDays.first(where: { $0.id == dayID }),
               let session = day.sessions?.first(where: { $0.goal?.id == goal.id }) {
                daily.append(session.elapsedTime / 60)
            } else {
                daily.append(0)
            }
        }
        return daily
    }
    
    /// Delta in minutes between this week and last week totals
    private var weeklyDeltaMinutes: Double {
        let calendar = Calendar.current
        let today = Date()
        guard let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) else {
            return 0
        }
        
        let thisWeekTotal = Double(weeklyElapsedMinutes)
        
        var lastWeekTotal: Double = 0
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: lastWeekStart) else { continue }
            let dayID = date.yearMonthDayID(with: calendar)
            
            if let day = allDays.first(where: { $0.id == dayID }),
               let session = day.sessions?.first(where: { $0.goal?.id == goal.id }) {
                lastWeekTotal += session.elapsedTime / 60
            }
        }
        
        return thisWeekTotal - lastWeekTotal
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
            RuleMark(y: .value("Target", goal.unifiedWeeklyTarget / 60))
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
                    // elapsedTime incorporates both manual sessions and healthKitTime
                    weekTotal += session.elapsedTime
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
        let theme = goal.primaryTag?.theme ?? ThemeStore.defaultPreset
        
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
                    theme.gradient(for: colorScheme)
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
            Text("\(Int(goal.unifiedWeeklyTarget / 60 / 7))m")
                .foregroundStyle(.secondary)
        }
        
        HStack {
            Text("Weekly Target")
            Spacer()
            Text("\(Int(goal.unifiedWeeklyTarget / 60))m")
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
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Delete Goal
    
    private func deleteGoal() {
        withAnimation {
            modelContext.delete(goal)
        }
        
        if modelContext.safeSave() {
            dismiss()
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
// MARK: - Weekly Bar Chart

private struct WeeklyBarChart: View {
    let dailyMinutes: [Double]  // 7 values, Mon-Sun
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

