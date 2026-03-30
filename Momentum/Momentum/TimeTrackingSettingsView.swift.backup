//
//  TimeTrackingSettingsView.swift
//  Momentum
//
//  Created by Assistant on 30/03/2026.
//

import SwiftUI
import MomentumKit

struct TimeTrackingSettingsView: View {
    @State private var serviceManager = TimeTrackingServiceManager()
    @State private var apiKey: String = ""
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var showingProjectMapping = false
    @State private var availableProjects: [TimeTrackingProject] = []

    var body: some View {
        Form {
            Section {
                Toggle("Enable Time Tracking Integration", isOn: $serviceManager.config.isEnabled)
                    .onChange(of: serviceManager.config.isEnabled) { _, newValue in
                        var config = serviceManager.config
                        config.isEnabled = newValue
                        serviceManager.updateConfig(config)
                    }
            } footer: {
                Text("Automatically sync your completed goal sessions to external time tracking services.")
            }

            if serviceManager.config.isEnabled {
                Section("Service") {
                    Picker("Service Provider", selection: $serviceManager.config.serviceType) {
                        ForEach(TimeTrackingServiceConfig.ServiceType.allCases, id: \.id) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: serviceManager.config.serviceType) { _, newValue in
                        var config = serviceManager.config
                        config.serviceType = newValue
                        serviceManager.updateConfig(config)
                    }
                }

                Section("Authentication") {
                    if !serviceManager.activeService?.isAuthenticated ?? true {
                        SecureField("API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()

                        Button {
                            authenticateService()
                        } label: {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Connect")
                            }
                        }
                        .disabled(apiKey.isEmpty || isAuthenticating)

                        if let error = authError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected")
                        }

                        Button("Disconnect", role: .destructive) {
                            serviceManager.activeService?.logout()
                            apiKey = ""
                            var config = serviceManager.config
                            config.apiKey = nil
                            serviceManager.updateConfig(config)
                        }
                    }
                } footer: {
                    Text("Get your API key from \(serviceManager.config.serviceType.rawValue) settings")
                }

                if serviceManager.activeService?.isAuthenticated ?? false {
                    Section("Project Mapping") {
                        NavigationLink {
                            ProjectMappingView(serviceManager: serviceManager)
                        } label: {
                            HStack {
                                Text("Map Goals to Projects")
                                Spacer()
                                Text("\(serviceManager.config.projectMappings.count) mapped")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    } footer: {
                        Text("Optionally map your goals to specific projects in \(serviceManager.config.serviceType.rawValue)")
                    }
                }
            }
        }
        .navigationTitle("Time Tracking")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authenticateService() {
        isAuthenticating = true
        authError = nil

        Task {
            do {
                try await serviceManager.activeService?.authenticate(apiKey: apiKey)

                // Save API key on success
                var config = serviceManager.config
                config.apiKey = apiKey
                serviceManager.updateConfig(config)

                await MainActor.run {
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Project Mapping View

struct ProjectMappingView: View {
    @State var serviceManager: TimeTrackingServiceManager
    @Query private var allGoals: [Goal]
    @State private var projects: [TimeTrackingProject] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading projects...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Failed to Load Projects",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                List {
                    ForEach(allGoals.filter { $0.status == .active }) { goal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(goal.title)
                                .font(.headline)

                            Picker("Project", selection: binding(for: goal)) {
                                Text("No Project").tag(nil as String?)
                                ForEach(projects) { project in
                                    HStack {
                                        if let color = project.color {
                                            Circle()
                                                .fill(Color(hex: color) ?? .gray)
                                                .frame(width: 10, height: 10)
                                        }
                                        Text(project.name)
                                        if let client = project.clientName {
                                            Text("· \(client)")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .tag(project.id as String?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Map to Projects")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProjects()
        }
    }

    private func binding(for goal: Goal) -> Binding<String?> {
        Binding(
            get: {
                serviceManager.config.projectMappings[goal.id.uuidString]
            },
            set: { newValue in
                if let newValue {
                    serviceManager.mapGoal(goal, toProjectID: newValue)
                } else {
                    var config = serviceManager.config
                    config.projectMappings.removeValue(forKey: goal.id.uuidString)
                    serviceManager.updateConfig(config)
                }
            }
        )
    }

    private func loadProjects() async {
        do {
            projects = try await serviceManager.fetchProjects()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Color Extension for Hex

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    NavigationStack {
        TimeTrackingSettingsView()
    }
}
