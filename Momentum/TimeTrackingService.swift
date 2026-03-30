//
//  TimeTrackingService.swift
//  Momentum
//
//  Created by Assistant on 30/03/2026.
//

import Foundation
import SwiftData
import MomentumKit

// MARK: - Protocol

/// Protocol for external time tracking service integrations
protocol TimeTrackingService {
    /// Service name (e.g., "Toggl", "Clockify", "Harvest")
    var serviceName: String { get }

    /// Whether the service is currently authenticated
    var isAuthenticated: Bool { get }

    /// Authenticate with the service
    func authenticate(apiKey: String) async throws

    /// Log out from the service
    func logout()

    /// Report a completed goal session to the service
    /// - Parameters:
    ///   - goal: The goal that was worked on
    ///   - duration: Duration in seconds
    ///   - startDate: When the session started
    ///   - notes: Optional notes about the session
    func reportSession(
        goal: Goal,
        duration: TimeInterval,
        startDate: Date,
        notes: String?
    ) async throws

    /// Get available projects/categories from the service
    func fetchProjects() async throws -> [TimeTrackingProject]

    /// Map a goal to a project in the external service
    func mapGoal(_ goal: Goal, toProjectID projectID: String) async throws
    
    /// Fetch time entries from the service for a date range
    func fetchTimeEntries(startDate: Date, endDate: Date) async throws -> [TimeTrackingEntry]
}

// MARK: - Supporting Types

struct TimeTrackingProject: Identifiable, Codable {
    let id: String
    let name: String
    let color: String?
    let clientName: String?
}

struct TimeTrackingEntry: Identifiable, Codable {
    let id: String
    let projectID: String?
    let description: String
    let startDate: Date
    let duration: TimeInterval
    let tags: [String]
}

enum TimeTrackingError: LocalizedError {
    case notAuthenticated
    case invalidAPIKey
    case networkError(Error)
    case projectNotFound
    case rateLimitExceeded
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with time tracking service"
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .projectNotFound:
            return "Project not found"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .invalidResponse:
            return "Invalid response from service"
        }
    }
}

// MARK: - Service Configuration

struct TimeTrackingServiceConfig: Codable {
    var isEnabled: Bool = false
    var serviceType: ServiceType = .toggl
    // Note: API key/credentials now stored in Keychain, not here
    var projectMappings: [String: String] = [:] // goalID -> projectID

    enum ServiceType: String, Codable, CaseIterable {
        case toggl = "Toggl Track"

        var id: String { rawValue }
    }
}

// MARK: - Service Manager

/// Pending session for batch sync
struct PendingSession: Codable {
    let goalID: String
    let goalTitle: String
    let duration: TimeInterval
    let startDate: Date
    let notes: String?
}

/// Manages the active time tracking service
@Observable
class TimeTrackingServiceManager {
    private(set) var config: TimeTrackingServiceConfig
    var activeService: TimeTrackingService?
    private var pendingSessions: [PendingSession] = []
    private var syncTimer: Timer?
    private let batchSyncInterval: TimeInterval = 300 // 5 minutes
    
    var pendingSessionCount: Int {
        pendingSessions.count
    }

    init() {
        // Load config from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "TimeTrackingServiceConfig"),
           let config = try? JSONDecoder().decode(TimeTrackingServiceConfig.self, from: data) {
            self.config = config
        } else {
            self.config = TimeTrackingServiceConfig()
        }
        
        // Load pending sessions
        loadPendingSessions()

        // Initialize service if configured
        if config.isEnabled {
            setupService()
            startBatchSyncTimer()
        }
    }

    private func setupService() {
        switch config.serviceType {
        case .toggl:
            // TogglService initializer automatically loads credentials from Keychain
            activeService = TogglService()
        }
    }

    func updateConfig(_ newConfig: TimeTrackingServiceConfig) {
        self.config = newConfig

        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: "TimeTrackingServiceConfig")
        }

        // Reinitialize service
        if newConfig.isEnabled {
            setupService()
        } else {
            activeService?.logout()
            activeService = nil
        }
    }

    func reportSession(
        goal: Goal,
        duration: TimeInterval,
        startDate: Date,
        notes: String? = nil
    ) async throws {
        guard config.isEnabled else { return }
        
        // Always queue sessions instead of syncing immediately
        // This prevents hitting rate limits by batching requests
        let pending = PendingSession(
            goalID: goal.id.uuidString,
            goalTitle: goal.title,
            duration: duration,
            startDate: startDate,
            notes: notes
        )
        
        pendingSessions.append(pending)
        savePendingSessions()
        
        print("📋 Queued session: \(goal.title) - \(pendingSessions.count) pending")
    }
    
    private func loadPendingSessions() {
        if let data = UserDefaults.standard.data(forKey: "PendingTogglSessions"),
           let sessions = try? JSONDecoder().decode([PendingSession].self, from: data) {
            pendingSessions = sessions
        }
    }
    
    private func savePendingSessions() {
        if let data = try? JSONEncoder().encode(pendingSessions) {
            UserDefaults.standard.set(data, forKey: "PendingTogglSessions")
        }
    }
    
    private func startBatchSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: batchSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncPendingSessions()
            }
        }
    }
    
    /// Manually trigger batch sync of pending sessions
    func syncPendingSessionsNow(goals: [Goal]) async -> (synced: Int, failed: Int) {
        await syncPendingSessions(goals: goals)
    }
    
    @MainActor
    private func syncPendingSessions(goals: [Goal]? = nil) async -> (synced: Int, failed: Int) {
        guard !pendingSessions.isEmpty else { return (0, 0) }
        guard let service = activeService else { return (0, pendingSessions.count) }
        
        print("🔄 Starting batch sync of \(pendingSessions.count) sessions...")
        
        var successCount = 0
        var failCount = 0
        var remainingSessions: [PendingSession] = []
        
        // Process in smaller batches to be extra conservative
        let batchSize = 5 // Only sync 5 at a time
        let sessionsToSync = Array(pendingSessions.prefix(batchSize))
        let remainingFromStart = Array(pendingSessions.dropFirst(batchSize))
        
        for pending in sessionsToSync {
            // Find matching goal if provided
            guard let goals = goals,
                  let goal = goals.first(where: { $0.id.uuidString == pending.goalID }) else {
                remainingSessions.append(pending)
                continue
            }
            
            do {
                try await service.reportSession(
                    goal: goal,
                    duration: pending.duration,
                    startDate: pending.startDate,
                    notes: pending.notes
                )
                successCount += 1
                print("✓ Synced: \(pending.goalTitle)")
            } catch {
                print("✗ Failed: \(pending.goalTitle) - \(error.localizedDescription)")
                remainingSessions.append(pending)
                failCount += 1
                
                // If we hit rate limit, stop immediately and keep all remaining
                if case TimeTrackingError.rateLimitExceeded = error {
                    print("⚠️ Rate limit hit - stopping sync")
                    let currentIndex = sessionsToSync.firstIndex(where: { $0.goalID == pending.goalID }) ?? 0
                    remainingSessions.append(contentsOf: sessionsToSync.dropFirst(currentIndex + 1))
                    break
                }
            }
            
            // Add 2 second delay between requests to be very conservative
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        // Add back sessions that weren't processed in this batch
        remainingSessions.append(contentsOf: remainingFromStart)
        
        pendingSessions = remainingSessions
        savePendingSessions()
        
        if successCount > 0 || failCount > 0 {
            print("📊 Sync complete: \(successCount) succeeded, \(failCount) failed, \(remainingSessions.count) remaining")
        }
        
        return (successCount, failCount)
    }

    func fetchProjects() async throws -> [TimeTrackingProject] {
        guard let service = activeService else {
            throw TimeTrackingError.notAuthenticated
        }
        return try await service.fetchProjects()
    }

    func mapGoal(_ goal: Goal, toProjectID projectID: String) {
        config.projectMappings[goal.id.uuidString] = projectID
        updateConfig(config)
    }
    
    /// Sync time entries from the service and create historical sessions
    func syncTimeEntries(
        goals: [Goal],
        days: [Day],
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) async throws -> Int {
        guard let service = activeService else {
            throw TimeTrackingError.notAuthenticated
        }
        
        let entries = try await service.fetchTimeEntries(startDate: startDate, endDate: endDate)
        
        // Build reverse mapping: projectID -> goal
        var projectToGoal: [String: Goal] = [:]
        for (goalID, projectID) in config.projectMappings {
            if let goal = goals.first(where: { $0.id.uuidString == goalID }) {
                projectToGoal[projectID] = goal
            }
        }
        
        // Build day lookup by ID
        var daysByID: [String: Day] = [:]
        for day in days {
            daysByID[day.id] = day
        }
        
        let calendar = Calendar.current
        var importedCount = 0
        
        for entry in entries {
            guard let projectID = entry.projectID,
                  let goal = projectToGoal[projectID] else {
                continue
            }
            
            // Find or create the day for this entry
            let dayDate = calendar.startOfDay(for: entry.startDate)
            let dayID = dayDate.yearMonthDayID(with: calendar)
            
            let day: Day
            if let existingDay = daysByID[dayID] {
                day = existingDay
            } else {
                // Create new day
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate)!
                day = Day(start: dayDate, end: dayEnd, calendar: calendar)
                modelContext.insert(day)
                daysByID[dayID] = day
            }
            
            // Create historical session
            let sessionEndDate = entry.startDate.addingTimeInterval(entry.duration)
            let historicalSession = HistoricalSession(
                title: entry.description,
                start: entry.startDate,
                end: sessionEndDate,
                needsHealthKitRecord: false
            )
            historicalSession.goalIDs = [goal.id.uuidString]
            modelContext.insert(historicalSession)
            day.add(historicalSession: historicalSession)
            
            importedCount += 1
        }
        
        try modelContext.save()
        return importedCount
    }
}
