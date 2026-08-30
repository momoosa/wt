//
//  MiniPlayerView.swift
//  Momentum
//
//  Floating mini player bar (Apple Music/Podcasts style) shown above the tab bar
//  when a session timer is active.
//

import SwiftUI
import MomentumKit

struct MiniPlayerView: View {
    let session: GoalSession
    let details: ActiveSessionDetails
    let onTapped: () -> Void
    let onStopTapped: () -> Void
    var onPauseTapped: (() -> Void)?
    var currentIntervalName: String?
    var intervalTimeElapsed: TimeInterval?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 10) {
                CircularProgressView(
                    progress: details.progress,
                    lineWidth: 3,
                    size: 34,
                    foregroundColor: session.theme.color(for: colorScheme),
                    backgroundColor: session.theme.color(for: colorScheme).opacity(0.2),
                    animateOnAppear: false
                )
                .overlay {
                    Image(systemName: session.goal?.iconName ?? "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(session.theme.color(for: colorScheme))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    
                    if let intervalName = currentIntervalName {
                        HStack(spacing: 4) {
                            Text(intervalName)
                            if let elapsed = intervalTimeElapsed {
                                Text("·")
                                Text(formatMiniCountdown(elapsed))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    } else {
                        Text("\(details.currentValue.formatted(style: .hmmss)) · \(Int(details.progress * 100))% of \(details.dailyTarget.formatted(style: .hourMinute))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 6) {
                    // Pause/Resume button
                    Button(action: { onPauseTapped?() }) {
                        Image(systemName: details.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(session.theme.foregroundColor(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(session.theme.color(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Stop button
                    Button(action: onStopTapped) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(session.theme.color(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(session.theme.color(for: colorScheme).opacity(0.2), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    private func formatMiniCountdown(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
