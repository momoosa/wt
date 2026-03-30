//
//  TimeTrackingSettingsView.swift
//  Momentum
//
//  Created by Assistant on 30/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct TimeTrackingSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [Goal]
    @State private var serviceManager = TimeTrackingServiceManager()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var showingProjectMapping = false
    @State private var availableProjects: [TimeTrackingProject] = []
    @State private var isSyncing = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Time Tracking Integration", isOn: Binding(
                    get: { serviceManager.config.isEnabled },
                    set: { newValue in
                        var config = serviceManager.config
                        config.isEnabled = newValue
                        serviceManager.updateConfig(config)
                    }
                ))
            } footer: {
                Text("Automatically sync your completed goal sessions to Toggl Track.")
            }

            if serviceManager.config.isEnabled {
                Section {
                    if !(serviceManager.activeService?.isAuthenticated ?? false) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)

                        Button {
                            authenticateService()
                        } label: {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || isAuthenticating)

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

                        Button("Sign Out", role: .destructive) {
                            serviceManager.activeService?.logout()
                            email = ""
                            password = ""
                            // Credentials are now removed from Keychain by the service
                        }
                    }
                } header: {
                    Text("Toggl Track Account")
                } footer: {
                    Text("Sign in with your Toggl Track email and password")
                }

                if serviceManager.activeService?.isAuthenticated ?? false {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pending Sessions")
                                    .font(.headline)
                                if serviceManager.pendingSessionCount == 0 {
                                    Text("All synced ✓")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("\(serviceManager.pendingSessionCount) session\(serviceManager.pendingSessionCount == 1 ? "" : "s") queued")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Button {
                                    Task {
                                        await syncPendingSessions()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Sync Now")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .disabled(serviceManager.pendingSessionCount == 0)
                            }
                        }
                    } header: {
                        Text("Sync Status")
                    } footer: {
                        Text("Sessions are automatically batched and synced every 5 minutes (5 at a time with 2s delays) to respect Toggl's rate limits. New sessions are queued, never sent immediately.")
                    }
                    
                    Section {
                        NavigationLink {
                            TogglProjectImportView(serviceManager: serviceManager)
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundStyle(.blue)
                                Text("Import Projects as Goals")
                            }
                        }
                        
                        NavigationLink {
                            TogglTimeSyncView(serviceManager: serviceManager)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.green)
                                Text("Sync Time Entries")
                            }
                        }
                    } header: {
                        Text("Import")
                    } footer: {
                        Text("Import projects as goals and sync your historical time entries")
                    }
                    
                    Section {
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
                    } header: {
                        Text("Project Mapping")
                    } footer: {
                        Text("Optionally map your goals to specific Toggl Track projects")
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
                // Combine email and password for the authenticate method
                let credentials = "\(email):\(password)"
                try await serviceManager.activeService?.authenticate(apiKey: credentials)

                // Credentials are now saved to Keychain by the service
                // No need to save to config anymore

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
    
    private func syncPendingSessions() async {
        isSyncing = true
        let result = await serviceManager.syncPendingSessionsNow(goals: allGoals)
        isSyncing = false
        print("Synced \(result.synced) sessions, \(result.failed) failed")
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

// MARK: - Toggl Project Import View

struct TogglProjectImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var serviceManager: TimeTrackingServiceManager
    @State private var projects: [TimeTrackingProject] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProjects: Set<String> = []
    @State private var isImporting = false
    @State private var importedCount = 0
    @State private var showingSuccess = false
    
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
            } else if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects Found",
                    systemImage: "folder",
                    description: Text("Create projects in Toggl Track first")
                )
            } else {
                List {
                    Section {
                        ForEach(projects) { project in
                            Button {
                                toggleSelection(project.id)
                            } label: {
                                HStack {
                                    if let color = project.color {
                                        Circle()
                                            .fill(Color(hex: color) ?? .gray)
                                            .frame(width: 12, height: 12)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name)
                                            .foregroundStyle(.primary)
                                        if let client = project.clientName {
                                            Text(client)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedProjects.contains(project.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Select projects to import")
                    } footer: {
                        Text("Each project will be created as a new goal with a 5 hour weekly target")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            importProjects()
                        } label: {
                            if isImporting {
                                ProgressView()
                            } else {
                                Text("Import (\(selectedProjects.count))")
                            }
                        }
                        .disabled(selectedProjects.isEmpty || isImporting)
                    }
                }
            }
        }
        .navigationTitle("Import Projects")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProjects()
        }
        .alert("Projects Imported", isPresented: $showingSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Successfully imported \(importedCount) project\(importedCount == 1 ? "" : "s") as goals")
        }
    }
    
    private func toggleSelection(_ projectId: String) {
        if selectedProjects.contains(projectId) {
            selectedProjects.remove(projectId)
        } else {
            selectedProjects.insert(projectId)
        }
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
    
    private func importProjects() {
        isImporting = true
        importedCount = 0
        
        let selectedProjectsList = projects.filter { selectedProjects.contains($0.id) }
        
        for project in selectedProjectsList {
            // Create a goal tag from the project color
            let tagColor = project.color.flatMap { Color(hex: $0) } ?? .blue
            let theme = findMatchingTheme(for: tagColor)
            let tag = GoalTag(title: project.clientName ?? "Toggl", themeID: theme.id)
            
            // Create the goal
            let goal = Goal(
                title: project.name,
                primaryTag: tag,
                weeklyTarget: TimeInterval(5 * 60 * 60), // 5 hours default
                notificationsEnabled: false,
                scheduleNotificationsEnabled: false,
                completionNotificationsEnabled: false
            )
            
            modelContext.insert(goal)
            
            // Auto-map this goal to the project
            serviceManager.mapGoal(goal, toProjectID: project.id)
            
            importedCount += 1
        }
        
        // Save the context
        try? modelContext.save()
        
        isImporting = false
        showingSuccess = true
    }
    
    private func findMatchingTheme(for color: Color) -> ThemePreset {
        // Try to match the Toggl project color to a theme
        // For now, just cycle through themes
        let index = projects.firstIndex { selectedProjects.contains($0.id) } ?? 0
        return themePresets[index % themePresets.count]
    }
}

// MARK: - Toggl Time Sync View

struct TogglTimeSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allGoals: [Goal]
    @State var serviceManager: TimeTrackingServiceManager
    @State private var selectedDays: Int = 7
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var syncedCount = 0
    @State private var showingSuccess = false
    
    private let dayOptions = [7, 14, 30, 90]
    
    var body: some View {
        Form {
            Section {
                Picker("Time Period", selection: $selectedDays) {
                    ForEach(dayOptions, id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Sync Period")
            } footer: {
                Text("Import time entries from the last \(selectedDays) days")
            }
            
            Section {
                if let mappedGoals = getMappedGoals(), !mappedGoals.isEmpty {
                    ForEach(mappedGoals, id: \.id) { goal in
                        HStack {
                            Circle()
                                .fill(goal.primaryTag?.theme.light ?? .gray)
                                .frame(width: 10, height: 10)
                            Text(goal.title)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Mapped Goals",
                        systemImage: "link.badge.plus",
                        description: Text("Map your goals to Toggl projects first")
                    )
                }
            } header: {
                Text("Goals to Sync")
            } footer: {
                Text("Only goals mapped to projects will sync time entries")
            }
            
            if let error = syncError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button {
                    syncTimeEntries()
                } label: {
                    HStack {
                        Spacer()
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Syncing...")
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Time Entries")
                        }
                        Spacer()
                    }
                }
                .disabled(isSyncing || getMappedGoals()?.isEmpty != false)
            } footer: {
                Text("Time entries will be imported as historical sessions for the mapped goals")
            }
        }
        .navigationTitle("Sync Time Entries")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sync Complete", isPresented: $showingSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Successfully synced \(syncedCount) time \(syncedCount == 1 ? "entry" : "entries")")
        }
    }
    
    private func getMappedGoals() -> [Goal]? {
        let mappedGoalIDs = Set(serviceManager.config.projectMappings.keys)
        return allGoals.filter { mappedGoalIDs.contains($0.id.uuidString) }
    }
    
    private func syncTimeEntries() {
        isSyncing = true
        syncError = nil
        
        Task {
            do {
                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .day, value: -selectedDays, to: endDate)!
                
                // Fetch all days in the date range
                let calendar = Calendar.current
                let descriptor = FetchDescriptor<Day>(
                    predicate: #Predicate<Day> { day in
                        day.startDate >= startDate && day.startDate <= endDate
                    }
                )
                let days = try modelContext.fetch(descriptor)
                
                syncedCount = try await serviceManager.syncTimeEntries(
                    goals: allGoals,
                    days: days,
                    startDate: startDate,
                    endDate: endDate,
                    modelContext: modelContext
                )
                
                await MainActor.run {
                    isSyncing = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncError = error.localizedDescription
                }
            }
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
