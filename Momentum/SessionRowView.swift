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
    let onSkip: (GoalSession) -> Void
    var isRecommended: Bool = false
    
    @Environment(GoalStore.self) private var goalStore
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            NavigationLink {
                if let timerManager {
                    ChecklistDetailView(session: session, animation: animation, timerManager: timerManager)
                        .tint(session.goal.primaryTag.themePreset.dark)
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
                            .foregroundStyle(isRecommended ? (session.goal.primaryTag.theme.textColor ?? .primary) : .primary)
                    
                    HStack {
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
                            }
                        } else {
                            Text(session.formattedTime)
                                .fontWeight(.semibold)
                                .font(.footnote)
                            
                            if session.hasMetDailyTarget {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.footnote)
                            }
                        }
                        
                        HealthKitBadge(
                            metric: session.goal.healthKitMetric,
                            isEnabled: session.goal.healthKitSyncEnabled
                        )
                        
                        Spacer()
                    }
                    .opacity(0.7)
                    .foregroundStyle(isRecommended ? session.goal.primaryTag.theme.textColor : (colorScheme == .dark ? session.goal.primaryTag.themePreset.neon : session.goal.primaryTag.themePreset.dark))
                }
                
                Spacer()
                
                // Differentiate HealthKit-synced goals from manual tracking goals
                if session.goal.healthKitSyncEnabled && session.goal.healthKitMetric != nil {
                    let metric = session.goal.healthKitMetric!
                    
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
                        }
                        .foregroundStyle(isRecommended ? session.goal.primaryTag.theme.textColor : session.goal.primaryTag.themePreset.color(for: colorScheme))
                    } else {
                        // Read-only HealthKit metric: Show only log button
                        Button {
                            sessionToLogManually = session
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                        }
                        .foregroundStyle(isRecommended ? session.goal.primaryTag.theme.textColor : session.goal.primaryTag.themePreset.color(for: colorScheme))
                        .opacity(0.6)
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
                            GaugePlayIcon(isActive: isActive, imageName: image, progress: session.progress, color: session.goal.primaryTag.themePreset.color(for: colorScheme), font: .title2, gaugeScale: 0.4)
                                .contentTransition(.symbolEffect(.replace))
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(isRecommended ? (session.goal.primaryTag.theme.textColor ?? .primary) : (colorScheme == .dark ? (session.goal.primaryTag.themePreset.neon ?? .gray) : (session.goal.primaryTag.themePreset.dark ?? .gray)))
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(colorScheme == .dark ? (session.goal.primaryTag.themePreset.light.opacity(0.03) ?? Color(.systemBackground)) : Color(.systemBackground))
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    selectedSession = session
                }
            }
            .matchedTransitionSource(id: session.id, in: animation)

        }
        .swipeActions {
            Button {
                onSkip(session)
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
