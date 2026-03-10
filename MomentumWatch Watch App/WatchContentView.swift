//
//  WatchContentView.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 02/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [GoalSession]
    @Query private var days: [Day]
    @Query private var goals: [Goal]
    
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    private var today: Day {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        
        if let existingDay = days.first(where: { day in
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: day.startDate)
            return dayComponents.year == todayComponents.year &&
                   dayComponents.month == todayComponents.month &&
                   dayComponents.day == todayComponents.day
        }) {
            return existingDay
        }
        
        // Create today if it doesn't exist
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let newDay = Day(start: start, end: end, calendar: calendar)
        modelContext.insert(newDay)
        try? modelContext.save()
        return newDay
    }
    
    private var todaySessions: [GoalSession] {
        // Filter sessions to only include today's sessions
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        
        return allSessions.filter { session in
            guard session.dailyTarget > 0,
                  let dayStartDate = session.day?.startDate else {
                return false
            }
            
            let sessionDayComponents = calendar.dateComponents([.year, .month, .day], from: dayStartDate)
            return sessionDayComponents.year == todayComponents.year &&
                   sessionDayComponents.month == todayComponents.month &&
                   sessionDayComponents.day == todayComponents.day
        }
    }
    
    private var filteredSessions: [GoalSession] {
        return todaySessions.sorted { (lhs: GoalSession, rhs: GoalSession) in
            return (lhs.goal?.title ?? "") < (rhs.goal?.title ?? "")
        }
    }
    
    private var activeSession: GoalSession? {
        guard let timerState = connectivityManager.activeTimerState else { return nil }
        return todaySessions.first(where: { $0.id == timerState.sessionID })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Connection status indicator
                if !connectivityManager.isReachable {
                    Section {
                        HStack {
                            Image(systemName: "iphone.slash")
                                .foregroundStyle(.orange)
                            Text("iPhone not reachable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Show error if any
                if let error = connectivityManager.lastError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // Show active session at the top
                if let activeSession = activeSession, let timerState = connectivityManager.activeTimerState {
                    Section {
                        WatchActiveSessionView(
                            session: activeSession,
                            timerState: timerState
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // Show all other sessions
                Section {
                    ForEach(filteredSessions.filter { $0.id.uuidString != activeSession?.id.uuidString }) { session in
                        WatchSessionRow(
                            session: session,
                            day: today
                        )
                    }
                }
            }
            .navigationTitle("Momentum")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
