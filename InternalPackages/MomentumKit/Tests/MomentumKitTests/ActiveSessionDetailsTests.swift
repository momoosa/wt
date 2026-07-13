//
//  ActiveSessionDetailsTests.swift
//  MomentumKitTests
//
//  Tests for ActiveSessionDetails pause behavior, elapsed time accumulation,
//  and progress calculations.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("ActiveSessionDetails Tests")
struct ActiveSessionDetailsTests {
    
    // MARK: - Initialization
    
    @Test("Initializes with correct values")
    func initializesCorrectly() {
        let startDate = Date()
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: startDate,
            elapsedTime: 100,
            dailyTarget: 3600
        )
        
        #expect(details.elapsedTime == 100)
        #expect(details.dailyTarget == 3600)
        #expect(details.isPaused == false)
        #expect(details.startDate == startDate)
    }
    
    @Test("Initializes with isPaused as false by default")
    func initializesNotPaused() {
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: Date(),
            elapsedTime: 0,
            dailyTarget: 600
        )
        
        #expect(details.isPaused == false)
    }
    
    // MARK: - accumulateElapsedTime
    
    @Test("accumulateElapsedTime adds time since startDate to elapsedTime")
    func accumulateElapsedTimeAddsTime() {
        let twoSecondsAgo = Date().addingTimeInterval(-2)
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: twoSecondsAgo,
            elapsedTime: 100
        )
        
        details.accumulateElapsedTime()
        
        // Should be approximately 102 seconds (100 + ~2)
        #expect(details.elapsedTime >= 101.5)
        #expect(details.elapsedTime <= 103.0)
    }
    
    @Test("accumulateElapsedTime resets startDate to now")
    func accumulateElapsedTimeResetsStartDate() {
        let tenSecondsAgo = Date().addingTimeInterval(-10)
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: tenSecondsAgo,
            elapsedTime: 0
        )
        
        let beforeAccumulate = Date()
        details.accumulateElapsedTime()
        let afterAccumulate = Date()
        
        // startDate should be reset to approximately now
        #expect(details.startDate >= beforeAccumulate)
        #expect(details.startDate <= afterAccumulate)
    }
    
    @Test("accumulateElapsedTime called twice accumulates correctly")
    func accumulateElapsedTimeCalledTwice() {
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: fiveSecondsAgo,
            elapsedTime: 0
        )
        
        details.accumulateElapsedTime()
        let afterFirst = details.elapsedTime
        
        // Very small gap between calls
        details.accumulateElapsedTime()
        let afterSecond = details.elapsedTime
        
        // First accumulation should have added ~5 seconds
        #expect(afterFirst >= 4.5)
        #expect(afterFirst <= 6.0)
        
        // Second accumulation should add nearly 0 (just the tiny gap)
        #expect(afterSecond >= afterFirst)
        #expect(afterSecond - afterFirst < 1.0)
    }
    
    // MARK: - Pause Behavior
    
    @Test("isPaused can be toggled")
    func isPausedCanBeToggled() {
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: Date(),
            elapsedTime: 0
        )
        
        #expect(details.isPaused == false)
        
        details.isPaused = true
        #expect(details.isPaused == true)
        
        details.isPaused = false
        #expect(details.isPaused == false)
    }
    
    @Test("Paused session elapsedTime stops growing")
    func pausedSessionElapsedTimeStopsGrowing() {
        let tenSecondsAgo = Date().addingTimeInterval(-10)
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: tenSecondsAgo,
            elapsedTime: 0,
            dailyTarget: 3600
        )
        details.targetUnit = .seconds
        
        // Simulate pause: accumulate then mark paused
        details.accumulateElapsedTime()
        details.isPaused = true
        
        // After accumulation, startDate is ~now, elapsedTime is ~10
        let frozenValue = details.elapsedTime
        
        // Wait a moment
        Thread.sleep(forTimeInterval: 0.1)
        
        // elapsedTime should not have changed (it's a stored property)
        #expect(details.elapsedTime == frozenValue)
    }
    
    // MARK: - Progress Calculations
    
    @Test("Progress is 0 when no time elapsed and no target")
    func progressIsZeroWithNoTarget() {
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: Date(),
            elapsedTime: 0,
            dailyTarget: 0
        )
        
        #expect(details.progress == 0.0)
    }
    
    @Test("Progress is 0.5 at half target")
    func progressIsHalfAtHalfTarget() {
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: Date(),
            elapsedTime: 1800,
            dailyTarget: 3600
        )
        details.unifiedTargetValue = 3600
        
        // elapsedTime is 1800, plus small live component from Date()-startDate
        // startDate is ~now so live component is ~0
        let progress = details.progress
        #expect(progress >= 0.49)
        #expect(progress <= 0.51)
    }
    
    @Test("hasMetDailyTarget is false when under target")
    func hasNotMetTarget() {
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: Date(),
            elapsedTime: 100,
            dailyTarget: 3600
        )
        details.unifiedTargetValue = 3600
        
        #expect(details.hasMetDailyTarget == false)
    }
    
    @Test("hasMetDailyTarget is true when at or over target")
    func hasMetTarget() {
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: Date(),
            elapsedTime: 3600,
            dailyTarget: 3600
        )
        details.unifiedTargetValue = 3600
        
        #expect(details.hasMetDailyTarget == true)
    }
    
    // MARK: - Start Time Adjustment
    
    @Test("adjustStartTime shifts startDate by offset")
    func adjustStartTimeShiftsDate() {
        let now = Date()
        let details = ActiveSessionDetails(
            id: UUID(),
            startDate: now,
            elapsedTime: 0
        )
        
        // Shift back 60 seconds (earlier start = more elapsed time)
        details.adjustStartTime(by: -60)
        
        let expected = now.addingTimeInterval(-60)
        #expect(abs(details.startDate.timeIntervalSince(expected)) < 0.01)
    }
    
    // MARK: - Equatable
    
    @Test("Equality is based on id and isPaused")
    func equalityBasedOnIdAndPaused() {
        let id = UUID()
        let a = ActiveSessionDetails(id: id, startDate: Date(), elapsedTime: 0)
        let b = ActiveSessionDetails(id: id, startDate: Date().addingTimeInterval(-100), elapsedTime: 500)
        
        // Same id, same isPaused → equal
        #expect(a == b)
        
        // Different isPaused → not equal
        b.isPaused = true
        #expect(a != b)
    }
    
    @Test("Different ids are not equal")
    func differentIdsNotEqual() {
        let a = ActiveSessionDetails(id: UUID(), startDate: Date(), elapsedTime: 0)
        let b = ActiveSessionDetails(id: UUID(), startDate: Date(), elapsedTime: 0)
        
        #expect(a != b)
    }
}
