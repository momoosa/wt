//
//  BottomAccessoryBarView.swift
//  Momentum
//
//  Extracted from ContentView to isolate timer observation.
//  Only this view re-renders on timer ticks, not the entire ContentView.
//

import SwiftUI
import MomentumKit

struct BottomAccessoryBarView: View {
    let sessions: [GoalSession]
    let timerManager: SessionTimerManager?
    let navigation: NavigationState
    let planningViewModel: PlanningViewModel
    let weatherManager: WeatherManager
    let showPlanButton: Bool
    @Binding var isMiniPlayerVisible: Bool
    let onTimerToggle: (GoalSession) -> Void
    let onShowPlannerSheet: () -> Void
    
    private var miniPlayerSession: (GoalSession, ActiveSessionDetails)? {
        guard let timerManager,
              let activeSession = timerManager.activeSession,
              let session = sessions.first(where: { $0.id == activeSession.id }) else {
            return nil
        }
        return (session, activeSession)
    }
    
    private var showMiniPlayer: Bool {
        miniPlayerSession != nil && !navigation.showNowPlaying
    }
    
    var body: some View {
        if showMiniPlayer || showPlanButton {
            VStack(spacing: 8) {
                if let toastConfig = navigation.toastConfig {
                    BottomAccessoryToastView(
                        config: toastConfig,
                        onDismiss: {
                            withAnimation {
                                navigation.toastConfig = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                HStack(spacing: 8) {
                    if showPlanButton {
                        PlanButtonView(
                            planningViewModel: planningViewModel,
                            weatherManager: weatherManager,
                            expanded: !isMiniPlayerVisible,
                            onTapped: onShowPlannerSheet
                        )
                    }
                    
                    if let (session, details) = miniPlayerSession {
                        MiniPlayerView(
                            session: session,
                            details: details,
                            onTapped: {
                                navigation.showNowPlaying = true
                            },
                            onStopTapped: {
                                onTimerToggle(session)
                            },
                            onPauseTapped: {
                                if details.isPaused {
                                    timerManager?.resumeTimer()
                                } else {
                                    timerManager?.pauseTimer()
                                }
                            },
                            currentIntervalName: timerManager?.currentIntervalName,
                            intervalTimeElapsed: timerManager?.intervalTimeElapsed
                        )
                        .transition(.blurReplace)
                    }
                }
                .animation(.smooth(duration: 0.4), value: isMiniPlayerVisible)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onChange(of: showMiniPlayer) { _, newValue in
                withAnimation(.smooth(duration: 0.4)) {
                    isMiniPlayerVisible = newValue
                }
            }
        }
    }
}

/// Plan button extracted to its own view for isolation
struct PlanButtonView: View {
    let planningViewModel: PlanningViewModel
    let weatherManager: WeatherManager
    let expanded: Bool
    let onTapped: () -> Void
    
    var body: some View {
        Button {
            if planningViewModel.isPlanning {
                planningViewModel.cancelPlanning()
            } else {
                onTapped()
            }
        } label: {
            HStack(spacing: 8) {
                if expanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            planPill(
                                icon: "clock",
                                label: planningViewModel.availableTimeMinutes > 0
                                    ? "\(planningViewModel.availableTimeMinutes)m"
                                    : "ANY"
                            )
                            
                            if let weather = planningViewModel.selectedWeather ?? weatherManager.getCurrentCondition() {
                                planPill(
                                    icon: weather.icon,
                                    label: weather.displayName.uppercased()
                                )
                            }
                            
                            planPill(
                                icon: "square.grid.2x2",
                                label: planningViewModel.selectedThemes.isEmpty
                                    ? "ALL THEMES"
                                    : "\(planningViewModel.selectedThemes.count) THEME\(planningViewModel.selectedThemes.count == 1 ? "" : "S")"
                            )
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // Sparkles icon (always visible). Uses concrete label/background
                // colors so it stays a solid dark circle inside the glass accessory
                // instead of being washed out to white by material vibrancy.
                Group {
                    if planningViewModel.isPlanning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color(.systemBackground))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color(.label), in: Circle())
                .foregroundStyle(Color(.systemBackground))
                .padding(.trailing, expanded ? 4 : 0)
            }
            .padding(expanded ? 4 : 0)
        }
        .buttonStyle(.plain)
    }
    
    private func planPill(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }
}
