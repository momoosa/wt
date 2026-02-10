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
    
    // Calculate total weekly elapsed time
    private var weeklyElapsedMinutes: Int {
        let calendar = Calendar.current
        let today = Date()
        var totalTime: TimeInterval = 0
        
        for daysAgo in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let dayID = date.yearMonthDayID(with: calendar)
            
            let fetchRequest = FetchDescriptor<Day>(
                predicate: #Predicate<Day> { $0.id == dayID }
            )
            
            if let day = try? modelContext.fetch(fetchRequest).first,
               let session = day.sessions.first(where: { $0.goal.id == goal.id }) {
                
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
    @Environment(\.modelContext) private var modelContext
    
    // Calculate daily data for the last 7 days
    private var dailyData: [(day: String, progress: TimeInterval, date: Date)] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let dayID = date.yearMonthDayID(with: calendar)
            
            // Fetch the day from SwiftData
            let fetchRequest = FetchDescriptor<Day>(
                predicate: #Predicate<Day> { $0.id == dayID }
            )
            
            let day = try? modelContext.fetch(fetchRequest).first
            
            // Find the session for this goal
            let session = day?.sessions.first(where: { $0.goal.id == goal.id })
            
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
                                    .strokeBorder(goal.primaryTag.themePreset.dark, lineWidth: 0.75)
                            }
                        }
                    
                    // Day label
                    Text(data.day)
                        .font(.caption2)
                        .foregroundStyle(isToday ? goal.primaryTag.themePreset.dark : .secondary)
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
