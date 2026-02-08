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
    public private(set) var id: String
    public var goalIDs: [String] = []
    public private(set) var title: String
    public private(set) var healthKitType: String?
    @Relationship
    public private(set) var day: Day?
    public var startDate: Date
    public var endDate: Date
    public var needsHealthKitRecord: Bool
    
    public init(id: String = UUID().uuidString, title: String, start: Date, end: Date, healthKitType: String? = nil, needsHealthKitRecord: Bool) {
        self.id = id
        self.title = title
        self.startDate = start
        self.healthKitType = healthKitType
        self.endDate = end
        self.needsHealthKitRecord = needsHealthKitRecord
    }
    
    public var duration: Double { // TODO: Extension
        return endDate.timeIntervalSince(startDate)
    }
    
    /// Update the HealthKit type for this session
    public func setHealthKitType(_ type: String?) {
        self.healthKitType = type
    }
}

