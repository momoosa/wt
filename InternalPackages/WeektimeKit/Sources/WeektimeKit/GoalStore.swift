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
@Observable
public final class GoalStore {
    
    public init() {
        
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
