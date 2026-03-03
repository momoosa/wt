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
    @Query(filter: #Predicate<GoalSession> { $0.dailyTarget > 0 }) private var sessions: [GoalSession]
    @Query private var allSessions: [GoalSession]
    @Query private var days: [Day]
    @Query private var goals: [Goal]
    
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
    
    private var filteredSessions: [GoalSession] {
        return sessions.sorted { (lhs: GoalSession, rhs: GoalSession) in
            return lhs.goal.title < rhs.goal.title
        }
    }
    
    // Check UserDefaults for active session
    private var activeSessionID: String? {
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return nil
        }
        return defaults.string(forKey: "ActiveSessionIDV1")
    }
    
    private var activeSession: GoalSession? {
        guard let activeID = activeSessionID else { return nil }
        return sessions.first(where: { $0.id.uuidString == activeID })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Debug info
                Section("Debug Info") {
                    Text("Goals: \(goals.count)")
                    Text("All Sessions: \(allSessions.count)")
                    Text("Sessions w/ target: \(sessions.count)")
                    Text("Filtered: \(filteredSessions.count)")
                    Text("Days: \(days.count)")
                    
                    // Show first few goals
                    if !goals.isEmpty {
                        ForEach(goals.prefix(3)) { goal in
                            Text("Goal: \(goal.title)")
                                .font(.system(size: 8))
                        }
                    }
                    
                    // Show first few sessions
                    if !allSessions.isEmpty {
                        ForEach(allSessions.prefix(3)) { session in
                            Text("Session: \(session.goal.title) - target: \(Int(session.dailyTarget))")
                                .font(.system(size: 8))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                // Show active session at the top
                if let activeSession = activeSession {
                    Section {
                        WatchActiveSessionView(session: activeSession)
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
