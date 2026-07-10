//
//  NavigationState.swift
//  Momentum
//
//  Consolidated navigation and UI state management for ContentView
//

import SwiftUI
import MomentumKit

enum AppTab: String, CaseIterable {
    case home = "Home"
    case plan = "Plan"
    case analytics = "Analytics"
    case search = "Search"
    
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .plan: "calendar"
        case .analytics: "chart.bar.fill"
        case .search: "magnifyingglass"
        }
    }
}

@Observable
class NavigationState {
    // MARK: - Sheet Presentation
    var showPlannerSheet = false
    var showNowPlaying = false
    var showAllGoals = false
    var showSettings = false
    var showDayOverview = false
    
    // MARK: - Tab Bar
    var selectedTab: AppTab = .home
    
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
    
    // MARK: - Interval Flow
    var intervalFlowSession: GoalSession?
    var intervalFlowListSession: IntervalListSession?
    var showIntervalFlow = false
    
    // MARK: - Goal Editor (lifted to root so it can present from any context)
    var goalEditorViewModel: GoalEditorViewModel?
    
    // MARK: - Celebration
    var celebrationData: CelebrationData?
    
    // MARK: - Toast
    var toastConfig: ToastConfig?
    
    // MARK: - Helper Methods
    func dismissAllSheets() {
        showPlannerSheet = false
        showNowPlaying = false
        showAllGoals = false
        showSettings = false
        showDayOverview = false
        celebrationData = nil
    }
    
    func openSession(_ session: GoalSession) {
        selectedSession = session
    }
    
    func openDeepLink(sessionID: String?) {
        sessionIDToOpen = sessionID
    }
}
