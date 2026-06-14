//
//  AppPermissionsView.swift
//  Momentum
//
//  Reusable permissions screen for Location, Calendar, and Notifications.
//  Used from Settings and designed for future onboarding flow integration.
//

import SwiftUI
import CoreLocation
import EventKit
import UserNotifications

// MARK: - Permission Types

enum PermissionType: CaseIterable {
    case location
    case calendar
    case notifications
}

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

// MARK: - View Model

@Observable
@MainActor
final class AppPermissionsViewModel {
    var locationStatus: PermissionStatus = .notDetermined
    var calendarStatus: PermissionStatus = .notDetermined
    var notificationStatus: PermissionStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    func refresh() async {
        // Location — synchronous read
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .granted
        case .denied, .restricted:
            locationStatus = .denied
        case .notDetermined:
            locationStatus = .notDetermined
        @unknown default:
            locationStatus = .notDetermined
        }
        
        // Calendar — synchronous class method
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            calendarStatus = .granted
        case .denied, .restricted:
            calendarStatus = .denied
        case .notDetermined, .writeOnly:
            calendarStatus = .notDetermined
        @unknown default:
            calendarStatus = .notDetermined
        }
        
        // Notifications — async
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .granted
        case .denied:
            notificationStatus = .denied
        case .notDetermined:
            notificationStatus = .notDetermined
        @unknown default:
            notificationStatus = .notDetermined
        }
    }
    
    func request(_ type: PermissionType) async {
        switch type {
        case .location:
            locationManager.requestWhenInUseAuthorization()
            // Location authorization is async via delegate; wait briefly then re-read
            try? await Task.sleep(for: .seconds(0.5))
        case .calendar:
            _ = try? await EKEventStore().requestFullAccessToEvents()
        case .notifications:
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
        await refresh()
    }
    
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    /// True if any permission has not been determined yet
    var hasAnyUndetermined: Bool {
        locationStatus == .notDetermined ||
        calendarStatus == .notDetermined ||
        notificationStatus == .notDetermined
    }
    
    /// Quick synchronous check for whether any permission is still undetermined.
    /// Use this to decide whether to show the permissions screen before creating a full view-model.
    static func hasUndeterminedPermissions() async -> Bool {
        let location = CLLocationManager().authorizationStatus == .notDetermined
        let calendar = EKEventStore.authorizationStatus(for: .event) == .notDetermined
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let notifications = settings.authorizationStatus == .notDetermined
        return location || calendar || notifications
    }
    
    func status(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .location: return locationStatus
        case .calendar: return calendarStatus
        case .notifications: return notificationStatus
        }
    }
}

// MARK: - View

struct AppPermissionsView: View {
    /// Pass a closure for onboarding mode (renders a Continue button). Omit for Settings mode.
    var onContinue: (() -> Void)? = nil
    
    @State private var viewModel = AppPermissionsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    private let permissionRows: [(type: PermissionType, icon: String, tint: Color, title: String, reason: String)] = [
        (
            .location,
            "location.fill",
            .blue,
            "Location",
            "Fetches local weather so Momentum can suggest the right goals for conditions outside."
        ),
        (
            .calendar,
            "calendar",
            .red,
            "Calendar",
            "Reads your schedule to find free time and avoid suggesting goals when you're busy."
        ),
        (
            .notifications,
            "bell.fill",
            .orange,
            "Notifications",
            "Sends reminders at your scheduled times to help you stay consistent."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Text("Momentum works best with the following permissions enabled.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                Section {
                    ForEach(permissionRows, id: \.type) { row in
                        PermissionRow(
                            icon: row.icon,
                            iconTint: row.tint,
                            title: row.title,
                            reason: row.reason,
                            status: viewModel.status(for: row.type),
                            onRequest: { Task { await viewModel.request(row.type) } },
                            onOpenSettings: { viewModel.openSystemSettings() }
                        )
                    }
                } footer: {
                    Text("You can change these at any time in iOS Settings.")
                }
            }
            
            if let onContinue {
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let reason: String
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(iconTint, in: RoundedRectangle(cornerRadius: 7))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 8)
            
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            case .notDetermined:
                Button("Enable", action: onRequest)
                    .buttonStyle(.borderedProminent)
                    .tint(iconTint)
                    .controlSize(.small)
            case .denied:
                Button("Settings", action: onOpenSettings)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hashable conformance for PermissionType

extension PermissionType: Hashable {}

// MARK: - Inline Permissions Prompt Card (for day-at-a-glance)

struct PermissionsPromptCard: View {
    @Bindable var viewModel: AppPermissionsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    
    private let cardGradient = LinearGradient(
        colors: [Color.indigo, Color.purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private var foreground: Color { .white }
    
    private var undeterminedPermissions: [(type: PermissionType, icon: String, label: String, detail: String)] {
        var result: [(PermissionType, String, String, String)] = []
        if viewModel.locationStatus == .notDetermined {
            result.append((.location, "location.fill", "Location", "Weather-based suggestions"))
        }
        if viewModel.calendarStatus == .notDetermined {
            result.append((.calendar, "calendar", "Calendar", "Find free time in your day"))
        }
        if viewModel.notificationStatus == .notDetermined {
            result.append((.notifications, "bell.fill", "Notifications", "Scheduled reminders"))
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Get Started")
                    .font(.title2.bold())
                    .foregroundStyle(foreground)
                
                Spacer()
                
                Text("SET UP")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(foreground.opacity(0.15), in: Capsule())
                    .foregroundStyle(foreground.opacity(0.8))
            }
            
            Text("Enable permissions to personalise your schedule")
                .font(.caption)
                .foregroundStyle(foreground.opacity(0.7))
            
            // Permission rows
            ForEach(undeterminedPermissions, id: \.type) { perm in
                Button {
                    Task { await viewModel.request(perm.type) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: perm.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(foreground.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(perm.label)
                                .font(.subheadline.weight(.semibold))
                            Text(perm.detail)
                                .font(.caption2)
                                .foregroundStyle(foreground.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Text("Enable")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(foreground.opacity(0.2), in: Capsule())
                    }
                    .foregroundStyle(foreground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .listRowBackground(
            cardGradient
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        )
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        AppPermissionsView()
    }
}

#Preview("Card") {
    List {
        Section {
            PermissionsPromptCard(viewModel: AppPermissionsViewModel())
                .listRowInsets(EdgeInsets())
        }
        .listSectionSpacing(.compact)
    }
}
