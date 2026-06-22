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
    
    // MARK: - Session Selection
    var selectedSession: GoalSession?
    var sessionToLogManually: GoalSession?
    var sessionIDToOpen: String?
    
    // MARK: - Search
    var isSearching = false
    var searchText = ""
    
    // MARK: - UI State
    var navigationPath = NavigationPath()
    var visibleSectionType: ContextualSection.SectionType?
    var showExpandedCapsule = false
    
    // MARK: - Celebration
    var celebrationData: CelebrationData?
    
    // MARK: - Toast
    var toastConfig: ToastConfig?
    
    // MARK: - Helper Methods
    func dismissAllSheets() {
        showPlannerSheet = false
        showAllGoals = false
        showSettings = false
        showNowPlaying = false
        showDayOverview = false
        showExpandedCapsule = false
        celebrationData = nil
    }
    
    func openSession(_ session: GoalSession) {
        selectedSession = session
    }
    
    func openDeepLink(sessionID: String?) {
        sessionIDToOpen = sessionID
    }
}
