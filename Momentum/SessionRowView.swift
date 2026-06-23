import SwiftUI
import SwiftData
import MomentumKit

struct SessionRowView: View {
    let session: GoalSession
    let day: Day
    let timerManager: SessionTimerManager?
    let animation: Namespace.ID
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    var isRecommended: Bool = false
    var useGradientAccents: Bool = false
    var isCompleted: Bool = false
    
    @Environment(GoalStore.self) private var goalStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sessionActions) private var sessionActions
    
    private var tintColor: Color {
        session.theme.color(for: colorScheme)
    }
    
    private var textForegroundColor: Color {
        if isRecommended {
            return session.theme.foregroundColor(for: colorScheme)
        } else {
            return session.theme.color(for: colorScheme)
        }
    }
    
    private var rowBackground: Color {
        if colorScheme == .dark {
            return (session.theme.colors(for: colorScheme).first ?? tintColor).opacity(0.03)
        } else {
            return Color(.systemBackground)
        }
    }
    
    /// Whether this session's timer is currently running
    private var isActive: Bool {
        timerManager?.activeSession?.id == session.id
    }
    
    /// Live progress that updates every timer tick for the active session
    private var liveProgress: Double {
        guard let activeSession = timerManager?.activeSession,
              activeSession.id == session.id else {
            return session.progress
        }
        // Read tickCount to subscribe to timer updates
        _ = activeSession.tickCount
        let liveElapsed = activeSession.elapsedTime + Date().timeIntervalSince(activeSession.startDate)
        guard activeSession.unifiedTargetValue > 0 else { return 0 }
        return liveElapsed / activeSession.unifiedTargetValue
    }
    
    /// Reusable play/stop button with circular progress gauge
    private var gaugeButton: some View {
        Button {
            sessionActions.onToggleTimer?(session)
        } label: {
            let image = isActive ? "stop.circle.fill" : "play.circle.fill"
            let color = isRecommended ? session.theme.foregroundColor(for: colorScheme) : session.theme.color(for: colorScheme)
            GaugePlayIcon(imageName: image, progress: liveProgress, color: color)
        }
        .accessibilityLabel(isActive ? "Stop tracking" : "Start tracking")
    }
    
    var body: some View {
        ZStack {
            NavigationLink {
                if let timerManager, let goal = session.goal {
                    GoalSessionDetailView(goal: goal, session: session, animation: animation, timerManager: timerManager)
                        .tint(tintColor)
                        .environment(goalStore)
                }
            } label: {
                EmptyView()
            }
            .opacity(0)
            
            HStack {
                VStack(alignment: .leading) {
                        Text(session.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(isRecommended ? session.theme.foregroundColor(for: colorScheme) : .primary)
                    
                    HStack {
                        // Check if this is effectively a count-based HealthKit metric goal
                        let isCountBasedMetric = session.goal?.healthKitSyncEnabled == true &&
                            session.goal?.healthKitMetric?.isCountBased == true
                        
                        if session.targetUnit.isTimeBased && !isCountBasedMetric {
                            // Time-based goal — show live timer or formatted time
                            if let activeSession = timerManager?.activeSession,
                               activeSession.id == session.id,
                               let timeText = activeSession.timeText {
                                Text(timeText)
                                    .contentTransition(.numericText())
                                    .fontWeight(.semibold)
                                    .font(.callout)
                                
                                if activeSession.hasMetDailyTarget {
                                    Image(systemName: "checkmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.green)
                                        .font(.footnote)
                                        .accessibilityLabel("Goal completed")
                                }
                            } else {
                                Text(session.formattedTime)
                                    .fontWeight(.semibold)
                                    .font(.callout)
                                
                                if session.hasMetDailyTarget {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.footnote)
                                        .accessibilityLabel("Goal completed")
                                }
                            }
                        } else {
                            // Metric-based goal — show value/target with optional HealthKit icon
                            HStack(spacing: 4) {
                                if let metric = session.goal?.healthKitMetric {
                                    Image(systemName: metric.symbolName)
                                        .font(.footnote)
                                        .accessibilityLabel(metric.displayName)
                                }
                                Text(session.formattedTime)
                                    .fontWeight(.semibold)
                                    .font(.callout)
                            }
                            
                            if session.hasMetDailyTarget {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.footnote)
                                    .accessibilityLabel("Goal completed")
                            }
                        }
                        
                        HealthKitBadge(
                            metric: session.goal?.healthKitMetric,
                            isEnabled: session.goal?.healthKitSyncEnabled == true,
                            color: isRecommended ? session.theme.foregroundColor(for: colorScheme) : .red
                        )
                        
                        if let checklist = session.checklist, !checklist.isEmpty {
                            let completed = checklist.filter(\.isCompleted).count
                            let total = checklist.count
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 9))
                                Text("\(completed)/\(total)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(textForegroundColor.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                }
                
                Spacer()
                
                // Differentiate HealthKit-synced goals from manual tracking goals
                if let goal = session.goal,
                   goal.healthKitSyncEnabled == true,
                   let metric = goal.healthKitMetric {
                    
                    if metric.supportsWrite {
                        // HealthKit metric that supports writing: Show play button with progress gauge
                        gaugeButton
                            .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                    } else {
                        // Read-only HealthKit metric: Show sync button
                        Button {
                            sessionActions.onSyncHealthKit?()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.title)
                                .symbolRenderingMode(.hierarchical)
                                .rotationEffect(.degrees(sessionActions.isSyncingHealthKit ? 360 : 0))
                                .animation(sessionActions.isSyncingHealthKit ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: sessionActions.isSyncingHealthKit)
                        }
                        .accessibilityLabel(sessionActions.isSyncingHealthKit ? "Syncing health data" : "Sync health data")
                        .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                        .disabled(sessionActions.isSyncingHealthKit)
                    }
                } else {
                    // Regular goal: Show standard play/stop button with progress gauge
                    gaugeButton
                        .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                }
            }
            .buttonStyle(.plain)
            .opacity(isCompleted ? 0.6 : 1.0)
            .listRowBackground(rowBackground)
            .onTapGesture {
                HapticFeedbackManager.trigger(.light)
                withAnimation(AnimationPresets.quickSpring) {
                    selectedSession = session
                }
            }
            .matchedTransitionSource(id: session.id, in: animation)

        }
        .swipeActions(edge: .trailing) {
            Button {
                HapticFeedbackManager.trigger(.medium)
                sessionActions.onSkip(session)
            } label: {
                Label {
                    Text(session.status == .skipped ? "Reactivate" : "Skip")
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            if !session.targetUnit.isTimeBased || session.goal?.healthKitSyncEnabled == true {
                Button {
                    HapticFeedbackManager.trigger(.light)
                    sessionToLogManually = session
                } label: {
                    Label("Log", systemImage: "plus.circle.fill")
                }
                .tint(tintColor)
            }
        }
    }
}

// MARK: - Convenience Extensions

// Theme helpers now available as public extension in MomentumKit
