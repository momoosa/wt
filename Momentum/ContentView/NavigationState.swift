//
//  NavigationState.swift
//  Momentum
//
//  Consolidated navigation and UI state management for ContentView
//

import SwiftUI
import MomentumKit

enum BottomBarTab: String, CaseIterable {
    case nowPlaying = "Now Playing"
    case plan = "Today's Plan"
    case goals = "All Goals"
    case analytics = "Analytics"
    case search = "Search"
    
    static let minimizedCases: [BottomBarTab] = [.plan, .goals, .analytics, .search]
    var icon: String {
        switch self {
        case .nowPlaying: return "play.circle.fill"
        case .plan: return "calendar"
        case .goals: return "target"
        case .analytics: return "chart.bar.fill"
        case .search: return "magnifyingglass"
        }
    }
}

struct BottomBarDetent: CustomPresentationDetent {
    static let contentHeight: CGFloat = 105
    
    static func height(in context: Context) -> CGFloat? {
        return contentHeight
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
    
    // MARK: - Bottom Bar
    var selectedBottomTab: BottomBarTab = .plan
    var bottomSheetDetent: PresentationDetent = .custom(BottomBarDetent.self)
    
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
    
    // MARK: - Celebration
    var celebrationData: CelebrationData?
    
    // MARK: - Toast
    var toastConfig: ToastConfig?
    
    // MARK: - Helper Methods
    func dismissAllSheets() {
        showPlannerSheet = false
        showNowPlaying = false // TODO: Can't this be an enum?
        showAllGoals = false
        showSettings = false
        showNowPlaying = false
        showDayOverview = false
        bottomSheetDetent = .custom(BottomBarDetent.self)
        celebrationData = nil
    }
    
    func openSession(_ session: GoalSession) {
        selectedSession = session
    }
    
    func openDeepLink(sessionID: String?) {
        sessionIDToOpen = sessionID
    }
}
