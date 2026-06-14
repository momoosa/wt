//
//  ProgressSummaryCardWrapper.swift
//  Momentum
//
//  Created by Mo Moosa on 23/01/2026.
//

import SwiftUI
import MomentumKit

// MARK: - Reusable Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let foregroundColor: Color
    let backgroundColor: Color
    let animateOnAppear: Bool
    /// Optional: previous week's progress at the same time of day (0.0–1.0+).
    /// When provided, renders a subtle marker on the track.
    let previousWeekProgress: Double?
    
    @State private var animatedProgress: Double = 0
    @State private var animatedPreviousProgress: Double = 0
    
    init(
        progress: Double,
        lineWidth: CGFloat = 6,
        size: CGFloat = 44,
        foregroundColor: Color,
        backgroundColor: Color,
        animateOnAppear: Bool = true,
        previousWeekProgress: Double? = nil
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.animateOnAppear = animateOnAppear
        self.previousWeekProgress = previousWeekProgress
    }
    
    var body: some View {
            ZStack {
                // Background circle
                Circle()
                    .stroke(backgroundColor, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                
                // Previous week marker (subtle dot on the track)
                if let _ = previousWeekProgress, animatedPreviousProgress > 0 {
                    let clampedPrev = min(animatedPreviousProgress, 1.0)
                    let angle = Angle.degrees(360 * clampedPrev - 90)
                    let radius = size / 2
                    Circle()
                        .fill(foregroundColor.opacity(0.35))
                        .frame(width: lineWidth + 4, height: lineWidth + 4)
                        .offset(
                            x: radius * cos(angle.radians),
                            y: radius * sin(angle.radians)
                        )
                }
                
                // Main progress arc
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
                    animatedPreviousProgress = previousWeekProgress ?? 0
                }
            } else {
                animatedProgress = progress
                animatedPreviousProgress = previousWeekProgress ?? 0
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(AnimationPresets.slowSpring) {
                animatedProgress = newValue
            }
        }
        .onChange(of: previousWeekProgress) { oldValue, newValue in
            withAnimation(AnimationPresets.slowSpring) {
                animatedPreviousProgress = newValue ?? 0
            }
        }
    }
}

// MARK: - Progress Summary Card Wrapper

struct ProgressSummaryCardWrapper: View {
    let session: GoalSession
    let weeklyProgress: Double
    let weeklyElapsedTime: TimeInterval
    var previousWeekProgress: Double?
    @Binding var cardRotationY: Double
    @Binding var shimmerOffset: CGFloat
    let timerManager: SessionTimerManager
    let onDone: () -> Void
    let onSkip: () -> Void
    let onManualLog: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var isTimerActive: Bool {
        timerManager.isActive(session)
    }
    
    var tintColor: Color {
        let theme = session.theme
        return theme.color(for: colorScheme)
    }

    var body: some View {
        ProgressSummaryCard(
            goalTitle: session.title,
            themeName: session.goal?.primaryTag?.title ?? "Default",
            themeColors: session.theme,
            dailyProgress: session.progress,
            dailyElapsed: session.elapsedTime,
            targetUnit: session.targetUnit,
            currentValue: session.currentValue,
            unifiedTargetValue: session.effectiveTargetValue,
            previousWeekProgress: previousWeekProgress,
            shimmerOffset: $shimmerOffset,
            activeSessionDetails: timerManager.isActive(session) ? timerManager.activeSession : nil,
            session: session,
            timerManager: timerManager,
            onDone: onDone,
            onSkip: onSkip,
            onManualLog: onManualLog
        )
    }
}

 // MARK: - Progress Summary Card

struct ProgressSummaryCard: View {
    let goalTitle: String
    let themeName: String
    let themeColors: ThemePreset
    let dailyProgress: Double
    let dailyElapsed: TimeInterval
    let targetUnit: Goal.TargetUnit
    let currentValue: Double
    let unifiedTargetValue: Double
    /// Previous week's progress (0.0–1.0+) at the same time of day, if available.
    var previousWeekProgress: Double?
    
    @Binding var shimmerOffset: CGFloat
    var activeSessionDetails: ActiveSessionDetails?
    var session: GoalSession?
    var timerManager: SessionTimerManager?
    var onDone: (() -> Void)?
    var onSkip: (() -> Void)?
    var onManualLog: (() -> Void)?
    
    // Computed property that accesses currentTime to ensure updates when timer is active
    private var currentElapsed: TimeInterval {
        if let activeSession = activeSessionDetails {
            let _ = activeSession.currentTime // Force observation
            return activeSession.elapsedTime + Date.now.timeIntervalSince(activeSession.startDate)
        }
        return dailyElapsed
    }
    
    private var currentProgress: Double {
        guard unifiedTargetValue > 0 else { return 0 }
        if targetUnit.isTimeBased {
            return currentElapsed / unifiedTargetValue
        }
        return currentValue / unifiedTargetValue
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Get text color optimized for the theme gradient
    private var textColor: Color {
        themeColors.foregroundColor(for: colorScheme)
    }
    
    var body: some View {
            ZStack {
                
                VStack(spacing: 0) {
               
                    // Progress summary content
                    HStack(alignment: .center, spacing: 16) {
                            CircularProgressView(
                                progress: currentProgress,
                                lineWidth: 8,
                                size: LayoutConstants.ProgressCircle.standardDiameter,
                                foregroundColor: textColor,
                                backgroundColor: textColor.opacity(0.3),
                                previousWeekProgress: previousWeekProgress
                            )
                            .overlay {
                                Text("\(Int(currentProgress * 100))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(textColor)
                                    .contentTransition(.numericText())

                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(Int(currentProgress * 100)) percent progress")
                        
                        
                        // Daily progress text
                        VStack(alignment: .leading, spacing: 8) {
                            
                            HStack {
                                Text(goalTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(textColor)
                                
                                if let activeSession = activeSessionDetails, activeSession.isPaused {
                                    Text("Paused")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(textColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(textColor.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                if targetUnit.isTimeBased {
                                    Text(currentElapsed.formatted(style: .hmmss))
                                        .foregroundStyle(textColor)
                                        .contentTransition(.numericText())
                                    
                                    Text("/ \(unifiedTargetValue.formatted(style: .hmmss))")
                                        .foregroundStyle(textColor.opacity(0.7))
                                } else {
                                    Text("\(Int(currentValue).formatted())")
                                        .foregroundStyle(textColor)
                                        .contentTransition(.numericText())
                                    
                                    Text("/ \(Int(unifiedTargetValue).formatted()) \(targetUnit.label)")
                                        .foregroundStyle(textColor.opacity(0.7))
                                }
                                if currentProgress >= 1.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(textColor.opacity(0.8))
                                        .font(.subheadline)
                                        .accessibilityLabel("Goal completed")
                                }
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Action Buttons (if provided)
                    if let session = session, let timerManager = timerManager, let onDone = onDone, let onSkip = onSkip {
                        
                        HStack(spacing: 0) {
                            
                            // Determine if goal is read-only (HealthKit goal that doesn't support writing)
                            let isReadOnly = session.goal?.healthKitSyncEnabled == true && 
                                           session.goal?.healthKitMetric?.supportsWrite == false
                            
                            // Start/Stop button (only show if NOT read-only)
                            if !isReadOnly {
                                Button {
                                    if let day = session.day {
                                        timerManager.toggleTimer(for: session, in: day)
                                    }
                                } label: {
                                    let isActive = timerManager.isActive(session)
                                    let isPaused = isActive && (timerManager.activeSession?.isPaused ?? false)
                                    VStack(spacing: 4) {
                                        Image(systemName: isPaused ? "play.circle.fill" : (isActive ? "pause.circle.fill" : "play.circle.fill"))
                                            .font(.title2)
                                            .symbolRenderingMode(.hierarchical)
                                        Text(isPaused ? "Resume" : (isActive ? "Pause" : "Start"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(textColor)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Manual Log button
                            if let onManualLog = onManualLog {
                                Button {
                                    onManualLog()
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "square.and.pencil")
                                            .font(.title2)
                                            .symbolRenderingMode(.hierarchical)
                                        Text("Log")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(textColor.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                                                        
                            // Skip button
                            Button {
                                onSkip()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "forward.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.hierarchical)
                                    Text(session.status == .skipped ? "Undo Skip" : "Skip")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(textColor.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            
                            // Mark as Done button
                            Button {
                                onDone()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.hierarchical)
                                    Text("Done")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(textColor)
                            }
                            .buttonStyle(.plain)
                        }

                            
                    }
                }
                .background {
                    themeColors.gradient(for: colorScheme)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
            
            .glassCardStyle(shadowColor: themeColors.color(for: colorScheme))
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Add subtle animation when device orientation changes
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    shimmerOffset = shimmerOffset == -200 ? 200 : -200
                }
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        shimmerOffset = -200
                    }
                }
            }
            #endif
    }
    
}

