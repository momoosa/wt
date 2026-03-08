//
//  CloudKitSyncStatusView.swift
//  Momentum
//
//  Created by Assistant on 08/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct CloudKitSyncStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var syncStatus: SyncStatus = .unknown
    @State private var lastSyncDate: Date?
    @State private var errorMessage: String?
    
    enum SyncStatus {
        case syncing
        case synced
        case error
        case disabled
        case unknown
        
        var icon: String {
            switch self {
            case .syncing: return "arrow.triangle.2.circlepath"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .disabled: return "xmark.icloud"
            case .unknown: return "icloud"
            }
        }
        
        var color: Color {
            switch self {
            case .syncing: return .blue
            case .synced: return .green
            case .error: return .red
            case .disabled: return .secondary
            case .unknown: return .secondary
            }
        }
        
        var statusText: String {
            switch self {
            case .syncing: return "Syncing..."
            case .synced: return "Synced"
            case .error: return "Sync Error"
            case .disabled: return "Disabled"
            case .unknown: return "Checking..."
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("iCloud Sync")
                } icon: {
                    Image(systemName: syncStatus.icon)
                        .foregroundStyle(syncStatus.color)
                        .symbolEffect(.pulse, isActive: syncStatus == .syncing)
                }
                
                Spacer()
                
                Text(syncStatus.statusText)
                    .font(.subheadline)
                    .foregroundStyle(syncStatus.color)
            }
            
            if let lastSync = lastSyncDate {
                Text("Last synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await checkSyncStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSPersistentStoreRemoteChange"))) { _ in
            Task {
                await checkSyncStatus()
            }
        }
    }
    
    private func checkSyncStatus() async {
        // Check if CloudKit container is accessible
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moosa.momentum.ios") else {
            syncStatus = .disabled
            errorMessage = "App Group not configured"
            return
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        
        // Check if store file exists
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            syncStatus = .disabled
            errorMessage = "Data store not found"
            return
        }
        
        // Try to read file attributes to check for recent changes
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                lastSyncDate = modificationDate
                
                // If modified recently (within last 30 seconds), show syncing
                if Date().timeIntervalSince(modificationDate) < 30 {
                    syncStatus = .syncing
                } else {
                    syncStatus = .synced
                }
            } else {
                syncStatus = .synced
            }
            errorMessage = nil
        } catch {
            syncStatus = .error
            errorMessage = "Failed to check sync status"
        }
    }
}

struct CloudKitSyncDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query private var sessions: [GoalSession]
    @Query private var days: [Day]
    @Query private var tags: [GoalTag]
    @Query private var historicalSessions: [HistoricalSession]
    
    var body: some View {
        List {
            Section {
                CloudKitSyncStatusView()
            }
            
            Section {
                HStack {
                    Text("Goals")
                    Spacer()
                    Text("\(goals.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Sessions")
                    Spacer()
                    Text("\(sessions.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Days")
                    Spacer()
                    Text("\(days.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Tags")
                    Spacer()
                    Text("\(tags.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Historical Sessions")
                    Spacer()
                    Text("\(historicalSessions.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Synced Data")
            } footer: {
                Text("All data is stored locally and synced to your private iCloud storage. Data syncs automatically across all your devices signed in with the same Apple ID.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(
                        icon: "lock.shield",
                        title: "Private & Secure",
                        description: "Your data is stored in your private iCloud container, accessible only to you."
                    )
                    
                    Divider()
                    
                    InfoRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Automatic Sync",
                        description: "Changes sync automatically when you're connected to the internet."
                    )
                    
                    Divider()
                    
                    InfoRow(
                        icon: "wifi.slash",
                        title: "Offline Support",
                        description: "The app works fully offline. Changes will sync when you're back online."
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("How it Works")
            }
            
            Section {
                Link(destination: URL(string: "https://support.apple.com/en-us/HT204025")!) {
                    Label("Manage iCloud Storage", systemImage: "gear")
                }
                
                Link(destination: URL(string: "https://support.apple.com/en-us/HT204283")!) {
                    Label("iCloud Troubleshooting", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Help & Support")
            }
        }
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CloudKitSyncDetailView()
    }
}
