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
    private var timer: Timer?
    let timerInterval: TimeInterval = 1.0

    public init(id: UUID, startDate: Date, elapsedTime: TimeInterval) {
        self.id = id
        self.startDate = startDate
        self.elapsedTime = elapsedTime
    }
    
    public func timerText(currentTime: Date = .now) -> String {
        let elapsed = elapsedTime + currentTime.timeIntervalSince(startDate)
        let formatted = Duration.seconds(elapsed).formatted()
        return formatted
    }
    
    public func startUITimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            withAnimation {
                self.timeText = self.timerText()
                self.currentTime = Date()
            }
        }
    }
    
    public func stopUITimer() {
        timer?.invalidate()
        timer = nil
    }

}
