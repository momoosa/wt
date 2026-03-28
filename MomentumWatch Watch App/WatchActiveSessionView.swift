//
//  WatchActiveSessionView.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 02/03/2026.
//

import SwiftUI
import MomentumKit
import Combine
import WatchKit

struct WatchActiveSessionView: View {
    let session: GoalSession
    let timerState: WatchConnectivityManager.ActiveTimerState
    
    @State private var currentTime = Date()
    @State private var hasReachedTarget = false
    @State private var showCelebration = false
    @State private var updateInterval: TimeInterval = 1.0
    
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: updateInterval, on: .main, in: .common).autoconnect()
    }
    
    private func toggleTimer() {
        // Haptic feedback - different based on state
        if timerState.isPaused {
            WKInterfaceDevice.current().play(.start)
        } else {
            WKInterfaceDevice.current().play(.stop)
        }
        
        WatchConnectivityManager.shared.requestTimerToggle(sessionID: timerState.sessionID)
    }
    
    private var totalElapsedMinutes: Int {
        if timerState.isPaused {
            return Int(timerState.elapsedTime / 60)
        } else {
            // Calculate current elapsed time based on start date
            let duration = currentTime.timeIntervalSince(timerState.startDate)
            let totalElapsed = timerState.elapsedTime + duration
            return Int(totalElapsed / 60)
        }
    }
    
    private var progress: Double {
        guard timerState.dailyTarget > 0 else { return 0 }
        let minutesTarget = timerState.dailyTarget / 60
        return Double(totalElapsedMinutes) / minutesTarget
    }
    
    private var remainingMinutes: Int {
        let targetMinutes = Int(timerState.dailyTarget / 60)
        return max(0, targetMinutes - totalElapsedMinutes)
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
            // Goal title
            Text(session.goal?.title ?? "Unknown")
                .font(.headline)
                .foregroundStyle((session.goal?.primaryTag?.theme ?? themePresets[0]).color(for: .dark))
            
            // Progress ring and time
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            (session.goal?.primaryTag?.theme ?? themePresets[0]).color(for: .dark),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Text(formatElapsedTime(totalElapsedMinutes))
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
                    if timerState.isPaused {
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
                    .fill((session.goal?.primaryTag?.theme ?? themePresets[0]).color(for: .dark).opacity(0.2))
            )
            .onTapGesture {
                toggleTimer()
            }
            .onReceive(timer) { time in
                currentTime = time
                checkForCompletion()
            }
            
            // Celebration overlay
            if showCelebration {
                ZStack {
                    Color.clear
                    
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: showCelebration)
                        
                        Text("Target Reached!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private func checkForCompletion() {
        let targetMinutes = Int(timerState.dailyTarget / 60)
        if totalElapsedMinutes >= targetMinutes && !hasReachedTarget {
            hasReachedTarget = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showCelebration = true
            }
            WKInterfaceDevice.current().play(.success)
            
            // Reduce update frequency after target reached (battery optimization)
            updateInterval = 5.0
            
            // Hide celebration after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showCelebration = false
                }
            }
        } else if totalElapsedMinutes < targetMinutes {
            hasReachedTarget = false
            updateInterval = 1.0
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
