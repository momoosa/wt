//
//  ActiveSessionDetails.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 20/08/2025.
//


import SwiftUI
import SwiftData

@Observable
public final class ActiveSessionDetails {
    public private(set) var id: UUID
    public private(set) var startDate: Date
    public private(set) var elapsedTime: TimeInterval = 0
    public var currentTime: Date?
    public private(set) var timeText: String?
    public var dailyTarget: TimeInterval? // Add daily target
    public var onTargetReached: (() -> Void)? // Callback when target is reached
    private var timer: Timer?
    let timerInterval: TimeInterval = 1.0
    private var hasNotifiedTargetReached = false // Track if we've already sent the notification

    public init(id: UUID, startDate: Date, elapsedTime: TimeInterval, dailyTarget: TimeInterval? = nil, onTargetReached: (() -> Void)? = nil) {
        self.id = id
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.dailyTarget = dailyTarget
        self.onTargetReached = onTargetReached
        
        // If we're already past the target when initializing, mark as notified
        if let dailyTarget = dailyTarget, elapsedTime >= dailyTarget {
            hasNotifiedTargetReached = true
        }
    }
    
    public func timerText(currentTime: Date = .now) -> String {
        let elapsed = elapsedTime + currentTime.timeIntervalSince(startDate)
        let elapsedFormatted = Duration.seconds(elapsed).formatted(.time(pattern: .hourMinuteSecond))
        
        // If we have a daily target, show it in the format "0:10:01/0:12:00"
        if let dailyTarget = dailyTarget {
            let targetFormatted = Duration.seconds(dailyTarget).formatted(.time(pattern: .hourMinuteSecond))
            return "\(elapsedFormatted)/\(targetFormatted)"
        } else {
            return elapsedFormatted
        }
    }
    
    public var hasMetDailyTarget: Bool {
        guard let dailyTarget = dailyTarget else { return false }
        let elapsed = elapsedTime + Date.now.timeIntervalSince(startDate)
        return elapsed >= dailyTarget
    }
    
    public var progress: Double {
        guard let dailyTarget = dailyTarget, dailyTarget > 0 else { return 0 }
        let elapsed = elapsedTime + Date.now.timeIntervalSince(startDate)
        return min(elapsed / dailyTarget, 1.0)
    }
    
    public func startUITimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            withAnimation {
                self.timeText = self.timerText()
                self.currentTime = Date()
                
                // Check if target was just reached
                if !self.hasNotifiedTargetReached, let dailyTarget = self.dailyTarget {
                    let elapsed = self.elapsedTime + Date.now.timeIntervalSince(self.startDate)
                    if elapsed >= dailyTarget {
                        self.hasNotifiedTargetReached = true
                        self.onTargetReached?()
                    }
                }
            }
        }
    }
    
    public func stopUITimer() {
        timer?.invalidate()
        timer = nil
    }

}
