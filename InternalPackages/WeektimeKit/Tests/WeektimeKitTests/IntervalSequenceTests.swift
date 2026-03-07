//
//  IntervalSequenceTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

@Suite("Interval Sequence Building")
struct IntervalSequenceTests {
    
    // MARK: - buildAlternatingSequence Tests
    
    @Test("buildAlternatingSequence returns empty for zero repeat count")
    func buildAlternatingSequenceReturnsEmptyForZero() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 0
        )
        
        #expect(intervals.isEmpty)
    }
    
    @Test("buildAlternatingSequence creates correct count for single repeat")
    func buildAlternatingSequenceCreatesSingleRepeat() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 1
        )
        
        #expect(intervals.count == 2) // 1 break + 1 work
    }
    
    @Test("buildAlternatingSequence alternates break and work correctly")
    func buildAlternatingSequenceAlternatesCorrectly() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 2
        )
        
        #expect(intervals.count == 4) // 2 breaks + 2 works
        #expect(intervals[0].kind == .breakTime)
        #expect(intervals[1].kind == .work)
        #expect(intervals[2].kind == .breakTime)
        #expect(intervals[3].kind == .work)
    }
    
    @Test("buildAlternatingSequence sets correct durations")
    func buildAlternatingSequenceSetsCorrectDurations() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 1
        )
        
        #expect(intervals[0].durationSeconds == 300) // Break
        #expect(intervals[1].durationSeconds == 1500) // Work
    }
    
    @Test("buildAlternatingSequence sets correct order indices")
    func buildAlternatingSequenceSetsCorrectOrderIndices() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 3
        )
        
        for (index, interval) in intervals.enumerated() {
            #expect(interval.orderIndex == index)
        }
    }
    
    @Test("buildAlternatingSequence names intervals correctly")
    func buildAlternatingSequenceNamesIntervalsCorrectly() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 2
        )
        
        #expect(intervals[0].name == "Break 1")
        #expect(intervals[1].name == "Work 1")
        #expect(intervals[2].name == "Break 2")
        #expect(intervals[3].name == "Work 2")
    }
    
    @Test("buildAlternatingSequence respects custom names")
    func buildAlternatingSequenceRespectsCustomNames() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 1,
            breakName: "Rest",
            workName: "Focus"
        )
        
        #expect(intervals[0].name == "Rest 1")
        #expect(intervals[1].name == "Focus 1")
    }
    
    @Test("buildAlternatingSequence handles large repeat counts")
    func buildAlternatingSequenceHandlesLargeRepeatCounts() {
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 10
        )
        
        #expect(intervals.count == 20) // 10 breaks + 10 works
        #expect(intervals.last?.orderIndex == 19)
    }
    
    @Test("buildAlternatingSequence preserves list association")
    func buildAlternatingSequencePreservesListAssociation() {
        let list = IntervalList(name: "Pomodoro")
        let intervals = Interval.buildAlternatingSequence(
            breakDurationSeconds: 300,
            workDurationSeconds: 1500,
            repeatCount: 1,
            list: list
        )
        
        for interval in intervals {
            #expect(interval.list === list)
        }
    }
}
