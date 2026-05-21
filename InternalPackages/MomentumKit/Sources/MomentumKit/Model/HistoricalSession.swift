//
//  HistoricalSession.swift
//  MomentumKit
//
//  Created by Mo Moosa on 27/07/2025.
//


//
//  HistoricalSession.swift
//  MomentumKit
//
//  Created by Mo Moosa on 13/10/2023.
//
import Foundation
import SwiftData

@Model
public final class HistoricalSession {
    public var id: String = UUID().uuidString
    public var goalIDs: [String] = []
    public var title: String = ""
    public var healthKitType: String?
    
    @Relationship(deleteRule: .nullify)
    public var day: Day?
    
    public var startDate: Date = Date()
    public var endDate: Date = Date()
    public var needsHealthKitRecord: Bool = false
    public var notes: String?
    
    public init(id: String = UUID().uuidString, title: String, start: Date, end: Date, healthKitType: String? = nil, needsHealthKitRecord: Bool, notes: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = start
        self.healthKitType = healthKitType
        self.endDate = end
        self.needsHealthKitRecord = needsHealthKitRecord
        self.notes = notes
    }
    
    public var duration: Double { // TODO: Extension
        return endDate.timeIntervalSince(startDate)
    }
    
    /// Update the HealthKit type for this session
    public func setHealthKitType(_ type: String?) {
        self.healthKitType = type
    }
}

