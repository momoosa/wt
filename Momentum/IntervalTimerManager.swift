//
//  IntervalTimerManager.swift
//  Momentum
//
//  Manages countdown timing through a sequence of intervals within a goal session.
//  Runs alongside SessionTimerManager — this handles the sub-structure (which interval,
//  how many seconds left) while SessionTimerManager tracks overall elapsed time.
//

import Foundation
import SwiftUI
import MomentumKit
import AVFoundation

@Observable
@MainActor
final class IntervalTimerManager {
    
    // MARK: - Public State
    
    enum Phase: Equatable {
        case idle
        case playing
        case paused
        case transition  // Brief rest between intervals
        case completed
    }
    
    /// Current phase of interval playback
    private(set) var phase: Phase = .idle
    
    /// Index of the current interval in the sorted sequence
    private(set) var currentIntervalIndex: Int = 0
    
    /// Seconds remaining in the current interval countdown
    private(set) var secondsRemaining: Int = 0
    
    /// The ordered list of interval sessions being played
    private(set) var intervalSessions: [IntervalSession] = []
    
    /// Transition countdown (seconds remaining in the rest between intervals)
    private(set) var transitionSecondsRemaining: Int = 0
    
    /// Duration of the transition period between intervals
    let transitionDuration: Int = 5
    
    // MARK: - Callbacks
    
    var onIntervalComplete: ((IntervalSession) -> Void)?
    var onAllIntervalsComplete: (() -> Void)?
    var onPhaseChange: ((Phase) -> Void)?
    
    // MARK: - Computed Properties
    
    var currentIntervalSession: IntervalSession? {
        guard currentIntervalIndex >= 0, currentIntervalIndex < intervalSessions.count else { return nil }
        return intervalSessions[currentIntervalIndex]
    }
    
    var currentInterval: Interval? {
        currentIntervalSession?.interval
    }
    
    var currentIntervalName: String? {
        currentInterval?.name
    }
    
    var currentIntervalKind: Interval.Kind? {
        currentInterval?.kind
    }
    
    var totalIntervals: Int {
        intervalSessions.count
    }
    
    var completedIntervals: Int {
        intervalSessions.filter(\.isCompleted).count
    }
    
    /// Progress through the current interval (0.0 to 1.0)
    var currentIntervalProgress: Double {
        guard let interval = currentInterval else { return 0 }
        let total = interval.durationSeconds
        guard total > 0 else { return 0 }
        let elapsed = total - secondsRemaining
        return Double(elapsed) / Double(total)
    }
    
    /// Overall progress through all intervals (0.0 to 1.0)
    var overallProgress: Double {
        guard !intervalSessions.isEmpty else { return 0 }
        
        let totalDuration = intervalSessions.reduce(0) { $0 + ($1.interval?.durationSeconds ?? 0) }
        guard totalDuration > 0 else { return 0 }
        
        var elapsedTotal = 0
        for (index, session) in intervalSessions.enumerated() {
            if session.isCompleted {
                elapsedTotal += session.interval?.durationSeconds ?? 0
            } else if index == currentIntervalIndex {
                let duration = session.interval?.durationSeconds ?? 0
                elapsedTotal += duration - secondsRemaining
                break
            }
        }
        
        return Double(elapsedTotal) / Double(totalDuration)
    }
    
    /// Total duration of all intervals in seconds
    var totalDurationSeconds: Int {
        intervalSessions.reduce(0) { $0 + ($1.interval?.durationSeconds ?? 0) }
    }
    
    /// Time remaining across all intervals
    var totalTimeRemaining: TimeInterval {
        var remaining = 0
        for (index, session) in intervalSessions.enumerated() {
            if session.isCompleted { continue }
            if index == currentIntervalIndex {
                remaining += secondsRemaining
            } else {
                remaining += session.interval?.durationSeconds ?? 0
            }
        }
        return TimeInterval(remaining)
    }
    
    var isActive: Bool {
        phase == .playing || phase == .paused || phase == .transition
    }
    
    // MARK: - Private
    
    @ObservationIgnored
    private nonisolated(unsafe) var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Lifecycle
    
    /// Load intervals from an IntervalListSession and prepare for playback
    func load(from listSession: IntervalListSession) {
        let sorted = (listSession.intervals ?? []).sorted { $0.interval?.orderIndex ?? 0 < $1.interval?.orderIndex ?? 0 }
        intervalSessions = sorted
        currentIntervalIndex = 0
        phase = .idle
        
        // Reset all completion states
        for session in sorted {
            session.isCompleted = false
            session.elapsedSeconds = 0
        }
    }
    
    /// Load intervals directly from an array (for previews/testing)
    func load(sessions: [IntervalSession]) {
        intervalSessions = sessions
        currentIntervalIndex = 0
        phase = .idle
    }
    
    // MARK: - Playback Control
    
    func start() {
        guard !intervalSessions.isEmpty else { return }
        
        // Find the first incomplete interval
        if let firstIncomplete = intervalSessions.firstIndex(where: { !$0.isCompleted }) {
            currentIntervalIndex = firstIncomplete
        } else {
            currentIntervalIndex = 0
            // Reset all
            for session in intervalSessions {
                session.isCompleted = false
                session.elapsedSeconds = 0
            }
        }
        
        secondsRemaining = currentIntervalSession?.interval?.durationSeconds ?? 0
        phase = .playing
        onPhaseChange?(.playing)
        startTimer()
        
        HapticFeedbackManager.trigger(.medium)
    }
    
    func pause() {
        guard phase == .playing || phase == .transition else { return }
        stopTimer()
        phase = .paused
        onPhaseChange?(.paused)
    }
    
    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        onPhaseChange?(.playing)
        startTimer()
    }
    
    func togglePause() {
        if phase == .paused {
            resume()
        } else if phase == .playing || phase == .transition {
            pause()
        }
    }
    
    func stop() {
        stopTimer()
        phase = .idle
        onPhaseChange?(.idle)
    }
    
    /// Skip to the next interval
    func skipToNext() {
        guard currentIntervalIndex < intervalSessions.count else { return }
        
        // Mark current as completed
        if let current = currentIntervalSession {
            current.isCompleted = true
            current.elapsedSeconds = current.interval?.durationSeconds ?? 0
            onIntervalComplete?(current)
        }
        
        advanceToNextInterval()
    }
    
    /// Skip to a specific interval by index
    func skipTo(index targetIndex: Int) {
        guard targetIndex >= 0, targetIndex < intervalSessions.count else { return }
        
        // Mark all intervals before target as completed
        for i in 0..<targetIndex {
            intervalSessions[i].isCompleted = true
            intervalSessions[i].elapsedSeconds = intervalSessions[i].interval?.durationSeconds ?? 0
        }
        
        // Reset target and all after it
        for i in targetIndex..<intervalSessions.count {
            intervalSessions[i].isCompleted = false
            intervalSessions[i].elapsedSeconds = 0
        }
        
        currentIntervalIndex = targetIndex
        secondsRemaining = intervalSessions[targetIndex].interval?.durationSeconds ?? 0
        
        if phase != .playing {
            phase = .playing
            onPhaseChange?(.playing)
            startTimer()
        }
        
        HapticFeedbackManager.trigger(.medium)
    }
    
    /// Skip back to the previous interval
    func skipToPrevious() {
        guard currentIntervalIndex > 0 else {
            // Restart current interval
            secondsRemaining = currentIntervalSession?.interval?.durationSeconds ?? 0
            return
        }
        
        // Un-complete previous interval
        let prevIndex = currentIntervalIndex - 1
        let prevSession = intervalSessions[prevIndex]
        prevSession.isCompleted = false
        prevSession.elapsedSeconds = 0
        
        currentIntervalIndex = prevIndex
        secondsRemaining = prevSession.interval?.durationSeconds ?? 0
        
        if phase != .playing {
            phase = .playing
            onPhaseChange?(.playing)
            startTimer()
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        switch phase {
        case .playing:
            tickPlaying()
        case .transition:
            tickTransition()
        default:
            break
        }
    }
    
    private func tickPlaying() {
        guard secondsRemaining > 0 else {
            completeCurrentInterval()
            return
        }
        
        secondsRemaining -= 1
        
        // Update elapsed seconds on the session model
        if let current = currentIntervalSession, let interval = current.interval {
            current.elapsedSeconds = interval.durationSeconds - secondsRemaining
        }
        
        // Haptic at 3, 2, 1
        if secondsRemaining <= 3 && secondsRemaining > 0 {
            HapticFeedbackManager.trigger(.light)
        }
        
        if secondsRemaining == 0 {
            completeCurrentInterval()
        }
    }
    
    private func tickTransition() {
        guard transitionSecondsRemaining > 0 else {
            finishTransition()
            return
        }
        
        transitionSecondsRemaining -= 1
        
        if transitionSecondsRemaining <= 3 && transitionSecondsRemaining > 0 {
            HapticFeedbackManager.trigger(.light)
        }
        
        if transitionSecondsRemaining == 0 {
            finishTransition()
        }
    }
    
    private func completeCurrentInterval() {
        guard let current = currentIntervalSession else { return }
        
        current.isCompleted = true
        current.elapsedSeconds = current.interval?.durationSeconds ?? 0
        onIntervalComplete?(current)
        
        HapticFeedbackManager.trigger(.success)
        
        advanceToNextInterval()
    }
    
    private func advanceToNextInterval() {
        let nextIndex = currentIntervalIndex + 1
        
        if nextIndex >= intervalSessions.count {
            // All intervals complete
            stopTimer()
            phase = .completed
            onPhaseChange?(.completed)
            onAllIntervalsComplete?()
            HapticFeedbackManager.trigger(.success)
            return
        }
        
        // Start transition period before next interval
        currentIntervalIndex = nextIndex
        transitionSecondsRemaining = transitionDuration
        phase = .transition
        onPhaseChange?(.transition)
        
        HapticFeedbackManager.trigger(.medium)
    }
    
    private func finishTransition() {
        secondsRemaining = currentIntervalSession?.interval?.durationSeconds ?? 0
        phase = .playing
        onPhaseChange?(.playing)
        
        HapticFeedbackManager.trigger(.rigid)
    }
}
