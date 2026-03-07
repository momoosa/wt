//
//  GoalStore.swift
//  MomentumKit
//
//  Created by Mo Moosa on 20/08/2025.
//


//
//  ContentViewModel.swift
//  Momentum
//
//  Created by Mo Moosa on 20/08/2025.
//


import SwiftUI
import SwiftData

@Observable
public final class GoalStore {
    nonisolated(unsafe) public static let shared = GoalStore()
    
    // Store references to goals and sessions for App Intents
    public var goals: [Goal] = []
    public var sessions: [GoalSession] = []
    
    public init() {
        
    }
    
    /// Get today's session for a goal
    public func getTodaySession(for goal: Goal) -> GoalSession? {
        let todayID = Date().yearMonthDayID(with: Calendar.current)
        return sessions.first { session in
            session.goal.id == goal.id && session.day.id == todayID
        }
    }
    
    /// Get weekly progress for a goal in minutes
    public func getWeeklyProgress(for goal: Goal) -> Int {
        var totalTime: TimeInterval = 0
        let calendar = Calendar.current
        
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0
        }
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            let dayID = date.yearMonthDayID(with: calendar)
            
            if let session = sessions.first(where: { 
                $0.goal.id == goal.id && $0.day.id == dayID
            }) {
                totalTime += session.elapsedTime
                totalTime += session.healthKitTime
            }
        }
        
        return Int(totalTime / 60)
    }
    
    @discardableResult
    public func save(session: GoalSession, in day: Day, startDate: Date, endDate: Date) -> HistoricalSession? {
        let errorPrefix = "Warning: Goal received session to save that"

        guard let modelContext = session.modelContext else {
            print("\(errorPrefix) has no model context.")
            return nil
        }
        
        guard endDate.timeIntervalSince(startDate) > 0 else {
            print("Will not create historical session: duration is zero.")
            return nil
        }

        // TODO:
//
//        if let healthKitType = goal.healthKitDataSource.sampleType?.identifier {
//            do {
//                try self.healthKitStore?.saveMindfullAnalysis(startTime: startDate, endTime: endDate)
//            } catch {
//                
//            }
//        } else {
            let historicalSession = HistoricalSession(title: session.title, start: startDate, end: endDate, needsHealthKitRecord: false)
            modelContext.insert(historicalSession)
            historicalSession.goalIDs = [session.goalID]
            day.add(historicalSession: historicalSession)
            do {
                try modelContext.save()
                return historicalSession
            } catch {
                print("Error trying to save context: \(error)")
                // TODO
            }
//        }
        return nil
    }

}
