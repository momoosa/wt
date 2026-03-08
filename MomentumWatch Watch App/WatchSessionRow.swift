//
//  WatchSessionRow.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 02/03/2026.
//

import SwiftUI
import MomentumKit
import WatchKit

struct WatchSessionRow: View {
    let session: GoalSession
    let day: Day
    
    @State private var showingStartAlert = false
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    private var todayMinutes: Int {
        // Get today's elapsed time from historical sessions
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())

        guard let historicalSessions = day.historicalSessions,
              let goalID = session.goal?.id.uuidString else {
            return 0
        }

        let todaySessions = historicalSessions.filter { historical in
            let sessionComponents = calendar.dateComponents([.year, .month, .day], from: historical.startDate)
            return historical.goalIDs.contains(goalID) &&
                   sessionComponents.year == todayComponents.year &&
                   sessionComponents.month == todayComponents.month &&
                   sessionComponents.day == todayComponents.day
        }

        return todaySessions.reduce(into: 0) { $0 += Int($1.duration / 60) }
    }
    
    private var progress: Double {
        guard session.dailyTarget > 0 else { return 0 }
        return min(Double(todayMinutes) / Double(session.dailyTarget), 1.0)
    }
    
    private var remainingMinutes: Int {
        max(0, Int(session.dailyTarget) - todayMinutes)
    }
    
    var body: some View {
        Button {
            startSession()
        } label: {
            HStack(spacing: 12) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            (session.goal?.primaryTag?.theme ?? Theme.default).color(for: .dark),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10))
                        .fontWeight(.semibold)
                }
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.goal?.title ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if remainingMinutes > 0 {
                            Text("\(remainingMinutes)m")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("left")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Done")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle((session.goal?.primaryTag?.theme ?? Theme.default).color(for: .dark))
            }
        }
        .buttonStyle(.plain)
        .alert("Timer Request", isPresented: $showingStartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if connectivityManager.isReachable {
                Text("Starting timer for \(session.goal?.title ?? "session")")
            } else {
                Text("iPhone not reachable. Command queued.")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                quickLog(minutes: 5)
            } label: {
                Label("+5m", systemImage: "plus.circle.fill")
            }
            .tint(.green)
            
            Button {
                quickLog(minutes: 15)
            } label: {
                Label("+15m", systemImage: "plus.circle.fill")
            }
            .tint(.blue)
        }
    }
    
    private func startSession() {
        // Haptic feedback
        WKInterfaceDevice.current().play(.start)
        
        // Show feedback
        showingStartAlert = true
        
        // Send start timer request to iPhone via WatchConnectivity
        WatchConnectivityManager.shared.requestStartTimer(sessionID: session.id)
    }
    
    private func quickLog(minutes: Int) {
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Send quick log request to iPhone via WatchConnectivity
        WatchConnectivityManager.shared.requestQuickLog(sessionID: session.id, minutes: minutes)
    }
}
