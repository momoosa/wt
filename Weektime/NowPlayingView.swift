//
//  NowPlayingView.swift
//  Weektime
//
//  Created by Mo Moosa on 20/01/2026.
//

import SwiftUI
import WeektimeKit

struct NowPlayingView: View {
    let session: GoalSession
    let activeSessionDetails: ActiveSessionDetails
    let onStopTapped: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    session.goal.primaryTag.theme.light,
                    session.goal.primaryTag.theme.dark
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        // Swipe down to dismiss
                        if value.translation.height > 100 {
                            dismiss()
                        }
                    }
            )
            
            VStack(spacing: 40) {
                // Dismiss indicator at top
                VStack(spacing: 16) {
                    // Grab handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    // Down chevron button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
                            )
                    }
                }
                
                Spacer()
                
                // Goal title
                VStack(spacing: 8) {
                    Text(session.goal.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(session.goal.primaryTag.title)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Circular progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            Color.white.opacity(0.3),
                            lineWidth: 20
                        )
                        .frame(width: 280, height: 280)
                    
                    // Progress circle with gradient
                    Circle()
                        .trim(from: 0, to: activeSessionDetails.progress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .white,
                                    session.goal.primaryTag.theme.neon,
                                    .white
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: activeSessionDetails.progress)
                    
                    // Time display in center
                    VStack(spacing: 12) {
                        if let timeText = activeSessionDetails.timeText {
                            Text(timeText)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                        
                        // Progress percentage
                        Text("\(Int(activeSessionDetails.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        // Daily target info
                        if let dailyTarget = activeSessionDetails.dailyTarget {
                            Text("of \(formatDuration(dailyTarget))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 40)
                
                // Control buttons
                HStack(spacing: 60) {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
                            )
                    }
                    
                    // Stop/Pause button (large)
                    Button {
                        #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        #endif
                        onStopTapped()
                        dismiss()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(session.goal.primaryTag.theme.dark)
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            )
                    }
                    
                    // Info button (placeholder for future features)
                    Button {
                        // TODO: Show session details/notes
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
                            )
                    }
                }
                .padding(.bottom, 60)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    
    let theme = GoalTag(title: "Wellness", color: themes.first(where: { $0.id == "purple" })!)
    let goal = Goal(title: "Meditation", primaryTag: theme, weeklyTarget: 3600)
    let day = Day(start: Date(), end: Date())
    let session = GoalSession(title: "Meditation", goal: goal, day: day)
    let details = ActiveSessionDetails(id: session.id, startDate: Date().addingTimeInterval(-600), elapsedTime: 600, dailyTarget: 1200)
    
    NowPlayingView(session: session, activeSessionDetails: details) {
        print("Stop tapped")
    }
}
