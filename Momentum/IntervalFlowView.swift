//
//  IntervalFlowView.swift
//  Momentum
//
//  Container view that manages the full interval session flow:
//  Overview (Screen A) → Playback (Screens B+C) → Completion (Screen D).
//

import SwiftUI
import MomentumKit

struct IntervalFlowView: View {
    let session: GoalSession
    let listSession: IntervalListSession
    let timerManager: SessionTimerManager
    let day: Day
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var flowPhase: FlowPhase = .overview
    @State private var intervalTimer = IntervalTimerManager()
    
    enum FlowPhase {
        case overview
        case playback
        case completed
    }
    
    var body: some View {
        ZStack {
            switch flowPhase {
            case .overview:
                IntervalSessionOverview(
                    session: session,
                    listSession: listSession,
                    onStart: startSession,
                    onDismiss: onDismiss
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
                
            case .playback:
                IntervalPlaybackView(
                    session: session,
                    intervalTimer: intervalTimer,
                    onStop: stopSession,
                    onComplete: {
                        withAnimation(AnimationPresets.smoothSpring) {
                            flowPhase = .completed
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                
            case .completed:
                IntervalCompletionView(
                    session: session,
                    intervalTimer: intervalTimer,
                    onDone: {
                        stopSession()
                    },
                    onRepeat: {
                        repeatSession()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            }
        }
        .animation(AnimationPresets.smoothSpring, value: flowPhase)
        .onAppear {
            intervalTimer.load(from: listSession)
            
            // Wire interval state to SessionTimerManager
            intervalTimer.onPhaseChange = { phase in
                updateSessionTimerManager()
            }
        }
    }
    
    // MARK: - Flow Actions
    
    private func startSession() {
        // Start the overall session timer if not already running
        if !timerManager.isActive(session) {
            timerManager.startTimer(for: session)
        }
        
        // Start interval playback
        intervalTimer.start()
        
        withAnimation(AnimationPresets.smoothSpring) {
            flowPhase = .playback
        }
        
        updateSessionTimerManager()
    }
    
    private func stopSession() {
        intervalTimer.stop()
        
        // Stop the overall session timer
        if timerManager.isActive(session) {
            timerManager.toggleTimer(for: session, in: day)
        }
        
        clearSessionTimerManagerIntervals()
        onDismiss()
    }
    
    private func repeatSession() {
        // Reset all intervals and restart
        intervalTimer.load(from: listSession)
        intervalTimer.start()
        
        withAnimation(AnimationPresets.smoothSpring) {
            flowPhase = .playback
        }
        
        updateSessionTimerManager()
    }
    
    // MARK: - SessionTimerManager Sync
    
    private func updateSessionTimerManager() {
        timerManager.currentIntervalName = intervalTimer.currentIntervalName
        timerManager.intervalProgress = intervalTimer.currentIntervalProgress
        timerManager.intervalTimeRemaining = TimeInterval(intervalTimer.secondsRemaining)
    }
    
    private func clearSessionTimerManagerIntervals() {
        timerManager.currentIntervalName = nil
        timerManager.intervalProgress = nil
        timerManager.intervalTimeRemaining = nil
    }
}

extension IntervalFlowView.FlowPhase: Equatable {}
