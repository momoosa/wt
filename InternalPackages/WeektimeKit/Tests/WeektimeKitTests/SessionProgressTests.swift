//
//  SessionProgressTests.swift
//  WeektimeKit Tests
//
//  Created by Assistant on 07/03/2026.
//

import Testing
import Foundation
@testable import MomentumKit

// Test helper struct conforming to SessionProgressProvider
struct SessionProgress: SessionProgressProvider {
    let elapsedTime: TimeInterval
    let dailyTarget: TimeInterval
}

@Suite("Session Progress Calculations")
struct SessionProgressTests {
    
    // MARK: - Progress Ratio Tests
    
    @Test("Progress returns correct ratio for partial completion")
    func progressReturnsCorrectRatio() {
        let progress = SessionProgress(elapsedTime: 1800, dailyTarget: 3600)
        
        #expect(progress.progress == 0.5) // 50%
    }
    
    @Test("Progress caps at 1.0 when exceeded")
    func progressCapsAtOne() {
        let progress = SessionProgress(elapsedTime: 5400, dailyTarget: 3600)
        
        #expect(progress.progress == 1.0) // Capped at 100%
    }
    
    @Test("Progress returns 0 for zero daily target")
    func progressReturnsZeroForZeroTarget() {
        let progress = SessionProgress(elapsedTime: 1800, dailyTarget: 0)
        
        #expect(progress.progress == 0.0)
    }
    
    @Test("Progress returns 0 for zero elapsed time")
    func progressReturnsZeroForZeroElapsed() {
        let progress = SessionProgress(elapsedTime: 0, dailyTarget: 3600)
        
        #expect(progress.progress == 0.0)
    }
    
    @Test("Progress handles exact target completion")
    func progressHandlesExactCompletion() {
        let progress = SessionProgress(elapsedTime: 3600, dailyTarget: 3600)
        
        #expect(progress.progress == 1.0)
    }
    
    // MARK: - Remaining Time Tests
    
    @Test("Remaining time calculates correctly")
    func remainingTimeCalculatesCorrectly() {
        let progress = SessionProgress(elapsedTime: 1800, dailyTarget: 3600)
        
        #expect(progress.remainingTime == 1800) // 30 minutes left
    }
    
    @Test("Remaining time returns 0 when target exceeded")
    func remainingTimeReturnsZeroWhenExceeded() {
        let progress = SessionProgress(elapsedTime: 5400, dailyTarget: 3600)
        
        #expect(progress.remainingTime == 0)
    }
    
    @Test("Remaining time handles exact completion")
    func remainingTimeHandlesExactCompletion() {
        let progress = SessionProgress(elapsedTime: 3600, dailyTarget: 3600)
        
        #expect(progress.remainingTime == 0)
    }
    
    // MARK: - Progress Percentage Tests
    
    @Test("Progress percentage formats correctly")
    func progressPercentageFormatsCorrectly() {
        let progress = SessionProgress(elapsedTime: 2700, dailyTarget: 3600)
        
        // 75% completion
        #expect(progress.progressPercentage == "75%")
    }
    
    @Test("Progress percentage handles zero")
    func progressPercentageHandlesZero() {
        let progress = SessionProgress(elapsedTime: 0, dailyTarget: 3600)
        
        #expect(progress.progressPercentage == "0%")
    }
    
    @Test("Progress percentage handles 100%")
    func progressPercentageHandlesComplete() {
        let progress = SessionProgress(elapsedTime: 3600, dailyTarget: 3600)
        
        #expect(progress.progressPercentage == "100%")
    }
    
    @Test("Progress percentage truncates decimals")
    func progressPercentageTruncatesDecimals() {
        let progress = SessionProgress(elapsedTime: 1850, dailyTarget: 3600)
        
        // 51.388...% should truncate to 51%
        #expect(progress.progressPercentage == "51%")
    }
    
    // MARK: - Progress Percentage Int Tests
    
    @Test("Progress percentage int returns correct value")
    func progressPercentageIntReturnsCorrectValue() {
        let progress = SessionProgress(elapsedTime: 2700, dailyTarget: 3600)
        
        #expect(progress.progressPercentageInt == 75)
    }
    
    @Test("Progress percentage int truncates correctly")
    func progressPercentageIntTruncatesCorrectly() {
        let progress = SessionProgress(elapsedTime: 1999, dailyTarget: 3600)
        
        // 55.527...% should truncate to 55
        #expect(progress.progressPercentageInt == 55)
    }
}
