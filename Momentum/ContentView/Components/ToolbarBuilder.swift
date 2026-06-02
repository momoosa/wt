//
//  ToolbarBuilder.swift
//  Momentum
//
//  Extracted from ContentView.swift — Toolbar content
//

import SwiftUI
import SwiftData
import MomentumKit
import WeatherKit

// MARK: - Toolbar

extension ContentView {
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button(action: { navigation.showingGoalEditor = true }) {
                    Image(systemName: "plus")
                }
                .matchedTransitionSource(id: "info", in: animation)
                
                Button {
                    navigation.showAllGoals = true
                } label: {
                    Image(systemName: "target")
                }
                
                #if DEBUG
                NavigationLink {
                    ThemePreviewView()
                        .modelContainer(previewOnlyContainer())
                } label: {
                    Text("Themes")
                }
                #endif
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                navigation.showSettings = true
            } label: {
                Image(systemName: "gear")
            }
   
        }
#endif
    }
}

//
//  BottomCapsuleBar.swift
//  Momentum
//
//  Bottom capsule bar — replaces the bottom toolbar.
//

extension ContentView {

    
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
