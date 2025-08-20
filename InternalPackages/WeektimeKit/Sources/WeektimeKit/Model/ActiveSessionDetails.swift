//
//  ActiveSessionDetails.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 20/08/2025.
//


import SwiftUI
import SwiftData

@Observable
final class ActiveSessionDetails {
    public private(set) var activeSessionID: UUID? = nil
    public private(set) var activeSessionStartDate: Date? = nil
    public private(set) var activeSessionElapsedTime: TimeInterval = 0
    
    private func timerText(for session: GoalSession, currentTime: Date = .now) -> String {
        let elapsed: TimeInterval
        if activeSessionID == session.id, let startDate = activeSessionStartDate {
            elapsed = activeSessionElapsedTime + currentTime.timeIntervalSince(startDate)
        } else {
            elapsed = 0
        }
        return Duration.seconds(elapsed).formatted()
    }
}
