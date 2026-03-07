//
//  WatchActiveSessionView.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 02/03/2026.
//

import SwiftUI
import MomentumKit
import Combine

struct WatchActiveSessionView: View {
    let session: GoalSession
    @State private var elapsedMinutes: Int = 0
    @State private var isPaused: Bool = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var progress: Double {
        guard session.dailyTarget > 0 else { return 0 }
        return min(Double(elapsedMinutes) / Double(session.dailyTarget), 1.0)
    }
    
    private var remainingMinutes: Int {
        max(0, Int(session.dailyTarget) - elapsedMinutes)
    }
    
    private func updateElapsedTime() {
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        
        let activeSessionIDKey = "ActiveSessionIDV1"
        let activeSessionStartDateKey = "ActiveSessionStartDateV1"
        let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
        let pausedSessionIDKey = "PausedSessionIDV1"
        
        guard let activeID = defaults.string(forKey: activeSessionIDKey),
              activeID == session.id.uuidString else {
            // Check if paused
            if let pausedID = defaults.string(forKey: pausedSessionIDKey),
               pausedID == session.id.uuidString {
                isPaused = true
                let elapsed = defaults.double(forKey: activeSessionElapsedTimeKey)
                elapsedMinutes = Int(elapsed / 60)
            }
            return
        }
        
        isPaused = false
        let startTimeInterval = defaults.double(forKey: activeSessionStartDateKey)
        let startDate = Date(timeIntervalSince1970: startTimeInterval)
        let initialElapsed = defaults.double(forKey: activeSessionElapsedTimeKey)
        let duration = Date().timeIntervalSince(startDate)
        let totalElapsed = initialElapsed + duration
        
        elapsedMinutes = Int(totalElapsed / 60)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Goal title
            Text(session.goal?.title ?? "Unknown")
                .font(.headline)
                .foregroundStyle((session.goal?.primaryTag?.theme ?? Theme.default).color(for: .dark))
            
            // Progress ring and time
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            (session.goal?.primaryTag?.theme ?? Theme.default).color(for: .dark),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Text(formatElapsedTime(elapsedMinutes))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    if remainingMinutes > 0 {
                        Text("\(remainingMinutes)m left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Target reached!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    // Status
                    if isPaused {
                        Text("Paused")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Active")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((session.goal?.primaryTag?.theme ?? Theme.default).color(for: .dark).opacity(0.2))
        )
        .onAppear {
            updateElapsedTime()
        }
        .onReceive(timer) { _ in
            updateElapsedTime()
        }
    }
    
    private func formatElapsedTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
