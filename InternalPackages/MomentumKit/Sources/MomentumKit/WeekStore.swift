//
//  WeekStore.swift
//  MomentumKit
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
        let existingDays = try context.fetch(request)
        
        // Handle duplicate days from CloudKit sync conflicts
        if existingDays.count > 1 {
            logger.warning("Found \(existingDays.count) duplicate days for \(dayID). Merging and cleaning up...")
            return try mergeDuplicateDays(existingDays, dayID: dayID)
        }
        
        guard let current = existingDays.first else {
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
    
    /// Merges duplicate Day objects that can occur from CloudKit sync conflicts
    private func mergeDuplicateDays(_ days: [Day], dayID: String) throws -> Day {
        guard let primaryDay = days.first else {
            throw Error.invalidDate
        }
        
        // Merge sessions from all duplicate days into the primary day
        for duplicateDay in days.dropFirst() {
            if let sessions = duplicateDay.sessions {
                for session in sessions {
                    // Transfer session to primary day
                    if primaryDay.sessions?.contains(where: { $0.id == session.id }) == false {
                        primaryDay.sessions?.append(session)
                    }
                }
            }
            
            // Delete the duplicate
            context.delete(duplicateDay)
            logger.debug("Deleted duplicate day: \(dayID)")
        }
        
        try context.save()
        logger.info("Merged \(days.count) duplicate days for \(dayID)")
        return primaryDay
    }
    
    /// Cleanup function to remove all duplicate days in the database
    public func cleanupDuplicateDays() throws {
        let allDaysRequest = FetchDescriptor<Day>(sortBy: [SortDescriptor(\.id)])
        let allDays = try context.fetch(allDaysRequest)
        
        var seenIDs: Set<String> = []
        var duplicateGroups: [String: [Day]] = [:]
        
        for day in allDays {
            if seenIDs.contains(day.id) {
                duplicateGroups[day.id, default: []].append(day)
            } else {
                seenIDs.insert(day.id)
                duplicateGroups[day.id] = [day]
            }
        }
        
        var mergedCount = 0
        for (dayID, days) in duplicateGroups where days.count > 1 {
            _ = try mergeDuplicateDays(days, dayID: dayID)
            mergedCount += days.count - 1
        }
        
        if mergedCount > 0 {
            logger.info("Cleaned up \(mergedCount) duplicate days")
        }
    }
}
