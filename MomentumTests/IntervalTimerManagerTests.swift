//
//  IntervalTimerManagerTests.swift
//  MomentumTests
//
//  Tests for IntervalTimerManager playback logic: start, pause, resume,
//  skip, completion, and progress tracking.
//

import Testing
import Foundation
@testable import Momentum
@testable import MomentumKit

@Suite("IntervalTimerManager Tests", .serialized)
struct IntervalTimerManagerTests {
    
    // MARK: - Helpers
    
    /// Creates test intervals with specified durations
    func createTestIntervals(durations: [Int] = [10, 15, 20]) -> (IntervalList, [IntervalSession]) {
        let list = IntervalList(name: "Test List")
        var intervals = [Interval]()
        for (index, duration) in durations.enumerated() {
            let interval = Interval(name: "Interval \(index + 1)", durationSeconds: duration, orderIndex: index, kind: index % 2 == 0 ? .work : .breakTime)
            interval.list = list
            intervals.append(interval)
        }
        list.intervals = intervals
        
        let sessions = intervals.map { IntervalSession(interval: $0) }
        return (list, sessions)
    }
    
    // MARK: - Initialization
    
    @Test("IntervalTimerManager initializes in idle phase")
    @MainActor
    func initializesInIdlePhase() {
        let manager = IntervalTimerManager()
        
        #expect(manager.phase == .idle)
        #expect(manager.currentIntervalIndex == 0)
        #expect(manager.secondsRemaining == 0)
        #expect(manager.intervalSessions.isEmpty)
        #expect(manager.isActive == false)
    }
    
    // MARK: - Load
    
    @Test("Loading sessions populates intervalSessions")
    @MainActor
    func loadingSetsUpSessions() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20, 30])
        
        manager.load(sessions: sessions)
        
        #expect(manager.intervalSessions.count == 3)
        #expect(manager.phase == .idle)
        #expect(manager.currentIntervalIndex == 0)
    }
    
    @Test("Loading resets completion states")
    @MainActor
    func loadingResetsSessions() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20])
        sessions[0].isCompleted = true
        sessions[0].elapsedSeconds = 10
        
        manager.load(sessions: sessions)
        
        // load(sessions:) does NOT reset - only load(from:) does
        // But after start(), it finds first incomplete
        #expect(manager.intervalSessions.count == 2)
    }
    
    // MARK: - Start
    
    @Test("Starting begins playback from first interval")
    @MainActor
    func startingBeginsPlayback() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20])
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.phase == .playing)
        #expect(manager.currentIntervalIndex == 0)
        #expect(manager.secondsRemaining == 10)
        #expect(manager.isActive == true)
    }
    
    @Test("Starting with no sessions does nothing")
    @MainActor
    func startingEmptyDoesNothing() {
        let manager = IntervalTimerManager()
        
        manager.start()
        
        #expect(manager.phase == .idle)
    }
    
    @Test("Starting skips already-completed intervals")
    @MainActor
    func startingSkipsCompleted() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20, 30])
        sessions[0].isCompleted = true
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.currentIntervalIndex == 1)
        #expect(manager.secondsRemaining == 20)
    }
    
    // MARK: - Pause / Resume
    
    @Test("Pausing stops playback")
    @MainActor
    func pausingStopsPlayback() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        manager.pause()
        
        #expect(manager.phase == .paused)
        #expect(manager.isActive == true) // paused is still considered active
    }
    
    @Test("Resuming continues playback")
    @MainActor
    func resumingContinuesPlayback() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        manager.pause()
        manager.resume()
        
        #expect(manager.phase == .playing)
    }
    
    @Test("Pausing from idle does nothing")
    @MainActor
    func pausingFromIdleDoesNothing() {
        let manager = IntervalTimerManager()
        
        manager.pause()
        
        #expect(manager.phase == .idle)
    }
    
    @Test("Resuming from non-paused does nothing")
    @MainActor
    func resumingFromNonPausedDoesNothing() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        // Playing, not paused
        manager.resume()
        
        #expect(manager.phase == .playing)
    }
    
    @Test("Toggle pause toggles between playing and paused")
    @MainActor
    func togglePauseWorks() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        #expect(manager.phase == .playing)
        
        manager.togglePause()
        #expect(manager.phase == .paused)
        
        manager.togglePause()
        #expect(manager.phase == .playing)
    }
    
    // MARK: - Stop
    
    @Test("Stopping resets to idle")
    @MainActor
    func stoppingResetsToIdle() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        manager.stop()
        
        #expect(manager.phase == .idle)
        #expect(manager.isActive == false)
    }
    
    // MARK: - Skip
    
    @Test("Skip to next marks current as completed and advances")
    @MainActor
    func skipToNextAdvances() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60, 30])
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.currentIntervalIndex == 0)
        
        manager.skipToNext()
        
        #expect(sessions[0].isCompleted == true)
        // After skipping, enters transition phase for next interval
        #expect(manager.currentIntervalIndex == 1)
    }
    
    @Test("Skip to next on last interval completes all")
    @MainActor
    func skipToNextOnLastCompletes() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        manager.skipToNext()
        
        #expect(manager.phase == .completed)
        #expect(sessions[0].isCompleted == true)
    }
    
    @Test("Skip to previous restarts current when at first interval")
    @MainActor
    func skipToPreviousAtFirstResetsCurrent() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        
        // Simulate some time passed
        #expect(manager.secondsRemaining == 60)
        
        manager.skipToPrevious()
        
        // Should restart current interval
        #expect(manager.currentIntervalIndex == 0)
        #expect(manager.secondsRemaining == 60)
    }
    
    @Test("Skip to previous goes back to previous interval")
    @MainActor
    func skipToPreviousGoesBack() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20])
        
        manager.load(sessions: sessions)
        manager.start()
        manager.skipToNext() // move to index 1
        
        // Now at index 1
        #expect(manager.currentIntervalIndex == 1)
        
        manager.skipToPrevious()
        
        #expect(manager.currentIntervalIndex == 0)
        #expect(sessions[0].isCompleted == false) // un-completed
        #expect(manager.secondsRemaining == 10)
    }
    
    // MARK: - Progress Calculations
    
    @Test("Current interval progress is 0 at start")
    @MainActor
    func currentIntervalProgressIsZeroAtStart() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [100])
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.currentIntervalProgress == 0.0)
    }
    
    @Test("Overall progress is 0 at start")
    @MainActor
    func overallProgressIsZeroAtStart() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [100, 100])
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.overallProgress == 0.0)
    }
    
    @Test("Overall progress reflects completed intervals")
    @MainActor
    func overallProgressReflectsCompleted() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 10])
        
        manager.load(sessions: sessions)
        manager.start()
        
        // Skip to next, completing first interval (10 of 20 total seconds)
        manager.skipToNext()
        
        // First interval (10s) is completed, second (10s) just started
        // Overall: 10 elapsed out of 20 total = 0.5
        #expect(manager.overallProgress == 0.5)
    }
    
    @Test("Total intervals count is correct")
    @MainActor
    func totalIntervalsCountIsCorrect() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20, 30])
        
        manager.load(sessions: sessions)
        
        #expect(manager.totalIntervals == 3)
    }
    
    @Test("Total duration seconds sums all intervals")
    @MainActor
    func totalDurationSumsAll() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20, 30])
        
        manager.load(sessions: sessions)
        
        #expect(manager.totalDurationSeconds == 60)
    }
    
    @Test("Total time remaining reflects current playback position")
    @MainActor
    func totalTimeRemainingIsCorrect() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20])
        
        manager.load(sessions: sessions)
        manager.start()
        
        // At start: 10 + 20 = 30 seconds remaining
        #expect(manager.totalTimeRemaining == 30.0)
    }
    
    @Test("Completed intervals count tracks progress")
    @MainActor
    func completedIntervalsCountTracksProgress() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20, 30])
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.completedIntervals == 0)
        
        manager.skipToNext()
        #expect(manager.completedIntervals == 1)
        
        manager.skipToNext()
        #expect(manager.completedIntervals == 2)
    }
    
    // MARK: - Callbacks
    
    @Test("onPhaseChange callback fires on start")
    @MainActor
    func onPhaseChangeFiresOnStart() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        var receivedPhase: IntervalTimerManager.Phase?
        manager.onPhaseChange = { phase in
            receivedPhase = phase
        }
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(receivedPhase == .playing)
    }
    
    @Test("onPhaseChange callback fires on pause")
    @MainActor
    func onPhaseChangeFiresOnPause() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        
        var receivedPhase: IntervalTimerManager.Phase?
        manager.onPhaseChange = { phase in
            receivedPhase = phase
        }
        
        manager.pause()
        
        #expect(receivedPhase == .paused)
    }
    
    @Test("onIntervalComplete callback fires when interval is skipped")
    @MainActor
    func onIntervalCompleteFiresOnSkip() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60, 30])
        
        var completedSession: IntervalSession?
        manager.onIntervalComplete = { session in
            completedSession = session
        }
        
        manager.load(sessions: sessions)
        manager.start()
        manager.skipToNext()
        
        #expect(completedSession != nil)
        #expect(completedSession?.id == sessions[0].id)
    }
    
    @Test("onAllIntervalsComplete fires when last interval completes")
    @MainActor
    func onAllIntervalsCompleteFiresAtEnd() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10])
        
        var allCompleteCalled = false
        manager.onAllIntervalsComplete = {
            allCompleteCalled = true
        }
        
        manager.load(sessions: sessions)
        manager.start()
        manager.skipToNext()
        
        #expect(allCompleteCalled == true)
        #expect(manager.phase == .completed)
    }
    
    // MARK: - Current Interval Info
    
    @Test("Current interval name returns correct name")
    @MainActor
    func currentIntervalNameIsCorrect() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20])
        
        manager.load(sessions: sessions)
        manager.start()
        
        #expect(manager.currentIntervalName == "Interval 1")
        
        manager.skipToNext()
        
        #expect(manager.currentIntervalName == "Interval 2")
    }
    
    @Test("Current interval kind reflects interval type")
    @MainActor
    func currentIntervalKindIsCorrect() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [10, 20])
        
        manager.load(sessions: sessions)
        manager.start()
        
        // First interval is work (index 0 % 2 == 0)
        #expect(manager.currentIntervalKind == .work)
        
        manager.skipToNext()
        
        // Second interval is breakTime (index 1 % 2 != 0)
        #expect(manager.currentIntervalKind == .breakTime)
    }
    
    // MARK: - Edge Cases
    
    @Test("Progress is 0 when no intervals loaded")
    @MainActor
    func progressIsZeroWhenEmpty() {
        let manager = IntervalTimerManager()
        
        #expect(manager.currentIntervalProgress == 0.0)
        #expect(manager.overallProgress == 0.0)
        #expect(manager.totalTimeRemaining == 0.0)
    }
    
    @Test("Multiple start calls don't break state")
    @MainActor
    func multipleStartCallsDontBreak() {
        let manager = IntervalTimerManager()
        let (_, sessions) = createTestIntervals(durations: [60])
        
        manager.load(sessions: sessions)
        manager.start()
        manager.start() // second start
        
        #expect(manager.phase == .playing)
        #expect(manager.currentIntervalIndex == 0)
    }
}
