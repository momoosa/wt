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
    private var email: String?
    private var password: String?
    private var workspaceID: String?

    var isAuthenticated: Bool {
        email != nil && password != nil && workspaceID != nil
    }

    func authenticate(apiKey: String) async throws {
        // apiKey parameter is repurposed to accept "email:password" format
        let components = apiKey.split(separator: ":", maxSplits: 1)
        guard components.count == 2 else {
            throw TimeTrackingError.invalidAPIKey
        }
        
        let email = String(components[0])
        let password = String(components[1])
        
        self.email = email
        self.password = password

        // Fetch user profile to get workspace ID and validate credentials
        let profile = try await fetchUserProfile()
        self.workspaceID = String(profile.default_workspace_id)

        // Save credentials to Keychain
        _ = KeychainHelper.save(email, service: "com.momentum.toggl", account: "email")
        _ = KeychainHelper.save(password, service: "com.momentum.toggl", account: "password")
        UserDefaults.standard.set(workspaceID, forKey: "TogglWorkspaceID")
    }

    func logout() {
        email = nil
        password = nil
        workspaceID = nil
        KeychainHelper.delete(service: "com.momentum.toggl", account: "email")
        KeychainHelper.delete(service: "com.momentum.toggl", account: "password")
        UserDefaults.standard.removeObject(forKey: "TogglWorkspaceID")
    }
    
    /// Initialize with stored credentials if available
    init() {
        if let storedEmail = KeychainHelper.loadString(service: "com.momentum.toggl", account: "email"),
           let storedPassword = KeychainHelper.loadString(service: "com.momentum.toggl", account: "password"),
           let storedWorkspaceID = UserDefaults.standard.string(forKey: "TogglWorkspaceID") {
            self.email = storedEmail
            self.password = storedPassword
            self.workspaceID = storedWorkspaceID
        }
    }

    func reportSession(
        goal: Goal,
        duration: TimeInterval,
        startDate: Date,
        notes: String?
    ) async throws {
        guard let email = email, let password = password, let workspaceID = workspaceID else {
            throw TimeTrackingError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/workspaces/\(workspaceID)/time_entries")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(basicAuthHeader(email: email, password: password))", forHTTPHeaderField: "Authorization")

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
            if httpResponse.statusCode == 429 || httpResponse.statusCode == 402 {
                throw TimeTrackingError.rateLimitExceeded
            }
            throw TimeTrackingError.networkError(
                NSError(domain: "TogglAPI", code: httpResponse.statusCode)
            )
        }
    }

    func fetchProjects() async throws -> [TimeTrackingProject] {
        guard let email = email, let password = password, let workspaceID = workspaceID else {
            throw TimeTrackingError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/workspaces/\(workspaceID)/projects")!
        var request = URLRequest(url: url)
        request.setValue("Basic \(basicAuthHeader(email: email, password: password))", forHTTPHeaderField: "Authorization")

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
    
    func fetchTimeEntries(startDate: Date, endDate: Date) async throws -> [TimeTrackingEntry] {
        guard let email = email, let password = password else {
            throw TimeTrackingError.notAuthenticated
        }
        
        // Format dates for Toggl API (ISO8601)
        let formatter = ISO8601DateFormatter()
        let startDateStr = formatter.string(from: startDate)
        let endDateStr = formatter.string(from: endDate)
        
        let url = URL(string: "\(baseURL)/me/time_entries?start_date=\(startDateStr)&end_date=\(endDateStr)")!
        var request = URLRequest(url: url)
        request.setValue("Basic \(basicAuthHeader(email: email, password: password))", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TimeTrackingError.invalidResponse
        }
        
        let togglEntries = try JSONDecoder().decode([TogglTimeEntry].self, from: data)
        
        return togglEntries.compactMap { entry in
            guard let start = entry.start,
                  let duration = entry.duration,
                  duration > 0 else {
                return nil
            }
            
            return TimeTrackingEntry(
                id: String(entry.id),
                projectID: entry.project_id.map { String($0) },
                description: entry.description ?? "Untitled",
                startDate: start,
                duration: TimeInterval(duration),
                tags: entry.tags ?? []
            )
        }
    }

    // MARK: - Private Helper Methods

    private func fetchUserProfile() async throws -> TogglUser {
        guard let email = email, let password = password else {
            throw TimeTrackingError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/me")!
        var request = URLRequest(url: url)
        request.setValue("Basic \(basicAuthHeader(email: email, password: password))", forHTTPHeaderField: "Authorization")

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

        do {
            return try JSONDecoder().decode(TogglUser.self, from: data)
        } catch {
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Failed to decode Toggl user response: \(responseString)")
            }
            throw TimeTrackingError.invalidResponse
        }
    }
}

// MARK: - Toggl API Models

private struct TogglUser: Codable {
    let id: Int
    let email: String
    let default_workspace_id: Int
}

private struct TogglProject: Codable {
    let id: Int
    let name: String
    let color: String?
    let client_name: String?
    let workspace_id: Int
}

private struct TogglTimeEntry: Codable {
    let id: Int
    let workspace_id: Int
    let project_id: Int?
    let description: String?
    let start: Date?
    let duration: Int? // in seconds, negative if timer is running
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, workspace_id, project_id, description, start, duration, tags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        workspace_id = try container.decode(Int.self, forKey: .workspace_id)
        project_id = try container.decodeIfPresent(Int.self, forKey: .project_id)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        
        // Decode start date with ISO8601
        if let startString = try container.decodeIfPresent(String.self, forKey: .start) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            start = formatter.date(from: startString) ?? ISO8601DateFormatter().date(from: startString)
        } else {
            start = nil
        }
    }
}

// MARK: - Helper Methods

extension TogglService {
    private func basicAuthHeader(email: String, password: String) -> String {
        let credentials = "\(email):\(password)"
        return Data(credentials.utf8).base64EncodedString()
    }
}
