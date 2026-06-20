//
//  RemindersTab.swift
//  Momentum
//
//  Created by Mo Moosa on 06/04/2026.
//

import SwiftUI
import MomentumKit
import EventKit

struct RemindersTab: View {
    let isSelected: Bool
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.body.weight(.medium))
            Text("Reminders")
                .font(.subheadline.weight(.medium))
            if !isSubscribed {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(isSelected ? Color.teal : Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.teal : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

struct RemindersTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    
    @Binding var userInput: String
    let onReminderSelected: (EKReminder) -> Void
    @Binding var showingPremiumPaywall: Bool
    
    @State private var remindersManager = RemindersManager()
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPermissionAlert = false
    
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }
    
    var body: some View {
        Group {
            if !isSubscribed {
                premiumUpsellView
            } else if !remindersManager.isAuthorized {
                permissionView
            } else if isLoading {
                ProgressView("Loading reminders...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reminders.isEmpty {
                emptyStateView
            } else {
                remindersList
            }
        }
        .task {
            if isSubscribed && remindersManager.isAuthorized {
                await loadReminders()
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Cannot access Reminders")
        }
    }
    
    private var premiumUpsellView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.teal)
            
            Text("Import from Reminders")
                .font(.headline)
            
            Text("Turn your reminders into time-tracked goals with schedules, checklists, and progress tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingPremiumPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text("Unlock with Pro")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
        }
        .padding()
    }
    
    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Access Reminders")
                .font(.headline)
            
            Text("Import your reminders as time-tracked goals")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Allow Access") {
                Task {
                    await requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Reminders")
                .font(.headline)
            
            Text("You don't have any incomplete reminders")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var remindersList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                    Button {
                        importReminder(reminder)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle")
                                .font(.body)
                                .foregroundStyle(.teal)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title ?? "Untitled")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
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
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private func requestPermission() async {
        do {
            let granted = try await remindersManager.requestAccess()
            if granted {
                await loadReminders()
            } else {
                errorMessage = "Reminders access was denied"
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
    
    private func importReminder(_ reminder: EKReminder) {
        // Create the goal
        let _ = remindersManager.createGoal(from: reminder, context: context, goalStore: goalStore)
        
        // Fill in the text field with reminder title
        onReminderSelected(reminder)
        
        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
