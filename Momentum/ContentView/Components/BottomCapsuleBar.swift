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
            .matchedTransitionSource(id: "plannerButton", in: animation)
            
            Spacer(minLength: 8)
            
            // Right zone: Action buttons
            HStack(spacing: 16) {
                Button { navigation.showDayOverview = true } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .matchedTransitionSource(id: "dayOverviewButton", in: animation)
                
                Button { navigation.isSearching = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .matchedTransitionSource(id: "searchButton", in: animation)
            }
            .padding(.trailing, 16)
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
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(session.theme.gradient(for: colorScheme))
                .frame(width: 24, height: 24)
            
            Text(session.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            
            if let timeText = details.timeText {
                Text(timeText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.leading, 14)
        .foregroundStyle(session.theme.color(for: colorScheme))
    }
}
