//
//  BottomCapsuleBar.swift
//  Momentum
//
//  Bottom capsule bar — replaces the bottom toolbar.
//

import SwiftUI
import WeatherKit
import MomentumKit

// MARK: - Bottom Capsule Bar

extension ContentView {
    
    var bottomCapsuleBar: some View {
        HStack(spacing: 0) {
            // Left zone: Context info or now-playing
            Button {
                if let timerManager,
                   timerManager.activeSession != nil {
                    navigation.showNowPlaying = true
                } else {
                    planningViewModel.cachedThemes = availableGoalThemes
                    navigation.showPlannerSheet = true
                }
            } label: {
                if let timerManager,
                   let activeSession = timerManager.activeSession,
                   let session = sessions.first(where: { $0.id == activeSession.id }) {
                    capsuleNowPlaying(session: session, details: activeSession)
                } else {
                    capsuleContextInfo
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .matchedTransitionSource(id: "plannerButton", in: animation)
            
            Spacer(minLength: 8)
            
            // Right zone: Action buttons
            HStack(spacing: 4) {
                Button { navigation.showDayOverview = true } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .matchedTransitionSource(id: "dayOverviewButton", in: animation)
                
                Button { navigation.isSearching = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .matchedTransitionSource(id: "searchButton", in: animation)
            }
            .padding(.trailing, 8)
        }
        .frame(height: 52)
        .glassEffect(in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .onLongPressGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                navigation.showExpandedCapsule = true
            }
        }
    }
    
    // MARK: - Capsule Content: Context Info (Idle)
    
    private var capsuleContextInfo: some View {
        HStack(spacing: 8) {
            if let weather = weatherManager.currentWeather {
                Image(systemName: weatherSymbol(for: weather.condition))
                    .foregroundStyle(.orange)
                    .font(.callout)
                
                Text("\(Int(weather.temperature.value))°")
                    .font(.subheadline.weight(.medium))
                
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            
            Text(freeTimeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 16)
    }
    
    // MARK: - Capsule Content: Now Playing (Active Session)
    
    private func capsuleNowPlaying(session: GoalSession, details: ActiveSessionDetails) -> some View {
        HStack(spacing: 10) {
            CircularProgressView(
                progress: details.progress,
                lineWidth: 3.5,
                size: 38,
                foregroundColor: session.theme.color(for: colorScheme),
                backgroundColor: session.theme.color(for: colorScheme).opacity(0.2),
                animateOnAppear: false
            )
            .overlay {
                Image(systemName: session.goal?.iconName ?? "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(session.theme.color(for: colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(session.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                Text(details.currentValue.formatted(style: .hmmss))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 12)
        }
        .padding(.leading, 10)
        .foregroundStyle(session.theme.color(for: colorScheme))
    }
}
