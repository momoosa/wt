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
        
    
//  
//        
//        ToolbarItem(placement: .bottomBar) {
//            Button {
//                if let timerManager,
//                   timerManager.activeSession != nil {
//                    navigation.showNowPlaying = true
//                } else {
//                    planningViewModel.cachedThemes = availableGoalThemes
//                    navigation.showPlannerSheet = true
//                }
//            } label: {
//                if let timerManager,
//                   let activeSession = timerManager.activeSession,
//                   let session = sessions.first(where: { $0.id == activeSession.id }) {
//                    capsuleNowPlaying(session: session, details: activeSession)
//                } else {
//                    capsuleContextInfo
//                }
//            }
////            Button {
////                navigation.isSearching = true
////            } label: {
////                Label("Search", systemImage: "magnifyingglass")
////            }
////            .matchedTransitionSource(id: "searchButton", in: animation)
//        }
//        
//        
//        
//        ToolbarItem(placement: .bottomBar) {
//            Button {
//                navigation.showDayOverview = true
//            } label: {
//                Image(systemName: "chart.bar.fill")
//                    .font(.body)
//                    .foregroundStyle(.secondary)
//            }
//            .matchedTransitionSource(id: "dayOverviewButton", in: animation)
//
//        }
//        
//        ToolbarItem(placement: .bottomBar) {
//            
//            Button { navigation.isSearching = true } label: {
//                Image(systemName: "magnifyingglass")
//                    .font(.body)
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .matchedTransitionSource(id: "searchButton", in: animation)
//        
//        ToolbarItem(placement: .bottomBar) {
//            Button {
//                // Cache themes before showing sheet to avoid SwiftData faults
//                planningViewModel.cachedThemes = availableGoalThemes
//                navigation.showPlannerSheet = true
//            } label: {
//                if planningViewModel.isPlanning {
//                    ProgressView()
//                        .controlSize(.small)
//                } else {
//                    Label("Plan Day", systemImage: "sparkles")
//                }
//            }
//            .disabled(planningViewModel.isPlanning)
//            .matchedTransitionSource(id: "plannerButton", in: animation)
//        }
//        
//        
//        ToolbarItem(placement: .bottomBar) {
//            Spacer()
//        }
//        
//        if let timerManager,
//           let activeSession = timerManager.activeSession,
//           let session = sessions.first(where: { $0.id == activeSession.id }) {
//            
//            ToolbarItem(placement: .bottomBar) {
//                ActionView(session: session, details: activeSession) { event in
//                    handle(event: event)
//                }
//                .onTapGesture {
//                    navigation.showNowPlaying = true
//                }
//                .frame(minWidth: 140.0)
//            }
//        }
//        
//        ToolbarItem(placement: .bottomBar) {
//            Spacer()
//        }
//        
//        ToolbarItem(placement: .bottomBar) {
//            Button(action: { navigation.showingGoalEditor = true }) {
//                Label("Add Item", systemImage: "plus")
//            }
//            .overlay {
//                Color.clear
//            }
//            .matchedTransitionSource(id: "info", in: animation)
//        }
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
