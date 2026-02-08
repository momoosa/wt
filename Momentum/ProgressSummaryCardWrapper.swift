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
            // Background circle
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

// MARK: - Progress Summary Card Wrapper

struct ProgressSummaryCardWrapper: View {
    let session: GoalSession
    let weeklyProgress: Double
    let weeklyElapsedTime: TimeInterval
    @Binding var cardRotationY: Double
    @Binding var shimmerOffset: CGFloat
    let timerManager: SessionTimerManager
    let onDone: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var isTimerActive: Bool {
        timerManager.isActive(session)
    }
    
    var tintColor: Color {
        colorScheme == .dark ? session.goal.primaryTag.theme.neon : session.goal.primaryTag.theme.dark
    }
    
    var body: some View {
        ProgressSummaryCard(
            goalTitle: session.goal.title,
            themeName: session.goal.primaryTag.title,
            themeColors: session.goal.primaryTag.theme,
            dailyProgress: session.progress,
            dailyElapsed: session.elapsedTime,
            dailyTarget: session.dailyTarget,
            shimmerOffset: $shimmerOffset,
            activeSessionDetails: timerManager.activeSession,
            session: session,
            timerManager: timerManager,
            onDone: onDone,
            onSkip: onSkip
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
    
    @Binding var shimmerOffset: CGFloat
    var activeSessionDetails: ActiveSessionDetails?
    var session: GoalSession?
    var timerManager: SessionTimerManager?
    var onDone: (() -> Void)?
    var onSkip: (() -> Void)?
    
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
        themeColors.textColor
    }
    
    var body: some View {
            ZStack {
                
                VStack(spacing: 0) {
               
                    // Progress summary content
                    HStack(alignment: .center, spacing: 16) {
                            CircularProgressView(
                                progress: currentProgress,
                                lineWidth: 8,
                                size: 80,
                                foregroundColor: textColor,
                                backgroundColor: textColor.opacity(0.3)
                            )
                            .overlay {
                                Text("\(Int(currentProgress * 100))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(textColor)
                                    .contentTransition(.numericText())

                            }
                        
                        
                        // Daily progress text
                        VStack(alignment: .leading, spacing: 8) {
                            
                            Text(goalTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(textColor)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(currentElapsed.formatted(style: .hmmss))
                                    .foregroundStyle(textColor)
                                    .contentTransition(.numericText())
                                
                                Text("/ \(dailyTarget.formatted(style: .hmmss))")
                                    .foregroundStyle(textColor.opacity(0.7))
                                if currentProgress >= 1.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(textColor.opacity(0.8))
                                        .font(.subheadline)
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
                            
                            
                            // Start/Stop button
                            Button {
                                timerManager.toggleTimer(for: session, in: session.day)
                            } label: {
                                let isActive = timerManager.isActive(session)
                                VStack(spacing: 4) {
                                    Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.hierarchical)
                                    Text(isActive ? "Pause" : "Start")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(textColor)
                            }
                            .buttonStyle(.plain)
                                                        
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
                        }
                        .background(.ultraThinMaterial)
                    }
                }
                .background {
                    LinearGradient(
                                   colors: [
               //                        themeColors.light,
                                       themeColors.neon,
                                       themeColors.dark
                                   ],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing
                               )
               
                               
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
            
            .glassCardStyle(shadowColor: themeColors.neon)
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
    
}

