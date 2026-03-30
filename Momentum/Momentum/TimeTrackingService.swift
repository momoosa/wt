//
//  TimeTrackingService.swift
//  Momentum
//
//  Created by Assistant on 30/03/2026.
//

import Foundation
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
}

// MARK: - Supporting Types

struct TimeTrackingProject: Identifiable, Codable {
    let id: String
    let name: String
    let color: String?
    let clientName: String?
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
    var apiKey: String?
    var projectMappings: [String: String] = [:] // goalID -> projectID

    enum ServiceType: String, Codable, CaseIterable {
        case toggl = "Toggl Track"
        case clockify = "Clockify"
        case harvest = "Harvest"

        var id: String { rawValue }
    }
}

// MARK: - Service Manager

/// Manages the active time tracking service
@Observable
class TimeTrackingServiceManager {
    private(set) var config: TimeTrackingServiceConfig
    private var activeService: TimeTrackingService?

    init() {
        // Load config from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "TimeTrackingServiceConfig"),
           let config = try? JSONDecoder().decode(TimeTrackingServiceConfig.self, from: data) {
            self.config = config
        } else {
            self.config = TimeTrackingServiceConfig()
        }

        // Initialize service if configured
        if config.isEnabled {
            setupService()
        }
    }

    private func setupService() {
        switch config.serviceType {
        case .toggl:
            activeService = TogglService()
        case .clockify:
            activeService = nil // TODO: Implement
        case .harvest:
            activeService = nil // TODO: Implement
        }

        // Authenticate if we have an API key
        if let apiKey = config.apiKey {
            Task {
                try? await activeService?.authenticate(apiKey: apiKey)
            }
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
        guard let service = activeService else {
            throw TimeTrackingError.notAuthenticated
        }

        try await service.reportSession(
            goal: goal,
            duration: duration,
            startDate: startDate,
            notes: notes
        )
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
}
