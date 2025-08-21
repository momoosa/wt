//
//  WeekStore.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 20/08/2025.
//



import Foundation
import SwiftData
import EventKit
import os.log

public final class WeekStore {
    enum Error: Swift.Error {
        case invalidDate
    }
    private let logger = Logger()
    private var context: ModelContext
    public init(modelContext: ModelContext) {
        self.context = modelContext
    }
    
    
    public func fetchCurrentDay(with calendar: Calendar = .current) throws -> Day {
        let dayID = Date.now.yearMonthDayID(with: calendar)
        
        let request = FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID }, sortBy: [])
        //        let request = FetchDescriptor<Week>(sortBy: [])
        
        
        guard let current = try context.fetch(request).first else {
            let startDate = Date.now.startOfDay() ?? .now
            let endDate = Date.now.endOfDay() ?? .now
            let day = Day(start: startDate, end: endDate)
            context.insert(day)
            logger.debug("No existing day found for \(dayID); created new one.")
            try context.save()
            return day
        }
        
        return current
    }
}
