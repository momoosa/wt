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
            return session.theme.colors(for: colorScheme).first!.opacity(0.03)
        } else {
            return Color(.systemBackground)
        }
    }
    
    var body: some View {
        ZStack {
            NavigationLink {
                if let timerManager {
                    GoalSessionDetailView(session: session, animation: animation, timerManager: timerManager)
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
                        if session.targetUnit.isTimeBased {
                            // Time-based goal — show live timer or formatted time
                            if let activeSession = timerManager?.activeSession,
                               activeSession.id == session.id,
                               let timeText = activeSession.timeText {
                                Text(timeText)
                                    .contentTransition(.numericText())
                                    .fontWeight(.semibold)
                                    .font(.footnote)
                                
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
                                    .font(.footnote)
                                
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
                                }
                                Text(session.formattedTime)
                                    .fontWeight(.semibold)
                                    .font(.footnote)
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
                        // HealthKit metric that supports writing: Show BOTH play button AND log button
                        HStack(spacing: 12) {
                            // Play button for live tracking (writes to HealthKit when stopped)
                            Button {
                                timerManager?.toggleTimer(for: session, in: day)
                            } label: {
                                let isActive = timerManager?.activeSession?.id == session.id
                                let image = isActive ? "stop.circle.fill" : "play.circle.fill"
                                Image(systemName: image)
                                    .font(.title2)
                            }
                            .accessibilityLabel(timerManager?.activeSession?.id == session.id ? "Stop tracking" : "Start tracking")
                        }
                        .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                    } else {
                        // Read-only HealthKit metric: Show sync button
                        Button {
                            sessionActions.onSyncHealthKit?()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.title2)
                                .rotationEffect(.degrees(sessionActions.isSyncingHealthKit ? 360 : 0))
                                .animation(sessionActions.isSyncingHealthKit ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: sessionActions.isSyncingHealthKit)
                        }
                        .accessibilityLabel(sessionActions.isSyncingHealthKit ? "Syncing health data" : "Sync health data")
                        .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                        .disabled(sessionActions.isSyncingHealthKit)
                    }
                } else {
                    // Regular goal: Show standard play/stop button (live tracking)
                    Button {
                        timerManager?.toggleTimer(for: session, in: day)
                    } label: {
                        let isActive = timerManager?.activeSession?.id == session.id
                        let image = isActive ? "stop.circle.fill" : "play.circle.fill"
                        
                        if isRecommended {
                            Image(systemName: image)
                                .contentTransition(.symbolEffect(.replace))
                                .font(.title2)
                        } else {
                            GaugePlayIcon(isActive: isActive, imageName: image, progress: session.progress, color: session.theme.color(for: colorScheme), font: .title2, gaugeScale: 0.4)
                                .contentTransition(.symbolEffect(.replace))
                                .font(.title2)
                        }
                    }
                    .accessibilityLabel(timerManager?.activeSession?.id == session.id ? "Stop tracking" : "Start tracking")
                    .foregroundStyle(useGradientAccents ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(textForegroundColor))
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(rowBackground)
            .onTapGesture {
                HapticFeedbackManager.trigger(.light)
                withAnimation(AnimationPresets.quickSpring) {
                    selectedSession = session
                }
            }
            .matchedTransitionSource(id: session.id, in: animation)

        }
        .swipeActions {
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
    }
}

// MARK: - Convenience Extensions

// Theme helpers now available as public extension in MomentumKit
