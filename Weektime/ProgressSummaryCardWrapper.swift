//
//  ProgressSummaryCardWrapper.swift
//  Weektime
//
//  Created by Mo Moosa on 23/01/2026.
//

import SwiftUI
import WeektimeKit
// MARK: - Progress Summary Card Wrapper

struct ProgressSummaryCardWrapper: View {
    let session: GoalSession
    let weeklyProgress: Double
    let weeklyElapsedTime: TimeInterval
    @Binding var cardRotationY: Double
    @Binding var shimmerOffset: CGFloat
    let timerManager: SessionTimerManager
    
    var isTimerActive: Bool {
        timerManager.isActive(session)
    }
    
    var body: some View {
        ProgressSummaryCard(
            goalTitle: session.goal.title,
            themeName: session.goal.primaryTheme.title,
            themeColors: session.goal.primaryTheme.theme,
            dailyProgress: session.progress,
            dailyElapsed: session.elapsedTime,
            dailyTarget: session.dailyTarget,
            weeklyProgress: weeklyProgress,
            weeklyElapsed: weeklyElapsedTime,
            weeklyTarget: session.goal.weeklyTarget,
            shimmerOffset: $shimmerOffset,
            isTimerActive: isTimerActive,
            activeSessionDetails: timerManager.activeSession
        )
    }
}

 // MARK: - Progress Summary Card

struct ProgressSummaryCard: View {
    let goalTitle: String
    let themeName: String
    let themeColors: Theme
    let dailyProgress: Double
    let dailyElapsed: TimeInterval
    let dailyTarget: TimeInterval
    let weeklyProgress: Double
    let weeklyElapsed: TimeInterval
    let weeklyTarget: TimeInterval
    
    @Binding var shimmerOffset: CGFloat
    var isTimerActive: Bool = false
    var activeSessionDetails: ActiveSessionDetails?
    
    // Computed property that accesses currentTime to ensure updates when timer is active
    private var currentElapsed: TimeInterval {
        if let activeSession = activeSessionDetails {
            let _ = activeSession.currentTime // Force observation
            return activeSession.elapsedTime + Date.now.timeIntervalSince(activeSession.startDate)
        }
        return dailyElapsed
    }
    
    private var currentProgress: Double {
        guard dailyTarget > 0 else { return 0 }
        return min(currentElapsed / dailyTarget, 1.0)
    }
    
    // Compute text color based on background luminance
    private var textColor: Color {
        // Calculate average luminance of the gradient colors
        let colors = [themeColors.light, themeColors.neon, themeColors.dark]
        let luminances = colors.compactMap { $0.luminance }
        let averageLuminance = luminances.isEmpty ? 0.5 : luminances.reduce(0, +) / Double(luminances.count)
        
        // Use black text if background is light (luminance > 0.5), white otherwise
        return averageLuminance > 0.5 ? .black : .white
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Card background with radial gradient
                LinearGradient(
                    colors: [
//                        themeColors.light,
                        themeColors.neon,
                        themeColors.dark
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 5)
                // Shimmer overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: shimmerOffset, y: shimmerOffset)
                .blur(radius: 20)
                
                // Card content - changes based on timer state
                
                VStack {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(themeName)
                                .font(.subheadline)
                                .foregroundStyle(textColor.opacity(0.8))
                            Text(goalTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(textColor)
                            
                        }
                        Spacer()
                    }
                    if isTimerActive {
                        // Active timer content
                        VStack(alignment: .leading) {
                            HStack {
                                
                                ZStack {
                                    // Background circle
                                    Circle()
                                        .stroke(textColor.opacity(0.3), lineWidth: 12)
                                        .frame(width: 120, height: 120)
                                    
                                    // Progress circle
                                    Circle()
                                        .trim(from: 0, to: currentProgress)
                                        .stroke(
                                            textColor,
                                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                        )
                                        .frame(width: 120, height: 120)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.spring(response: 0.6), value: currentProgress)
                                    
                                    // Time display in center
                                    VStack(spacing: 2) {
                                        Text(formatTimeWithSeconds(currentElapsed))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundStyle(textColor)
                                            .contentTransition(.numericText())
                                        
                                        Text("of \(formatTimeWithSeconds(dailyTarget))")
                                            .font(.caption2)
                                            .foregroundStyle(textColor.opacity(0.7))
                                    }
                                }
                                
                                Spacer()
                                
                                // Progress percentage and completion indicator
                                VStack {
                                    Text("\(Int(currentProgress * 100))% complete")
                                        .font(.headline)
                                        .foregroundStyle(textColor.opacity(0.9))
                                    
                                    // Completion indicator
                                    if currentProgress >= 1.0 {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                            Text("Daily Target Reached!")
                                                .fontWeight(.semibold)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(textColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(textColor.opacity(0.2))
                                        )
                                    }
                                }
                            }
                            // Progress circle
                        }
                        .padding(24)
                        .id("timer-active")
                    } else {
                        // Normal progress summary content
                        VStack(alignment: .leading) {
                            // Progress stats - Vertical layout with horizontal progress bars
                            HStack {
                                // Daily progress
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TODAY")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(textColor.opacity(0.7))
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(formatTimeWithSeconds(dailyElapsed))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(textColor)
                                            .contentTransition(.numericText())
                                        
                                        Text("/ \(formatTimeWithSeconds(dailyTarget))")
                                            .font(.caption)
                                            .foregroundStyle(textColor.opacity(0.7))
                                    }
                                    
                                    // Progress bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(textColor.opacity(0.3))
                                                .frame(height: 6)
                                            
                                            Capsule()
                                                .fill(textColor)
                                                .frame(width: geo.size.width * dailyProgress, height: 6)
                                                .animation(.spring(response: 0.6), value: dailyProgress)
                                        }
                                    }
                                    .frame(height: 6)
                                    
                                    Text("\(Int(dailyProgress * 100))% complete")
                                        .font(.caption)
                                        .foregroundStyle(textColor.opacity(0.8))
                                }
                                
                                // Weekly progress
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("THIS WEEK")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(textColor.opacity(0.7))
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(formatTime(weeklyElapsed))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundStyle(textColor)
                                        
                                        Text("/ \(formatTime(weeklyTarget))")
                                            .font(.caption)
                                            .foregroundStyle(textColor.opacity(0.7))
                                    }
                                    
                                    // Progress bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(textColor.opacity(0.3))
                                                .frame(height: 6)
                                            
                                            Capsule()
                                                .fill(textColor)
                                                .frame(width: geo.size.width * min(weeklyProgress, 1.0), height: 6)
                                                .animation(.spring(response: 0.6), value: weeklyProgress)
                                        }
                                    }
                                    .frame(height: 6)
                                    
                                    Text("\(Int(min(weeklyProgress, 1.0) * 100))% complete")
                                        .font(.caption)
                                        .foregroundStyle(textColor.opacity(0.8))
                                }
                            }
                        }
                        .id("timer-inactive")
                    }
                }
                .padding()

                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: themeColors.dark.opacity(0.4), radius: 20, x: 0, y: 10)
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Add subtle animation when device orientation changes
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    shimmerOffset = shimmerOffset == -200 ? 200 : -200
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        shimmerOffset = -200
                    }
                }
            }
            #endif
        }
        .frame(minHeight: 160)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTimerActive)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTimeWithSeconds(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        } else if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "0:\(String(format: "%02d", seconds))"
        }
    }
}

// MARK: - Color Luminance Extension

extension Color {
    /// Calculates the relative luminance of a color
    /// Returns a value between 0 (darkest) and 1 (lightest)
    var luminance: Double? {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components else { return nil }
        #elseif os(macOS)
        guard let components = NSColor(self).cgColor.components else { return nil }
        #endif
        
        // Ensure we have RGB components
        guard components.count >= 3 else { return nil }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Calculate relative luminance using the standard formula
        // https://www.w3.org/TR/WCAG20/#relativeluminancedef
        let rsRGB = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gsRGB = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bsRGB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        return 0.2126 * rsRGB + 0.7152 * gsRGB + 0.0722 * bsRGB
    }
}
