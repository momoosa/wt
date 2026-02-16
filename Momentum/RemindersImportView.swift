//
//  RemindersImportView.swift
//  Momentum
//
//  Created by Assistant on 15/02/2026.
//

import SwiftUI
import EventKit
import MomentumKit
import SwiftData

struct RemindersImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    
    @State private var remindersManager = RemindersManager()
    @State private var reminders: [EKReminder] = []
    @State private var selectedReminders: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                if !remindersManager.isAuthorized {
                    permissionView
                } else if isLoading {
                    ProgressView("Loading reminders...")
                } else if reminders.isEmpty {
                    emptyStateView
                } else {
                    remindersList
                }
            }
            .navigationTitle("Import Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if !reminders.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Import") {
                            importSelectedReminders()
                        }
                        .disabled(selectedReminders.isEmpty)
                    }
                }
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Cannot access Reminders")
            }
            .task {
                if remindersManager.isAuthorized {
                    await loadReminders()
                }
            }
        }
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Access Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Momentum can import your reminders to help you quickly create time-tracked goals.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button {
                Task {
                    await requestPermission()
                }
            } label: {
                Text("Allow Access")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Incomplete Reminders", systemImage: "checklist")
        } description: {
            Text("You don't have any incomplete reminders to import.")
        }
    }
    
    private var remindersList: some View {
        List(reminders, id: \.calendarItemIdentifier, selection: $selectedReminders) { reminder in
            ReminderRow(reminder: reminder)
        }
        .environment(\.editMode, .constant(.active))
    }
    
    private func requestPermission() async {
        do {
            let granted = try await remindersManager.requestAccess()
            if granted {
                await loadReminders()
            } else {
                errorMessage = "Reminders access was denied. Please enable it in Settings."
                showingPermissionAlert = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showingPermissionAlert = true
        }
    }
    
    private func loadReminders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            reminders = try await remindersManager.fetchIncompleteReminders()
            // Sort by due date (reminders with due dates first)
            reminders.sort { reminder1, reminder2 in
                let date1 = reminder1.dueDateComponents?.date ?? Date.distantFuture
                let date2 = reminder2.dueDateComponents?.date ?? Date.distantFuture
                return date1 < date2
            }
        } catch {
            errorMessage = error.localizedDescription
            showingPermissionAlert = true
        }
    }
    
    private func importSelectedReminders() {
        let selectedReminderObjects = reminders.filter {
            selectedReminders.contains($0.calendarItemIdentifier)
        }
        
        let _ = remindersManager.importReminders(
            selectedReminderObjects,
            context: context,
            goalStore: goalStore
        )
        
        // Show success feedback and dismiss
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        dismiss()
    }
}

struct ReminderRow: View {
    let reminder: EKReminder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reminder.title ?? "Untitled")
                .font(.body)
            
            if let dueDate = reminder.dueDateComponents?.date {
                Text("Due: \(dueDate, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let notes = reminder.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RemindersImportView()
        .environment(GoalStore())
}
