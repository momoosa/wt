//
//  IntervalPlaybackView.swift
//  Momentum
//
//  Active interval playback view with countdown timer (Design Screens B + C).
//  Shows large countdown for the current interval, transition screens between
//  intervals, and a scrollable list of all intervals with progress.
//

import SwiftUI
import MomentumKit

struct IntervalPlaybackView: View {
    let session: GoalSession
    @Bindable var intervalTimer: IntervalTimerManager
    let onStop: () -> Void
    let onComplete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    private var theme: ThemePreset {
        session.theme
    }
    
    private var foregroundColor: Color {
        theme.foregroundColor(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            theme.gradient(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                switch intervalTimer.phase {
                case .transition:
                    transitionView
                case .completed:
                    // Handled by parent via onComplete callback
                    EmptyView()
                default:
                    playbackContent
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: intervalTimer.phase) { _, newPhase in
            if newPhase == .completed {
                onComplete()
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button {
                intervalTimer.stop()
                onStop()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(foregroundColor.opacity(0.15))
                    )
            }
            
            Spacer()
            
            // Interval counter
            Text("\(intervalTimer.currentIntervalIndex + 1) of \(intervalTimer.totalIntervals)")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundStyle(foregroundColor.opacity(0.7))
            
            Spacer()
            
            // Overall time remaining
            Text(formatTimeInterval(intervalTimer.totalTimeRemaining))
                .font(.caption.monospacedDigit())
                .foregroundStyle(foregroundColor.opacity(0.5))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Playback Content (Screen B)
    
    private var playbackContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Current interval name
            VStack(spacing: 6) {
                Text(intervalTimer.currentIntervalName ?? "Interval")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
                
                if let interval = intervalTimer.currentInterval {
                    Text(kindSubtitle(interval))
                        .font(.caption)
                        .foregroundStyle(foregroundColor.opacity(0.6))
                }
            }
            
            Spacer()
                .frame(height: 32)
            
            // Countdown ring
            countdownRing
            
            Spacer()
                .frame(height: 32)
            
            // Controls
            controlButtons
            
            Spacer()
                .frame(height: 20)
            
            // Interval list
            intervalList
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - Countdown Ring
    
    private var countdownRing: some View {
        ZStack {
            let ringSize: CGFloat = 240
            let lineWidth: CGFloat = 10
            let progress = intervalTimer.currentIntervalProgress
            
            // Background ring
            Circle()
                .stroke(foregroundColor.opacity(0.15), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    foregroundColor.opacity(0.8),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            
            // Countdown text
            VStack(spacing: 4) {
                Text(formatCountdown(intervalTimer.secondsRemaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: intervalTimer.secondsRemaining)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(foregroundColor.opacity(0.5))
            }
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Previous
            Button {
                intervalTimer.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(foregroundColor.opacity(0.15))
                    )
            }
            
            // Play/Pause
            Button {
                intervalTimer.togglePause()
            } label: {
                Image(systemName: intervalTimer.phase == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.gradient(for: colorScheme))
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(foregroundColor)
                            .shadow(color: foregroundColor.opacity(0.3), radius: 12, x: 0, y: 4)
                    )
            }
            
            // Next
            Button {
                intervalTimer.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(foregroundColor.opacity(0.15))
                    )
            }
        }
    }
    
    // MARK: - Interval List
    
    private var intervalList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(intervalTimer.intervalSessions.enumerated()), id: \.element.id) { index, intervalSession in
                        intervalListRow(intervalSession, index: index)
                            .id(intervalSession.id)
                        
                        if index < intervalTimer.intervalSessions.count - 1 {
                            Divider()
                                .foregroundStyle(foregroundColor.opacity(0.1))
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: intervalTimer.currentIntervalIndex) { _, newIndex in
                if newIndex < intervalTimer.intervalSessions.count {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(intervalTimer.intervalSessions[newIndex].id, anchor: .center)
                    }
                }
            }
        }
        .background(foregroundColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    private func intervalListRow(_ intervalSession: IntervalSession, index: Int) -> some View {
        let isCurrent = index == intervalTimer.currentIntervalIndex
        let isCompleted = intervalSession.isCompleted
        let interval = intervalSession.interval
        
        return HStack(spacing: 12) {
            // Numbered circle
            ZStack {
                Circle()
                    .fill(isCurrent ? foregroundColor : foregroundColor.opacity(isCompleted ? 0.1 : 0.08))
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(foregroundColor.opacity(0.5))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isCurrent ? AnyShapeStyle(theme.gradient(for: colorScheme)) : AnyShapeStyle(foregroundColor.opacity(0.6)))
                }
            }
            
            // Interval name
            VStack(alignment: .leading, spacing: 2) {
                Text(interval?.name ?? "Interval")
                    .font(.subheadline.weight(isCurrent ? .semibold : .medium))
                    .foregroundStyle(
                        isCurrent ? foregroundColor : foregroundColor.opacity(isCompleted ? 0.4 : 0.8)
                    )
                    .lineLimit(1)
                
                if isCurrent, let kind = interval?.kind {
                    Text(kind == .work ? "In progress" : "Rest")
                        .font(.caption2)
                        .foregroundStyle(foregroundColor.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Duration
            if let duration = interval?.durationSeconds {
                Text(formatDuration(duration))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(
                        isCurrent ? foregroundColor : foregroundColor.opacity(isCompleted ? 0.3 : 0.5)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isCurrent ?
                AnyShapeStyle(foregroundColor.opacity(0.12)) :
                AnyShapeStyle(Color.clear)
        )
    }
    
    // MARK: - Transition View (Screen C)
    
    private var transitionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Next interval preview
            if let next = intervalTimer.currentInterval {
                Text("NEXT UP")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundStyle(foregroundColor.opacity(0.5))
                
                Spacer()
                    .frame(height: 12)
                
                Text(next.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
            }
            
            Spacer()
                .frame(height: 40)
            
            // Large countdown number
            Text("\(intervalTimer.transitionSecondsRemaining)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.3), value: intervalTimer.transitionSecondsRemaining)
            
            Spacer()
                .frame(height: 24)
            
            Text("Ease into position, breathe")
                .font(.subheadline)
                .foregroundStyle(foregroundColor.opacity(0.6))
            
            Spacer()
            
            // Skip transition button
            Button {
                intervalTimer.resume()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(foregroundColor.opacity(0.15))
                )
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helpers
    
    private func kindSubtitle(_ interval: Interval) -> String {
        switch interval.kind {
        case .work:
            return "Hold the position, breathe through it"
        case .breakTime:
            return "Rest and recover"
        }
    }
    
    private func formatCountdown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return String(format: "00:%02d", secs)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
