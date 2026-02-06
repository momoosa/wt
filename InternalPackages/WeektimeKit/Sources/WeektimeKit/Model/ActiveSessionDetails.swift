//
//  ActiveSessionDetails.swift
//  MomentumKit
//
//  Created by Mo Moosa on 20/08/2025.
//


import SwiftUI
import SwiftData

@Observable
public final class ActiveSessionDetails: SessionProgressProvider {
    public private(set) var id: UUID
    public private(set) var startDate: Date
    public private(set) var elapsedTime: TimeInterval = 0
    public var currentTime: Date?
    public private(set) var timeText: String?
    public var dailyTarget: TimeInterval = 0 // Changed from optional to required for protocol
    public var onTargetReached: (() -> Void)? // Callback when target is reached
    public var onTick: (() -> Void)? // Callback on every timer tick
    public private(set) var tickCount: Int = 0 // Increments every second to trigger UI updates
    private var timer: Timer?
    let timerInterval: TimeInterval = 1.0
    private var hasNotifiedTargetReached = false // Track if we've already sent the notification

    public init(id: UUID, startDate: Date, elapsedTime: TimeInterval, dailyTarget: TimeInterval = 0, onTargetReached: (() -> Void)? = nil) {
        self.id = id
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.dailyTarget = dailyTarget
        self.onTargetReached = onTargetReached
        
        // If we're already past the target when initializing, mark as notified
        if dailyTarget > 0 && elapsedTime >= dailyTarget {
            hasNotifiedTargetReached = true
        }
    }
    
    public func timerText(currentTime: Date = .now) -> String {
        let elapsed = elapsedTime + currentTime.timeIntervalSince(startDate)
        let elapsedFormatted = elapsed.formatted(style: .components)
        
        // If we have a daily target, show it in the format "31m 6s/1h 30m"
        if dailyTarget > 0 {
            let targetFormatted = dailyTarget.formatted(style: .components)
            return "\(elapsedFormatted)/\(targetFormatted)"
        } else {
            return elapsedFormatted
        }
    }
    
    public func startUITimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            withAnimation {
                self.tickCount += 1
                self.timeText = self.timerText()
                self.currentTime = Date()
                
                // Check if target was just reached
                if !self.hasNotifiedTargetReached && self.dailyTarget > 0 {
                    if self.hasMetDailyTarget {
                        self.hasNotifiedTargetReached = true
                        self.onTargetReached?()
                    }
                }
                
                // Call tick callback for external updates (e.g., Live Activity)
                self.onTick?()
            }
        }
    }
    
    public func stopUITimer() {
        timer?.invalidate()
        timer = nil
    }

}
