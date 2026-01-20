//
//  Day.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 27/07/2025.
//

import Foundation
import SwiftData

@Model
public final class Day {
    public private(set) var id: String
    public var dayComponent: Int {
        Calendar.current.component(.day, from: startDate)
    }
    public var fullTitle: String {
        return "\(dayComponent) \(title)"
    }
    public var title: String {
        startDate.formatted(.dateTime.month(.wide))
    }
    public private(set) var startDate: Date
    public private(set) var endDate: Date
    public private(set) var initial: String?
    public private(set) var weekdayTitle: String?
    public private(set) var weekdayID: Int16
    @Relationship(inverse: \GoalSession.day)
    public private(set) var sessions: [GoalSession] = []
    
    @Relationship(inverse: \HistoricalSession.day)
    public private(set) var historicalSessions: [HistoricalSession] = []
    
    public init(start: Date, end: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents(Calendar.Component.yearMonthDay.union(Set(arrayLiteral: .weekday)), from: start)
        let weekday = components.weekday ?? 1

        let shortSymbols = calendar.veryShortStandaloneWeekdaySymbols
        let symbols = calendar.weekdaySymbols
        self.id = start.yearMonthDayID(with: calendar)
        self.startDate = start
        self.endDate = end
        initial = shortSymbols[weekday - 1]
        weekdayTitle = symbols[weekday - 1]
        weekdayID = Int16(weekday)
    }

    public func removeAllSessions() {
        for session in sessions {
            modelContext?.delete(session)
        }
        sessions.removeAll()
    }
    
    public func add(historicalSession: HistoricalSession) {
        if let index = historicalSessions.firstIndex(where: { $0.id == historicalSession.id }) {
            historicalSessions[index] = historicalSession
        } else {
            historicalSessions.append(historicalSession)
        }
    }
}
