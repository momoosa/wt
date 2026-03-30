//
//  TogglService.swift
//  Momentum
//
//  Created by Assistant on 30/03/2026.
//

import Foundation
import MomentumKit

/// Toggl Track API integration
class TogglService: TimeTrackingService {
    let serviceName = "Toggl Track"

    private let baseURL = "https://api.track.toggl.com/api/v9"
    private var apiKey: String?
    private var workspaceID: String?

    var isAuthenticated: Bool {
        apiKey != nil && workspaceID != nil
    }

    func authenticate(apiKey: String) async throws {
        self.apiKey = apiKey

        // Fetch user profile to get workspace ID
        let profile = try await fetchUserProfile()
        self.workspaceID = profile.default_workspace_id

        // Save credentials
        UserDefaults.standard.set(apiKey, forKey: "TogglAPIKey")
        UserDefaults.standard.set(workspaceID, forKey: "TogglWorkspaceID")
    }

    func logout() {
        apiKey = nil
        workspaceID = nil
        UserDefaults.standard.removeObject(forKey: "TogglAPIKey")
        UserDefaults.standard.removeObject(forKey: "TogglWorkspaceID")
    }

    func reportSession(
        goal: Goal,
        duration: TimeInterval,
        startDate: Date,
        notes: String?
    ) async throws {
        guard let apiKey = apiKey, let workspaceID = workspaceID else {
            throw TimeTrackingError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/workspaces/\(workspaceID)/time_entries")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(apiKey.base64Encoded())", forHTTPHeaderField: "Authorization")

        let endDate = startDate.addingTimeInterval(duration)

        let body: [String: Any] = [
            "description": goal.title,
            "start": ISO8601DateFormatter().string(from: startDate),
            "stop": ISO8601DateFormatter().string(from: endDate),
            "duration": Int(duration),
            "created_with": "Momentum iOS",
            "tags": goal.primaryTag.map { [$0.title] } ?? []
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TimeTrackingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw TimeTrackingError.rateLimitExceeded
            }
            throw TimeTrackingError.networkError(
                NSError(domain: "TogglAPI", code: httpResponse.statusCode)
            )
        }
    }

    func fetchProjects() async throws -> [TimeTrackingProject] {
        guard let apiKey = apiKey, let workspaceID = workspaceID else {
            throw TimeTrackingError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/workspaces/\(workspaceID)/projects")!
        var request = URLRequest(url: url)
        request.setValue("Basic \(apiKey.base64Encoded())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TimeTrackingError.invalidResponse
        }

        let projects = try JSONDecoder().decode([TogglProject].self, from: data)

        return projects.map { project in
            TimeTrackingProject(
                id: String(project.id),
                name: project.name,
                color: project.color,
                clientName: project.client_name
            )
        }
    }

    func mapGoal(_ goal: Goal, toProjectID projectID: String) async throws {
        // Mapping is handled by TimeTrackingServiceManager
        // This could be extended to sync tags or other metadata
    }

    // MARK: - Private Helper Methods

    private func fetchUserProfile() async throws -> TogglUser {
        guard let apiKey = apiKey else {
            throw TimeTrackingError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/me")!
        var request = URLRequest(url: url)
        request.setValue("Basic \(apiKey.base64Encoded())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TimeTrackingError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            throw TimeTrackingError.invalidAPIKey
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TimeTrackingError.networkError(
                NSError(domain: "TogglAPI", code: httpResponse.statusCode)
            )
        }

        return try JSONDecoder().decode(TogglUser.self, from: data)
    }
}

// MARK: - Toggl API Models

private struct TogglUser: Codable {
    let id: Int
    let email: String
    let default_workspace_id: String
}

private struct TogglProject: Codable {
    let id: Int
    let name: String
    let color: String?
    let client_name: String?
    let workspace_id: String
}

// MARK: - String Extension

private extension String {
    func base64Encoded() -> String {
        // Toggl uses "api_token:api_token" format for Basic Auth
        let credentials = "\(self):api_token"
        return Data(credentials.utf8).base64EncodedString()
    }
}
