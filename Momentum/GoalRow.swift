//
//  GoalRow.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct GoalRow: View {
    let goal: Goal
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("weekStartDay") private var weekStartDay: Int = Calendar.current.firstWeekday
    @Query private var allDays: [Day]
    
    init(goal: Goal) {
        self.goal = goal
        
        // Fetch current week's days efficiently with a single query
        var calendar = Calendar.current
        let storedWeekStartDay = UserDefaults.standard.integer(forKey: "weekStartDay")
        calendar.firstWeekday = storedWeekStartDay == 0 ? Calendar.current.firstWeekday : storedWeekStartDay
        
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            _allDays = Query(filter: #Predicate<Day> { _ in false })
            return
        }
        
        let startDayID = startOfWeek.yearMonthDayID(with: calendar)
        let endDayID = endOfWeek.yearMonthDayID(with: calendar)
        
        _allDays = Query(
            filter: #Predicate<Day> { day in
                day.id >= startDayID && day.id <= endDayID
            },
            sort: \Day.id
        )
    }
    
    // Calculate total weekly elapsed time
    private var weeklyElapsedMinutes: Int {
        var totalTime: TimeInterval = 0
        
        for day in allDays {
            if let session = day.sessions.first(where: { $0.goal.id == goal.id }) {
                // Add manual elapsed time
                totalTime += session.elapsedTime
                
                // Add HealthKit time
                totalTime += session.healthKitTime
                
                // Add manual historical sessions
                let manualHistoricalTime = session.historicalSessions
                    .filter { $0.healthKitType == nil }
                    .reduce(0.0) { $0 + $1.duration }
                totalTime += manualHistoricalTime
            }
        }
        
        return Int(totalTime / 60)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(weeklyElapsedMinutes)/\(Int(goal.weeklyTarget / 60))")
                 
                        Text("min this week")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(goal.tintColor(for: colorScheme))
                    .font(.caption)
                    .fontWeight(.semibold)


                    if goal.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if goal.healthKitSyncEnabled {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }
            }
            
            Spacer()
            
            // 7-day bar chart (compact)
            VStack {
                Spacer()
                SevenDayBarChart(goal: goal)
                    .frame(width: 100)
            }
            
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 7-Day Bar Chart

struct SevenDayBarChart: View {
    let goal: Goal
    @Query private var allDays: [Day]
    @AppStorage("weekStartDay") private var weekStartDay: Int = Calendar.current.firstWeekday
    @Environment(\.colorScheme) private var colorScheme
    
    init(goal: Goal) {
        self.goal = goal
        
        // Fetch last 7 days efficiently with a single query
        let calendar = Calendar.current
        let today = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let startDayID = sevenDaysAgo.yearMonthDayID(with: calendar)
        let endDayID = today.yearMonthDayID(with: calendar)
        
        _allDays = Query(
            filter: #Predicate<Day> { day in
                day.id >= startDayID && day.id <= endDayID
            },
            sort: \Day.id
        )
    }
    
    // Calculate daily data for the current week (respecting user's week start preference)
    private var dailyData: [(day: String, progress: TimeInterval, date: Date)] {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartDay
        
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        
        // Create a lookup dictionary for faster access
        let daysByID = Dictionary(uniqueKeysWithValues: allDays.map { ($0.id, $0) })
        
        return (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                return ("", 0, Date())
            }
            
            let dayID = date.yearMonthDayID(with: calendar)
            
            // Find the session for this goal
            let session = daysByID[dayID]?.sessions.first(where: { $0.goal.id == goal.id })
            
            // Calculate total progress from manual tracking + HealthKit + historical sessions
            var totalProgress: TimeInterval = 0
            
            // Add manual elapsed time
            totalProgress += session?.elapsedTime ?? 0
            
            // Add HealthKit time (already deduplicated in session.healthKitTime)
            totalProgress += session?.healthKitTime ?? 0
            
            // Add historical sessions for this goal (manual logs, not HealthKit as those are already in healthKitTime)
            // Only count manual historical sessions to avoid double-counting HealthKit data
            if let session = session {
                let manualHistoricalTime = session.historicalSessions
                    .filter { $0.healthKitType == nil } // Only manual entries
                    .reduce(0.0) { $0 + $1.duration }
                totalProgress += manualHistoricalTime
            }
            
            // Get weekday initial (M, T, W, etc.)
            let weekdaySymbol = calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            
            return (weekdaySymbol, totalProgress, date)
        }
    }
    
    private var dailyTarget: TimeInterval {
        goal.weeklyTarget / 7
    }
    
    private var maxValue: TimeInterval {
        max(dailyData.map { $0.progress }.max() ?? 0, dailyTarget)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(dailyData.enumerated()), id: \.offset) { index, data in
                VStack(spacing: 1) {
                    // Bar
                    let height: CGFloat = maxValue > 0 ? CGFloat(data.progress / maxValue) * 20 : 0
                    let isToday = Calendar.current.isDateInToday(data.date)
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor(for: data.progress))
                        .frame(width: 6, height: max(height, 1.5))
                        .overlay(alignment: .bottom) {
                            if isToday {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .strokeBorder(goal.primaryTag.themePreset.color(for: colorScheme), lineWidth: 0.75)
                            }
                        }
                    
                    // Day label
                    Text(data.day)
                        .font(.caption2)
                        .foregroundStyle(isToday ? goal.primaryTag.themePreset.color(for: colorScheme) : .secondary)
                        .fontWeight(isToday ? .semibold : .regular)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40)
    }
    
    private func barColor(for progress: TimeInterval) -> Color {
        if progress >= dailyTarget {
            return goal.primaryTag.themePreset.neon
        } else if progress > 0 {
            return goal.primaryTag.themePreset.light.opacity(0.6)
        } else {
            return Color(.systemGray5)
        }
    }
}
