//
//  CalendarSettingsView.swift
//  Momentum
//
//  Created by Assistant on 20/03/2026.
//

import SwiftUI

struct CalendarSettingsView: View {
    @StateObject private var permissionsHandler = PermissionsHandler()
    @State private var isRequestingPermission = false
    @State private var showingAvailabilitySummary = false
    @State private var availabilitySummary = ""
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule Flexibility")
                        .font(.headline)
                    
                    Text("Enable calendar integration to get smarter goal recommendations. When your scheduled days are busy, we'll suggest working on those goals on other days with more free time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                HStack {
                    Image(systemName: permissionsHandler.calendarAccessGranted ? "checkmark.circle.fill" : "calendar")
                        .foregroundStyle(permissionsHandler.calendarAccessGranted ? .green : .secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calendar Access")
                            .font(.body)
                        
                        Text(permissionsHandler.calendarAccessGranted ? "Enabled" : "Not enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !permissionsHandler.calendarAccessGranted {
                        Button("Enable") {
                            Task {
                                isRequestingPermission = true
                                await permissionsHandler.requestCalendarAccess()
                                isRequestingPermission = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRequestingPermission)
                    }
                }
            } header: {
                Text("Permissions")
            } footer: {
                if permissionsHandler.calendarAccessGranted {
                    Text("Momentum can see when you're busy and suggest goals at better times.")
                } else {
                    Text("Grant access to enable smart scheduling based on your availability.")
                }
            }
            
            if permissionsHandler.calendarAccessGranted {
                Section {
                    Button {
                        Task {
                            await loadAvailabilitySummary()
                            showingAvailabilitySummary = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("View This Week's Availability")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Availability")
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "calendar.badge.exclamationmark",
                        title: "Busy Weekend Detection",
                        description: "If your weekend goal has a busy weekend, we'll suggest doing it earlier in the week"
                    )
                    
                    Divider()
                    
                    FeatureRow(
                        icon: "clock.arrow.2.circlepath",
                        title: "Flexible Scheduling",
                        description: "Goals adapt to your real calendar, not just fixed weekly schedules"
                    )
                    
                    Divider()
                    
                    FeatureRow(
                        icon: "sparkles",
                        title: "Smart Recommendations",
                        description: "Get goal suggestions when you actually have time to work on them"
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("How It Works")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                        Text("Your calendar data stays private")
                            .font(.subheadline)
                    }
                    
                    Text("• Only used locally on your device\n• Never sent to servers\n• You can revoke access anytime in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Privacy")
            }
        }
        .navigationTitle("Calendar Integration")
        .sheet(isPresented: $showingAvailabilitySummary) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("This Week's Availability")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        Text(availabilitySummary)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        
                        Text("This shows how much free time you have each day after accounting for calendar events.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Availability")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingAvailabilitySummary = false
                        }
                    }
                }
            }
        }
        .onAppear {
            _ = permissionsHandler.checkCalendarAccess()
        }
    }
    
    private func loadAvailabilitySummary() async {
        let manager = permissionsHandler.getCalendarManager()
        let availability = await manager.calculateWeeklyAvailability()
        availabilitySummary = manager.availabilitySummary(availability)
    }
}

struct FeatureRow: View {
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
        CalendarSettingsView()
    }
}
