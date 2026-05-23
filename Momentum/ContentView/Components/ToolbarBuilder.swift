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
        
    
  
        
        // Bottom bar items removed — replaced by BottomCapsuleBar
    }
}
