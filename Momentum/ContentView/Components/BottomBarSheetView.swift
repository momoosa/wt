//
//  BottomBarSheetView.swift
//  Momentum
//
//  Persistent bottom sheet — collapsed shows the bar, expanded shows tab content.
//

import SwiftUI
import SwiftData
import MomentumKit

struct BottomBarSheetView: View {
    let navigation: NavigationState
    let day: Day
    let sessions: [GoalSession]
    let timerManager: SessionTimerManager?
    let planningViewModel: PlanningViewModel
    let animation: Namespace.ID
    @Binding var goalEditorViewModel: GoalEditorViewModel?
    let availableGoalThemes: [GoalTag]
    let onToggleTimer: (GoalSession) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(GoalStore.self) private var goalStore
    @Query private var goals: [Goal]
    
    private var isExpanded: Bool {
        navigation.bottomSheetDetent == .large
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Now playing bar (if active)
            if let timerManager,
               let activeSession = timerManager.activeSession,
               let session = sessions.first(where: { $0.id == activeSession.id }) {
                nowPlayingBar(session: session, details: activeSession)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                // Context info row (idle)
                contextInfoRow
                    .padding(.top, 4)
            }
            
            // Tab bar — always visible
            tabBar
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, isExpanded ? 8 : 0)
            
            // Expanded content — only when sheet is pulled up
            if isExpanded {
                Divider()
                    .padding(.horizontal, 20)
                
                TabView(selection: Binding(
                    get: { navigation.selectedBottomTab },
                    set: { navigation.selectedBottomTab = $0 }
                )) {
                    planTabContent
                        .tag(BottomBarTab.plan)
                    
                    goalsTabContent
                        .tag(BottomBarTab.goals)
                    
                    analyticsTabContent
                        .tag(BottomBarTab.analytics)
                    
                    searchTabContent
                        .tag(BottomBarTab.search)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
    
    // MARK: - Context Info (Idle state)
    
    private var contextInfoRow: some View {
        HStack(spacing: 10) {
            if !availableGoalThemes.isEmpty {
                Text("\(availableGoalThemes.count) themes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("·")
                    .foregroundStyle(.quaternary)
                    .font(.caption)
            }
            
            Text("\(sessions.filter { $0.progress < 1.0 }.count) remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(BottomBarTab.allCases, id: \.self) { tab in
                let isSelected = isExpanded && navigation.selectedBottomTab == tab
                
                Button {
                    if isExpanded {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            navigation.selectedBottomTab = tab
                        }
                    } else {
                        navigation.selectedBottomTab = tab
                        withAnimation {
                            navigation.bottomSheetDetent = .large
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Now Playing Bar
    
    private func nowPlayingBar(session: GoalSession, details: ActiveSessionDetails) -> some View {
        Button {
            navigation.showNowPlaying = true
        } label: {
            HStack(spacing: 10) {
                CircularProgressView(
                    progress: details.progress,
                    lineWidth: 3,
                    size: 34,
                    foregroundColor: session.theme.color(for: colorScheme),
                    backgroundColor: session.theme.color(for: colorScheme).opacity(0.2),
                    animateOnAppear: false
                )
                .overlay {
                    Image(systemName: session.goal?.iconName ?? "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(session.theme.color(for: colorScheme))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    
                    Text("\(details.currentValue.formatted(style: .hmmss)) · \(Int(details.progress * 100))% of \(details.dailyTarget.formatted(style: .hourMinute))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                
                Spacer(minLength: 0)
                
                // Pause / Stop
                HStack(spacing: 6) {
                    Button {
                        navigation.showNowPlaying = true
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(session.theme.foregroundColor(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(session.theme.color(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onToggleTimer(session)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(session.theme.color(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(session.theme.color(for: colorScheme).opacity(0.2), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(session.theme.gradient(for: colorScheme).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Plan Tab
    
    private var planTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's plan")
                        .font(.title.bold())
                    
                    HStack(spacing: 4) {
                        Text(day.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(sessions.count) goals scheduled")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                LazyVStack(spacing: 12) {
                    ForEach(sessions) { session in
                        HStack(spacing: 12) {
                            let theme = session.theme
                            
                            Image(systemName: session.goal?.iconName ?? "target")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.foregroundColor(for: colorScheme))
                                .frame(width: 36, height: 36)
                                .background(theme.gradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.subheadline.weight(.medium))
                                
                                Text(session.formattedTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if session.progress >= 1.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Button {
                    navigation.bottomSheetDetent = .height(120)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigation.showPlannerSheet = true
                    }
                } label: {
                    Label("Generate Plan", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Goals Tab
    
    private var goalsTabContent: some View {
        AllGoalsView(goals: goals, timerManager: timerManager)
    }
    
    // MARK: - Analytics Tab
    
    private var analyticsTabContent: some View {
        DayOverviewView(
            day: day,
            sessions: sessions,
            goals: goals,
            animation: animation,
            timerManager: timerManager,
            healthKitManager: nil,
            selectedSession: .constant(nil),
            sessionToLogManually: .constant(nil)
        )
    }
    
    // MARK: - Search Tab
    
    private var searchTabContent: some View {
        SearchSheet(
            sessions: sessions,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: .constant(nil),
            sessionToLogManually: .constant(nil),
            searchText: .constant(""),
            isGoalValid: { _ in true }
        )
    }
}
