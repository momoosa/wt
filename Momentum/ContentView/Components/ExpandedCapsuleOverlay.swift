//
//  ExpandedCapsuleOverlay.swift
//  Momentum
//
//  Expanded capsule overlay — shown on long-press of the bottom capsule.
//

import SwiftUI
import WeatherKit
import MomentumKit

// MARK: - Expanded Capsule Overlay

extension ContentView {
    
    var expandedCapsuleOverlay: some View {
        let vm = progressViewModel
        
        return VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                // Drag handle
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                // Progress ring + stats
                HStack(spacing: 20) {
                    CircularProgressView(
                        progress: vm.dailyProgress,
                        foregroundColor: .blue,
                        backgroundColor: Color.blue.opacity(0.4)
                    )
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(Int(vm.dailyProgress * 100))%")
                                .font(.caption.bold())
                        }
                    }
                    .frame(width: 56, height: 56)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Progress")
                            .font(.subheadline.weight(.semibold))
                        Text("\(vm.completedGoalsCount) of \(vm.totalActiveGoals) goals completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .onTapGesture {
                    withAnimation { navigation.showExpandedCapsule = false }
                    navigation.showDayOverview = true
                }
                
                // Quick info chips
                HStack(spacing: 12) {
                    if let weather = weatherManager.currentWeather {
                        expandedInfoChip(
                            icon: weatherSymbol(for: weather.condition),
                            text: "\(Int(weather.temperature.value))°",
                            color: .orange
                        )
                    }
                    
                    expandedInfoChip(
                        icon: "clock.fill",
                        text: freeTimeText,
                        color: .blue
                    )
                }
                .padding(.horizontal, 20)
                
                // Focus themes
                if !availableGoalThemes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus Themes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableGoalThemes) { tag in
                                    let theme = ThemeStore.resolve(for: tag.themeID)
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.color(for: colorScheme))
                                            .frame(width: 8, height: 8)
                                        Text(tag.title)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(theme.color(for: colorScheme).opacity(0.15), in: Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Generate plan button
                Button {
                    withAnimation { navigation.showExpandedCapsule = false }
                    planningViewModel.cachedThemes = availableGoalThemes
                    navigation.showPlannerSheet = true
                } label: {
                    Label("Generate Plan", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, y: -4)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .background {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        navigation.showExpandedCapsule = false
                    }
                }
        }
    }
    
    // MARK: - Expanded Overlay Helpers
    
    private func expandedInfoChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}
