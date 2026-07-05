//
//  IntervalCompletionView.swift
//  Momentum
//
//  Shown when all intervals in a session have been completed (Design Screen D).
//  Displays a checkmark animation, completion message, and summary.
//

import SwiftUI
import MomentumKit

struct IntervalCompletionView: View {
    let session: GoalSession
    let intervalTimer: IntervalTimerManager
    let onDone: () -> Void
    let onRepeat: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCheckmark = false
    @State private var showContent = false
    
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
                Spacer()
                
                // Checkmark circle
                ZStack {
                    Circle()
                        .fill(foregroundColor.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(foregroundColor)
                        .scaleEffect(showCheckmark ? 1.0 : 0.3)
                        .opacity(showCheckmark ? 1.0 : 0.0)
                }
                
                Spacer()
                    .frame(height: 32)
                
                // Title
                Text("Nicely done")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                
                Spacer()
                    .frame(height: 12)
                
                // Subtitle
                Text("You just completed the entire structure of \(session.goal?.title ?? session.title)")
                    .font(.subheadline)
                    .foregroundStyle(foregroundColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                
                Spacer()
                    .frame(height: 32)
                
                // Summary stats
                summaryStats
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                
                Spacer()
                
                // Action buttons
                actionButtons
                    .opacity(showContent ? 1 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Summary Stats
    
    private var summaryStats: some View {
        HStack(spacing: 24) {
            statItem(
                value: formatDuration(intervalTimer.totalDurationSeconds),
                label: "Total time"
            )
            
            statItem(
                value: "\(intervalTimer.totalIntervals)",
                label: "Intervals"
            )
            
            statItem(
                value: "\(intervalTimer.completedIntervals)",
                label: "Completed"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(foregroundColor.opacity(0.08))
        )
        .padding(.horizontal, 40)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(foregroundColor)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(foregroundColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Repeat button
            Button {
                onRepeat()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body.weight(.semibold))
                    Text("Repeat")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(foregroundColor.opacity(0.15))
                )
            }
            
            // Done button
            Button {
                onDone()
            } label: {
                HStack(spacing: 6) {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(theme.gradient(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(foregroundColor)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}
