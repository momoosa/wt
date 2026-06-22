import SwiftUI
import SwiftData
import MomentumKit

struct RecommendedSessionRowView: View {
    let session: GoalSession
    let day: Day
    let index: Int
    let timerManager: SessionTimerManager?
    let animation: Namespace.ID
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sessionActions) private var sessionActions
    @Environment(GoalStore.self) private var goalStore
    
    private var themePreset: ThemePreset { session.theme }
    private var foreground: Color { themePreset.foregroundColor(for: colorScheme) }
    
    private var isActive: Bool {
        timerManager?.activeSession?.id == session.id
    }
    
    private var liveProgress: Double {
        guard let activeSession = timerManager?.activeSession,
              activeSession.id == session.id else {
            return session.progress
        }
        _ = activeSession.tickCount
        let liveElapsed = activeSession.elapsedTime + Date().timeIntervalSince(activeSession.startDate)
        guard activeSession.unifiedTargetValue > 0 else { return 0 }
        return liveElapsed / activeSession.unifiedTargetValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Number + Category + TOP PICK badge
            HStack {
                Text(session.title)
                    .font(.title2.bold())
                    .foregroundStyle(foreground)

                Spacer()
                
                Text("\(Self.ordinalFormatter.string(from: index as NSNumber) ?? "\(index)") PICK".uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(foreground.opacity(0.15), in: Capsule())
            }
            .foregroundStyle(foreground.opacity(0.8))
            
            // Row 2: Title
            
            // Row 3: Reason chips
            let reasons = Array(session.safeRecommendationReasons.prefix(3))
            if !reasons.isEmpty {
                HStack(spacing: 6) {
                    ForEach(reasons, id: \.self) { reason in
                        HStack(spacing: 3) {
                            Image(systemName: iconForReason(reason))
                                .font(.system(size: 8))
                            Text(reason.displayName.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.3)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(foreground.opacity(0.15), in: Capsule())
                    }
                }
                .foregroundStyle(foreground.opacity(0.9))
            }
            
            // Row 4: Progress + play button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROGRESS")
                        .font(.caption2.weight(.medium))
                        .tracking(0.5)
                        .foregroundStyle(foreground.opacity(0.6))
                    
                    if let activeSession = timerManager?.activeSession,
                       activeSession.id == session.id,
                       let timeText = activeSession.timeText {
                        Text(timeText)
                            .font(.title.bold())
                            .foregroundStyle(foreground)
                            .contentTransition(.numericText())
                    } else {
                        Text(session.formattedTime)
                            .font(.title.bold())
                            .foregroundStyle(foreground)
                    }
                }
                
                Spacer()
                
                if let goal = session.goal,
                   goal.healthKitSyncEnabled,
                   let metric = goal.healthKitMetric,
                   !metric.supportsWrite {
                    // Read-only HealthKit metric: sync button with progress ring
                    Button {
                        sessionActions.onSyncHealthKit?()
                    } label: {
                        GaugePlayIcon(
                            imageName: "arrow.triangle.2.circlepath.circle.fill",
                            progress: liveProgress,
                            color: foreground,
                            size: 44,
                            lineWidth: 3
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sync health data")
                } else {
                    // Regular or HealthKit-writable goal: play/stop button
                    Button {
                        sessionActions.onToggleTimer?(session)
                    } label: {
                        GaugePlayIcon(
                            imageName: isActive ? "stop.circle.fill" : "play.circle.fill",
                            progress: liveProgress,
                            color: foreground,
                            size: 44,
                            lineWidth: 3
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isActive ? "Stop tracking" : "Start tracking")
                }
            }
        }
        .padding(20)
        .listRowInsets(EdgeInsets())
        .listRowBackground(
            themePreset.gradient(for: colorScheme)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        )
        .onTapGesture {
            HapticFeedbackManager.trigger(.light)
            withAnimation(AnimationPresets.quickSpring) {
                selectedSession = session
            }
        }
        .matchedTransitionSource(id: session.id, in: animation)
        .swipeActions {
            Button {
                HapticFeedbackManager.trigger(.medium)
                sessionActions.onSkip(session)
            } label: {
                Label(session.status == .skipped ? "Reactivate" : "Skip", systemImage: "xmark.circle.fill")
            }
            .tint(.orange)
        }
    }
    
    // MARK: - Helpers
    
    private static let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()
    
    private func iconForReason(_ reason: RecommendationReason) -> String {
        switch reason {
        case .weeklyProgress: return "chart.line.uptrend.xyaxis"
        case .userPriority: return "star.fill"
        case .weather: return "sun.max.fill"
        case .availableTime: return "clock.fill"
        case .plannedTheme: return "calendar"
        case .quickFinish: return "flag.checkered"
        case .preferredTime: return "heart.fill"
        case .usualTime: return "clock.arrow.circlepath"
        case .constrained: return "hourglass"
        }
    }
}
