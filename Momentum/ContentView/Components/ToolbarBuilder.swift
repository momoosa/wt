//
//  ToolbarBuilder.swift
//  Momentum
//
//  Extracted from ContentView.swift — Toolbar content
//

import SwiftUI
import SwiftData
import MomentumKit

// MARK: - Toolbar

extension ContentView {
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
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
        
    
  
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                navigation.isSearching = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .matchedTransitionSource(id: "searchButton", in: animation)
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                navigation.showDayOverview = true
            } label: {
                Label("Day Overview", systemImage: "calendar.badge.checkmark")
            }
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                // Cache themes before showing sheet to avoid SwiftData faults
                planningViewModel.cachedThemes = availableGoalThemes
                navigation.showPlannerSheet = true
            } label: {
                if planningViewModel.isPlanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Plan Day", systemImage: "sparkles")
                }
            }
            .disabled(planningViewModel.isPlanning)
            .matchedTransitionSource(id: "plannerButton", in: animation)
        }
        
        
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }
        
        if let timerManager,
           let activeSession = timerManager.activeSession,
           let session = sessions.first(where: { $0.id == activeSession.id }) {
            
            ToolbarItem(placement: .bottomBar) {
                ActionView(session: session, details: activeSession) { event in
                    handle(event: event)
                }
                .onTapGesture {
                    navigation.showNowPlaying = true
                }
                .frame(minWidth: 140.0)
            }
        }
        
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button(action: { navigation.showingGoalEditor = true }) {
                Label("Add Item", systemImage: "plus")
            }
            .overlay {
                Color.clear
            }
            .matchedTransitionSource(id: "info", in: animation)
        }
    }
}
