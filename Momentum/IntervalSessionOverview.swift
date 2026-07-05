//
//  IntervalSessionOverview.swift
//  Momentum
//
//  Pre-session view showing the interval list for a goal session (Design Screen A).
//  Displays goal name, ordered intervals with durations, and a "Start session" button.
//

import SwiftUI
import MomentumKit

struct IntervalSessionOverview: View {
    let session: GoalSession
    let listSession: IntervalListSession
    let onStart: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var theme: ThemePreset {
        session.theme
    }
    
    private var foregroundColor: Color {
        theme.foregroundColor(for: colorScheme)
    }
    
    private var sortedIntervals: [IntervalSession] {
        (listSession.intervals ?? []).sorted {
            ($0.interval?.orderIndex ?? 0) < ($1.interval?.orderIndex ?? 0)
        }
    }
    
    private var totalDuration: TimeInterval {
        TimeInterval(sortedIntervals.reduce(0) { $0 + ($1.interval?.durationSeconds ?? 0) })
    }
    
    var body: some View {
        ZStack {
            theme.gradient(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection
                        
                        // Interval list
                        intervalListSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                
                // Start button
                startButton
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
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
            
            Text(session.goal?.primaryTag?.title.uppercased() ?? "")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(foregroundColor.opacity(0.7))
            
            Spacer()
            
            // Balance spacer
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.goal?.title ?? session.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)
            
            HStack(spacing: 8) {
                Label(
                    "\(sortedIntervals.count) moves",
                    systemImage: "list.bullet"
                )
                
                Text("·")
                    .foregroundStyle(foregroundColor.opacity(0.4))
                
                Label(
                    totalDuration.formatted(style: .hourMinute),
                    systemImage: "clock"
                )
            }
            .font(.subheadline)
            .foregroundStyle(foregroundColor.opacity(0.7))
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Interval List
    
    private var intervalListSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedIntervals.enumerated()), id: \.element.id) { index, intervalSession in
                intervalRow(intervalSession, index: index)
                
                if index < sortedIntervals.count - 1 {
                    Divider()
                        .background(foregroundColor.opacity(0.1))
                        .padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(foregroundColor.opacity(0.08))
        )
        .padding(.horizontal, 20)
    }
    
    private func intervalRow(_ intervalSession: IntervalSession, index: Int) -> some View {
        HStack(spacing: 12) {
            // Index circle
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.gradient(for: colorScheme))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(foregroundColor)
                )
            
            // Interval info
            VStack(alignment: .leading, spacing: 2) {
                Text(intervalSession.interval?.name ?? "Interval")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(foregroundColor)
                
                if let interval = intervalSession.interval {
                    Text(intervalKindLabel(interval))
                        .font(.caption)
                        .foregroundStyle(foregroundColor.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Duration
            if let duration = intervalSession.interval?.durationSeconds {
                Text(formatDuration(duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(foregroundColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Start Button
    
    private var startButton: some View {
        Button {
            HapticFeedbackManager.trigger(.medium)
            onStart()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.body.weight(.semibold))
                Text("Start session")
                    .font(.headline)
            }
            .foregroundStyle(theme.gradient(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(foregroundColor)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helpers
    
    private func intervalKindLabel(_ interval: Interval) -> String {
        switch interval.kind {
        case .work:
            return "Exercise"
        case .breakTime:
            return "Rest"
        }
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
}
