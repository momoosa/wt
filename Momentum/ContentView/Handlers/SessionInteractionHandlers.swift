//
//  SessionInteractionHandlers.swift
//  Momentum
//
//  Extracted from ContentView.swift — Timer, start time, and daily goal adjustment handlers
//

import SwiftUI
import MomentumKit
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Session Interaction Handlers

extension ContentView {
    
    func handleTimerToggle(for session: GoalSession) {
        guard let timerManager else { return }
        
        // Check if session is currently completed
        let wasCompleted = session.hasMetDailyTarget
        
        // Toggle the timer
        timerManager.toggleTimer(for: session, in: day)
        
        // If it was completed and we just started it, switch to Today filter and show toast
        if wasCompleted && timerManager.activeSession?.id == session.id {
            withAnimation {
                navigation.activeFilter = .activeToday
            }
            
            navigation.toastConfig = ToastConfig(
                message: "Session resumed - moved to Today",
                showUndo: false
            )
        }
    }
    
    func handleStartTimeAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        guard let timerManager,
              let activeSession = timerManager.activeSession,
              activeSession.id == session.id else { return }
        
        // Adjust start time using the ActiveSessionDetails method
        activeSession.adjustStartTime(by: adjustment)
        
        // Save to UserDefaults
        if let defaults = UserDefaults(suiteName: "group.com.moosa.momentum.ios") {
            defaults.set(activeSession.startDate.timeIntervalSince1970, forKey: "ActiveSessionStartDateV1")
            defaults.synchronize()
        }
        
        let minutes = Int(abs(adjustment) / 60)
        let direction = adjustment > 0 ? "earlier" : "later"
        navigation.toastConfig = ToastConfig(
            message: "Adjusted start time: \(minutes)m \(direction)",
            showUndo: false
        )
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handleDailyGoalAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        // Delegate to ViewModel
        viewModel.adjustDailyTarget(for: session, by: adjustment)
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handle(event: ActionView.Event) {
        guard let timerManager else { return }
        switch event {
        case .stopTapped:
            if let session = sessions.first(where: { $0.id == timerManager.activeSession?.id }) {
                handleTimerToggle(for: session)
            }
        }
    }
    
    func timerText(for session: GoalSession) -> String {
        return timerManager?.timerText(for: session) ?? "00:00"
    }
}
