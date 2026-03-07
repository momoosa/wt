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
    
    private var tintColor: Color {
        session.goal?.primaryTag?.themePreset.dark ?? themePresets[0].dark
    }
    
    private var textForegroundColor: Color {
        if isRecommended {
            return session.goal?.primaryTag?.theme.textColor ?? .primary
        } else if colorScheme == .dark {
            return session.goal?.primaryTag?.themePreset.neon ?? .gray
        } else {
            return session.goal?.primaryTag?.themePreset.dark ?? .gray
        }
    }
    
    private var rowBackground: Color {
        if colorScheme == .dark {
            return (session.goal?.primaryTag?.themePreset.light ?? .gray).opacity(0.03)
        } else {
            return Color(.systemBackground)
        }
    }
    
    var body: some View {
        ZStack {
            NavigationLink {
                if let timerManager {
                    ChecklistDetailView(session: session, animation: animation, timerManager: timerManager)
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
                            .foregroundStyle(isRecommended ? (session.goal?.primaryTag?.theme.textColor ?? .primary) : .primary)
                    
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
                            metric: session.goal?.healthKitMetric,
                            isEnabled: session.goal?.healthKitSyncEnabled == true
                        )
                        
                        Spacer()
                    }
                    .opacity(0.7)
                    .foregroundStyle(textForegroundColor)
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
                        }
                        .foregroundStyle(textForegroundColor)
                    } else {
                        // Read-only HealthKit metric: Show only log button
                        Button {
                            sessionToLogManually = session
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                        }
                        .foregroundStyle(textForegroundColor)
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
                            GaugePlayIcon(isActive: isActive, imageName: image, progress: session.progress, color: session.goal?.primaryTag?.themePreset.color(for: colorScheme) ?? themePresets[0].color(for: colorScheme), font: .title2, gaugeScale: 0.4)
                                .contentTransition(.symbolEffect(.replace))
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(textForegroundColor)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(rowBackground)
            .onTapGesture {
                withAnimation(AnimationPresets.quickSpring) {
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
