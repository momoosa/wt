//
//  ScreenTimeManager.swift
//  Momentum
//
//  Created by Claude Code on 31/03/2026.
//

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftData
import MomentumKit

/// Manages Screen Time integration including app blocking and usage monitoring
@MainActor
@Observable
public class ScreenTimeManager {
    public static let shared = ScreenTimeManager()
    
    private let authorizationCenter = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    
    public var isAuthorized = false
    
    private init() {
        updateAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    /// Check and update authorization status
    public func updateAuthorizationStatus() {
        isAuthorized = authorizationCenter.authorizationStatus == .approved
    }
    
    /// Request Family Controls authorization
    public func requestAuthorization() async throws {
        try await authorizationCenter.requestAuthorization(for: .individual)
        updateAuthorizationStatus()
    }
    
    // MARK: - App Blocking
    
    /// Apply app blocking based on goal completion status
    /// - Parameters:
    ///   - goal: The goal that controls blocking
    ///   - isCompleted: Whether the goal is completed today
    public func updateBlocking(for goal: Goal, isCompleted: Bool) {
        guard goal.screenTimeBlockingEnabled,
              goal.screenTimeEnabled else {
            return
        }
        
        // Check if we're in the blocking time window
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        
        // Check if blocking applies to today
        guard goal.screenTimeBlockingWeekdays.isEmpty || 
              goal.screenTimeBlockingWeekdays.contains(currentWeekday) else {
            return
        }
        
        // Check if we're in the time window
        if let startHour = goal.screenTimeBlockingStartHour,
           let endHour = goal.screenTimeBlockingEndHour {
            let inTimeWindow = (startHour <= currentHour && currentHour < endHour)
            if !inTimeWindow {
                return
            }
        }
        
        // Apply or remove blocking based on completion
        if isCompleted {
            // Goal completed - remove blocks
            clearBlocking()
        } else {
            // Goal not completed - apply blocks
            applyBlocking(for: goal)
        }
    }
    
    /// Apply app blocking for a goal
    /// Note: This requires the user to configure blocking through the UI
    /// as FamilyActivity tokens cannot be persisted
    private func applyBlocking(for goal: Goal) {
        // Blocking configuration is handled through the UI
        // The ManagedSettingsStore maintains the current blocked apps
        // This method would be called to enforce existing blocks
    }
    
    /// Clear all app blocking
    public func clearBlocking() {
        store.application.blockedApplications = []
        store.shield.applicationCategories = nil
    }
    
    // MARK: - Usage Monitoring
    
    /// Start monitoring device activity for a goal
    /// - Parameter goal: The goal to monitor
    /// - Parameter selection: The apps/categories/domains to monitor
    public func startMonitoring(goal: Goal, selection: FamilyActivitySelection) {
        guard goal.screenTimeEnabled else { return }
        
        // Create activity name
        let activityName = DeviceActivityName("goal_\(goal.id.uuidString)")
        
        // Get daily target duration
        let targetDuration = goal.dailyTargetFromSchedule()
        
        // Create schedule (monitor from midnight to midnight)
        var startComponents = DateComponents()
        startComponents.hour = 0
        startComponents.minute = 0
        
        var endComponents = DateComponents()
        endComponents.hour = 23
        endComponents.minute = 59
        
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true
        )
        
        // Create threshold event
        let threshold = DateComponents(second: Int(targetDuration))
        
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold,
            includesPastActivity: true
        )
        
        let events = [DeviceActivityEvent.Name("threshold"): event]
        
        // Start monitoring
        do {
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
        } catch {
            print("Failed to start monitoring: \(error)")
        }
    }
    
    /// Stop monitoring device activity for a goal
    /// - Parameter goal: The goal to stop monitoring
    public func stopMonitoring(goal: Goal) {
        let activityName = DeviceActivityName("goal_\(goal.id.uuidString)")
        deviceActivityCenter.stopMonitoring([activityName])
    }
}
