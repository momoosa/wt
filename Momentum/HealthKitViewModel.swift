//
//  HealthKitViewModel.swift
//  Momentum
//
//  ViewModel for HealthKit sync operations and state management
//

import Foundation
import SwiftUI
import HealthKit
import MomentumKit

/// ViewModel handling HealthKit sync state and coordination
@Observable
class HealthKitViewModel {
    // MARK: - Dependencies
    
    private let healthKitManager: HealthKitManaging
    private let healthKitSyncService: HealthKitSyncService
    
    // MARK: - State
    
    /// HealthKit observers for real-time updates
    var healthKitObservers: [HKObserverQuery] = []
    
    /// Is currently syncing HealthKit data
    var isSyncingHealthKit = false
    
    // MARK: - Initialization
    
    init(healthKitManager: HealthKitManaging, healthKitSyncService: HealthKitSyncService) {
        self.healthKitManager = healthKitManager
        self.healthKitSyncService = healthKitSyncService
    }
    
    // MARK: - HealthKit Sync
    
    /// Sync HealthKit data for all enabled goals
    func syncHealthKitData(
        for goals: [Goal],
        sessions: [GoalSession],
        in day: Day,
        userInitiated: Bool = false
    ) async -> HealthKitSyncResult {
        isSyncingHealthKit = true
        
        // Delegate to service for the actual sync
        let result = await healthKitSyncService.syncHealthKitData(
            for: goals,
            sessions: sessions,
            in: day,
            userInitiated: userInitiated
        )
        
        isSyncingHealthKit = false
        
        return result
    }
    
    /// Start observing HealthKit changes for real-time updates
    func startHealthKitObservers(for goals: [Goal]) {
        // Stop any existing observers first
        stopHealthKitObservers()
        
        // Delegate to service for observer setup
        healthKitObservers = healthKitSyncService.startHealthKitObservers(for: goals)
    }
    
    /// Stop all HealthKit observers
    func stopHealthKitObservers() {
        healthKitSyncService.stopHealthKitObservers(healthKitObservers)
        healthKitObservers.removeAll()
    }
}
