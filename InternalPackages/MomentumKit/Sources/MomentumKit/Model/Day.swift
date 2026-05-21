//
//  Day.swift
//  MomentumKit
//
//  Created by Mo Moosa on 27/07/2025.
//

import Foundation
import SwiftData

@Model
public final class Day {
    public var id: String = ""
    public var dayComponent: Int {
        Calendar.current.component(.day, from: startDate)
    }
    public var fullTitle: String {
        return "\(dayComponent) \(title)"
    }
    public var title: String {
        startDate.formatted(.dateTime.month(.wide))
    }
    public var startDate: Date = Date()
    public var endDate: Date = Date()
    public var initial: String? = nil
    public var weekdayTitle: String? = nil
    public var weekdayID: Int16 = 1
    
    @Relationship(deleteRule: .cascade)
    public var sessions: [GoalSession]? = []
    
    @Relationship(deleteRule: .cascade)
    public var historicalSessions: [HistoricalSession]? = []
    
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
        guard let sessions = sessions else { return }
        for session in sessions {
            modelContext?.delete(session)
        }
        self.sessions?.removeAll()
    }
    
    public func add(historicalSession: HistoricalSession) {
        if historicalSessions == nil {
            historicalSessions = []
        }
        if let index = historicalSessions?.firstIndex(where: { $0.id == historicalSession.id }) {
            historicalSessions?[index] = historicalSession
        } else {
            historicalSessions?.append(historicalSession)
        }
    }
}
