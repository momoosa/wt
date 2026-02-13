//
//  MomentumWidgetLiveActivity.swift
//  MomentumWidget
//
//  Created by Mo Moosa on 01/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI
import MomentumKit
import AppIntents

// Note: MomentumWidgetAttributes is now defined in MomentumKit/SessionTimerIntents.swift

// MARK: - Circular Progress View (Widget Version)

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let foregroundColor: Color
    let backgroundColor: Color
    let animateOnAppear: Bool
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        size: CGFloat = 80,
        foregroundColor: Color,
        backgroundColor: Color,
        animateOnAppear: Bool = true
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.animateOnAppear = animateOnAppear
    }
    
    var body: some View {
        Circle()
            .stroke(backgroundColor, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .trim(from: 0, to: min(animatedProgress, 1.0))
                    .stroke(
                        foregroundColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }
            .onAppear {
                if animateOnAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        animatedProgress = progress
                    }
                } else {
                    animatedProgress = progress
                }
            }
            .onChange(of: progress) { oldValue, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animatedProgress = newValue
                }
            }
    }
}

// MARK: - Live Activity Widget

struct MomentumWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MomentumWidgetAttributes.self) { context in
            // Lock screen/banner UI
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: context.attributes.themeDark)?.opacity(0.3))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        let elapsed = currentElapsed(context: context, at: timeline.date)
                        let progress = currentProgress(context: context, at: timeline.date)
                        
                        CircularProgressView(
                            progress: progress,
                            lineWidth: 6,
                            size: 50,
                            foregroundColor: Color(hex: context.attributes.themeNeon) ?? .blue,
                            backgroundColor: Color(hex: context.attributes.themeDark)?.opacity(0.3) ?? .gray.opacity(0.3),
                            animateOnAppear: false
                        )
                        .overlay {
                            Text("\(Int(progress * 100))%")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.isActive {
                            // Calculate the effective start date accounting for elapsed time
                            let effectiveStart = context.state.startDate.addingTimeInterval(-context.state.elapsedTime)
                            Text(timerInterval: effectiveStart...Date.distantFuture, countsDown: false)
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .contentTransition(.numericText())
                        } else {
                            Text(context.state.elapsedTime.formatted(style: .hmmss))
                                .font(.title3)
                                .fontWeight(.bold)
                                .contentTransition(.numericText())
                        }
                        
                        Text("/ \(context.attributes.dailyTarget.formatted(style: .hmmss))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        Text(context.attributes.goalTitle)
                            .font(.headline)
                            .lineLimit(1)
                        
                        HStack(spacing: 16) {
                            // Pause/Resume button
                            Button(intent: PauseResumeTimerIntent(sessionID: context.attributes.sessionID, dayID: context.attributes.dayID)) {
                                HStack(spacing: 6) {
                                    Image(systemName: context.state.isActive ? "pause.circle.fill" : "play.circle.fill")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            
                            // Stop button
                            Button(intent: StopTimerIntent(sessionID: context.attributes.sessionID, dayID: context.attributes.dayID)) {
                                HStack(spacing: 6) {
                                    Image(systemName: "stop.circle.fill")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } compactLeading: {
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    let progress = currentProgress(context: context, at: timeline.date)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: context.attributes.themeNeon) ?? .blue)
                            .frame(width: 8, height: 8)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                }
            } compactTrailing: {
                if context.state.isActive {
                    // Calculate the effective start date accounting for elapsed time
                    let effectiveStart = context.state.startDate.addingTimeInterval(-context.state.elapsedTime)
                    Text(timerInterval: effectiveStart...Date.distantFuture, countsDown: false)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text(formatCompactTime(context.state.elapsedTime))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            } minimal: {
                Circle()
                    .fill(Color(hex: context.attributes.themeNeon) ?? .blue)
                    .frame(width: 12, height: 12)
            }
            .keylineTint(Color(hex: context.attributes.themeNeon))
        }
    }
}

// MARK: - Lock Screen View

struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<MomentumWidgetAttributes>
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timelineContext in
            HStack(alignment: .center, spacing: 16) {
                CircularProgressView(
                    progress: currentProgress(at: timelineContext.date),
                    lineWidth: 8,
                    size: 60,
                    foregroundColor: Color(hex: context.attributes.themeNeon) ?? .blue,
                    backgroundColor: Color(hex: context.attributes.themeDark)?.opacity(0.3) ?? .gray.opacity(0.3),
                    animateOnAppear: false
                )
                .overlay {
                    Text("\(Int(currentProgress(at: timelineContext.date) * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.goalTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        if context.state.isActive {
                            // Calculate the effective start date accounting for elapsed time
                            let effectiveStart = context.state.startDate.addingTimeInterval(-context.state.elapsedTime)
                            Text(timerInterval: effectiveStart...Date.distantFuture, countsDown: false)
                                .font(.subheadline)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text(context.state.elapsedTime.formatted(style: .hmmss))
                                .font(.subheadline)
                                .contentTransition(.numericText())
                        }
                        
                        Text("/ \(context.attributes.dailyTarget.formatted(style: .hmmss))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    
                }
                
                Spacer()
                VStack {
                    
                    // Pause/Resume button
                    Button(intent: PauseResumeTimerIntent(sessionID: context.attributes.sessionID, dayID: context.attributes.dayID)) {
                        HStack(spacing: 4) {
                            Image(systemName: context.state.isActive ? "pause.circle.fill" : "play.circle.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    // Stop button
                    Button(intent: StopTimerIntent(sessionID: context.attributes.sessionID, dayID: context.attributes.dayID)) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .font(.title)
            }
            .padding()
        }
    }
    
    private func currentElapsed(at date: Date) -> TimeInterval {
        if context.state.isActive {
            return context.state.elapsedTime + date.timeIntervalSince(context.state.startDate)
        }
        return context.state.elapsedTime
    }
    
    private func currentProgress(at date: Date) -> Double {
        guard context.attributes.dailyTarget > 0 else { return 0 }
        return min(currentElapsed(at: date) / context.attributes.dailyTarget, 1.0)
    }
}

// MARK: - Helper Functions

func currentElapsed(context: ActivityViewContext<MomentumWidgetAttributes>, at date: Date) -> TimeInterval {
    if context.state.isActive {
        return context.state.elapsedTime + date.timeIntervalSince(context.state.startDate)
    }
    return context.state.elapsedTime
}

func currentProgress(context: ActivityViewContext<MomentumWidgetAttributes>, at date: Date) -> Double {
    guard context.attributes.dailyTarget > 0 else { return 0 }
    return min(currentElapsed(context: context, at: date) / context.attributes.dailyTarget, 1.0)
}

func formatCompactTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}

// MARK: - Helper Extensions

extension ActivityViewContext where Attributes == MomentumWidgetAttributes {
    var currentElapsed: TimeInterval {
        if state.isActive {
            return state.elapsedTime + Date.now.timeIntervalSince(state.startDate)
        }
        return state.elapsedTime
    }
    
    var currentProgress: Double {
        guard attributes.dailyTarget > 0 else { return 0 }
        return min(currentElapsed / attributes.dailyTarget, 1.0)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

// MARK: - Preview

extension MomentumWidgetAttributes {
    fileprivate static var preview: MomentumWidgetAttributes {
        MomentumWidgetAttributes(
            sessionID: UUID().uuidString,
            dayID: "2026-02-08",
            goalTitle: "Reading",
            dailyTarget: 3600, // 1 hour
            themeLight: "#93C5FD",
            themeDark: "#1E40AF",
            themeNeon: "#3B82F6"
        )
    }
}

extension MomentumWidgetAttributes.ContentState {
    fileprivate static var active: MomentumWidgetAttributes.ContentState {
        MomentumWidgetAttributes.ContentState(
            elapsedTime: 1800, // 30 minutes
            startDate: Date.now.addingTimeInterval(-300), // Started 5 minutes ago
            isActive: true
        )
    }
     
    fileprivate static var paused: MomentumWidgetAttributes.ContentState {
        MomentumWidgetAttributes.ContentState(
            elapsedTime: 2400, // 40 minutes
            startDate: Date.now,
            isActive: false
        )
    }
}

#Preview("Notification", as: .content, using: MomentumWidgetAttributes.preview) {
   MomentumWidgetLiveActivity()
} contentStates: {
    MomentumWidgetAttributes.ContentState.active
    MomentumWidgetAttributes.ContentState.paused
}
