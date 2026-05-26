//
//  NavigationState.swift
//  Momentum
//
//  Consolidated navigation and UI state management for ContentView
//

import SwiftUI
import MomentumKit

@Observable
class NavigationState {
    // MARK: - Sheet Presentation
    var showPlannerSheet = false
    var showAllGoals = false
    var showSettings = false
    var showNowPlaying = false
    var showDayOverview = false
    var showingGoalEditor = false
    
    // MARK: - Session Selection
    var selectedSession: GoalSession?
    var sessionToLogManually: GoalSession?
    var sessionIDToOpen: String?
    
    // MARK: - Search
    var isSearching = false
    var searchText = ""
    
    // MARK: - UI State
    var navigationPath = NavigationPath()
    var scrollProxy: ScrollViewProxy?
    var expandedSections: Set<ContextualSection.SectionType> = [.recommendedNow, .later]
    var showExpandedCapsule = false
    
    // MARK: - Toast
    var toastConfig: ToastConfig?
    
    // MARK: - Helper Methods
    func dismissAllSheets() {
        showPlannerSheet = false
        showAllGoals = false
        showSettings = false
        showNowPlaying = false
        showDayOverview = false
        showingGoalEditor = false
        showExpandedCapsule = false
    }
    
    func openSession(_ session: GoalSession) {
        selectedSession = session
    }
    
    func openDeepLink(sessionID: String?) {
        sessionIDToOpen = sessionID
    }
}
