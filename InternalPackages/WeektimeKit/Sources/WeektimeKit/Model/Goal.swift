//
//  Goal.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 26/07/2025.
//

import Foundation
import SwiftData

@Model
public final class Goal {
    public private(set) var id: UUID
    public var title: String
    public var status: Status
    public var primaryTheme: GoalTheme
    public var weeklyTarget: TimeInterval // Target duration in seconds for the week
    public var notificationsEnabled: Bool // Whether to send notifications when target is reached
    
    // HealthKit Integration
    public var healthKitMetricRawValue: String? // Stores the HealthKitMetric raw value
    public var healthKitSyncEnabled: Bool = false // Whether to sync time from HealthKit
    
    // Time of Day Preferences (for AI planner)
    public var preferredTimesOfDay: [String] = [] // e.g., ["morning", "afternoon", "evening", "night"]
    
    @Relationship
    var goalSessions: [GoalSession] = []
    @Relationship public var checklistItems: [ChecklistItem] = []
    @Relationship public var intervalLists: [IntervalList] = []

    public init(title: String, primaryTheme: GoalTheme, weeklyTarget: TimeInterval = 0, notificationsEnabled: Bool = false, healthKitMetric: HealthKitMetric? = nil, healthKitSyncEnabled: Bool = false) {
        self.id = UUID()
        self.title = title
        self.status = .active
        self.primaryTheme = primaryTheme
        self.weeklyTarget = weeklyTarget
        self.notificationsEnabled = notificationsEnabled
        self.healthKitMetricRawValue = healthKitMetric?.rawValue
        self.healthKitSyncEnabled = healthKitSyncEnabled
    }
}

public extension Goal {
    enum Status: String, Codable {
        case suggestion
        case active
        case archived
    }
    
    /// The HealthKit metric associated with this goal, if any
    var healthKitMetric: HealthKitMetric? {
        get {
            guard let rawValue = healthKitMetricRawValue else { return nil }
            return HealthKitMetric(rawValue: rawValue)
        }
        set {
            healthKitMetricRawValue = newValue?.rawValue
        }
    }
}
