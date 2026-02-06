//
//  ActiveSessionDetails.swift
//  MomentumKit
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
    public private(set) var tickCount: Int = 0 // Increments every second to trigger UI updates
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
        let elapsedFormatted = formatTimeWithUnits(elapsed)
        
        // If we have a daily target, show it in the format "31m 6s/1h 30m"
        if let dailyTarget = dailyTarget {
            let targetFormatted = formatTimeWithUnits(dailyTarget)
            return "\(elapsedFormatted)/\(targetFormatted)"
        } else {
            return elapsedFormatted
        }
    }
    
    private func formatTimeWithUnits(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        var components: [String] = []
        
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 {
            components.append("\(minutes)m")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds)s")
        }
        
        return components.joined(separator: " ")
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
                self.tickCount += 1
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
