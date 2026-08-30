//
//  RemindersListLinkSheet.swift
//  Momentum
//
//  Sheet for linking a Reminders list to a Goal's checklist.
//

import SwiftUI
import EventKit
import SwiftData
import MomentumKit
import os

struct RemindersListLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let goal: Goal
    let session: GoalSession?
    
    @State private var remindersManager = RemindersManager()
    @State private var calendars: [EKCalendar] = []
    @State private var reminderPreviews: [String: [String]] = [:] // calendarID → first few titles
    @State private var reminderCounts: [String: Int] = [:] // calendarID → count
    @State private var selectedCalendarID: String?
    @State private var isLoading = true
    @State private var isLinking = false
    
    init(goal: Goal, session: GoalSession?) {
        self.goal = goal
        self.session = session
        self._selectedCalendarID = State(initialValue: goal.linkedRemindersListID)
    }
    
    private var selectedCalendar: EKCalendar? {
        guard let id = selectedCalendarID else { return nil }
        return calendars.first { $0.calendarIdentifier == id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checklist.checked")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("Link a Reminders list")
                    .font(.title3.weight(.bold))
                
                Text("Its items become this goal's checklist. Tick things off here or in Reminders — they stay in sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .padding(.horizontal, 16)
            
            // List of calendars
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if calendars.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No Reminders lists found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(calendar)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    linkSelected()
                } label: {
                    if isLinking {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Link \(selectedCalendar?.title ?? "List")")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color(.darkGray), in: RoundedRectangle(cornerRadius: 14))
                .disabled(selectedCalendarID == nil || isLinking)
                .opacity(selectedCalendarID == nil ? 0.5 : 1)
                
                if goal.linkedRemindersListID != nil {
                    Button("Unlink list", role: .destructive) {
                        RemindersSyncService.unlinkList(from: goal, context: context)
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .padding(.top, 12)
        }
        .task {
            await loadCalendars()
        }
    }
    
    // MARK: - Calendar Row
    
    private func calendarRow(_ calendar: EKCalendar) -> some View {
        let id = calendar.calendarIdentifier
        let isSelected = selectedCalendarID == id
        let count = reminderCounts[id] ?? 0
        let previews = reminderPreviews[id] ?? []
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCalendarID = id
            }
        } label: {
            HStack(spacing: 12) {
                // Colored dot
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 0) {
                        Text("\(count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !previews.isEmpty {
                            Text(" · ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(previews.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                } else {
                    Circle()
                        .strokeBorder(Color(.systemGray3), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.3) : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func loadCalendars() async {
        isLoading = true
        defer { isLoading = false }
        
        // Always request access to ensure the event store is connected,
        // even if already authorized — a fresh EKEventStore may return
        // empty calendars until it's been properly initialized.
        _ = try? await remindersManager.requestAccess()
        
        calendars = remindersManager.fetchAllLists().sorted { $0.title < $1.title }
        
        // Fetch preview data for each calendar
        for calendar in calendars {
            let id = calendar.calendarIdentifier
            do {
                let reminders = try await remindersManager.fetchReminders(in: id)
                reminderCounts[id] = reminders.count
                reminderPreviews[id] = Array(
                    reminders.prefix(3).compactMap { $0.title }
                )
            } catch {
                reminderCounts[id] = 0
                reminderPreviews[id] = []
            }
        }
    }
    
    private func linkSelected() {
        guard let calendarID = selectedCalendarID else { return }
        isLinking = true
        
        Task {
            do {
                try await RemindersSyncService.linkList(
                    calendarID: calendarID,
                    to: goal,
                    session: session,
                    context: context
                )
            } catch {
                AppLogger.app.error("Failed to link reminders list: \(error.localizedDescription)")
            }
            isLinking = false
            dismiss()
        }
    }
}

// MARK: - Editor Variant (works with GoalEditorViewModel)

struct RemindersListLinkSheetForEditor: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var vm: GoalEditorViewModel
    
    @State private var remindersManager = RemindersManager()
    @State private var calendars: [EKCalendar] = []
    @State private var reminderPreviews: [String: [String]] = [:]
    @State private var reminderCounts: [String: Int] = [:]
    @State private var selectedCalendarID: String?
    @State private var isLoading = true
    @State private var isLinking = false
    
    init(vm: GoalEditorViewModel) {
        self.vm = vm
        self._selectedCalendarID = State(initialValue: vm.linkedRemindersListID)
    }
    
    private var selectedCalendar: EKCalendar? {
        guard let id = selectedCalendarID else { return nil }
        return calendars.first { $0.calendarIdentifier == id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checklist.checked")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("Link a Reminders list")
                    .font(.title3.weight(.bold))
                
                Text("Its items become this goal's checklist. Tick things off here or in Reminders — they stay in sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .padding(.horizontal, 16)
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if calendars.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No Reminders lists found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(calendar)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    linkSelected()
                } label: {
                    if isLinking {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Link \(selectedCalendar?.title ?? "List")")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color(.darkGray), in: RoundedRectangle(cornerRadius: 14))
                .disabled(selectedCalendarID == nil || isLinking)
                .opacity(selectedCalendarID == nil ? 0.5 : 1)
                
                if vm.linkedRemindersListID != nil {
                    Button("Unlink list", role: .destructive) {
                        vm.linkedRemindersListID = nil
                        // Remove all linked checklist items
                        vm.checklistItems.removeAll { $0.remindersIdentifier != nil }
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .padding(.top, 12)
        }
        .task {
            await loadCalendars()
        }
    }
    
    private func calendarRow(_ calendar: EKCalendar) -> some View {
        let id = calendar.calendarIdentifier
        let isSelected = selectedCalendarID == id
        let count = reminderCounts[id] ?? 0
        let previews = reminderPreviews[id] ?? []
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCalendarID = id
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 0) {
                        Text("\(count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !previews.isEmpty {
                            Text(" · ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(previews.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                } else {
                    Circle()
                        .strokeBorder(Color(.systemGray3), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.3) : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func loadCalendars() async {
        isLoading = true
        defer { isLoading = false }
        
        _ = try? await remindersManager.requestAccess()
        
        calendars = remindersManager.fetchAllLists().sorted { $0.title < $1.title }
        
        for calendar in calendars {
            let id = calendar.calendarIdentifier
            do {
                let reminders = try await remindersManager.fetchReminders(in: id)
                reminderCounts[id] = reminders.count
                reminderPreviews[id] = Array(
                    reminders.prefix(3).compactMap { $0.title }
                )
            } catch {
                reminderCounts[id] = 0
                reminderPreviews[id] = []
            }
        }
    }
    
    private func linkSelected() {
        guard let calendarID = selectedCalendarID else { return }
        isLinking = true
        
        Task {
            _ = try? await remindersManager.requestAccess()
            
            do {
                let reminders = try await remindersManager.fetchReminders(in: calendarID)
                
                // Remove existing linked items from the editor
                vm.checklistItems.removeAll { $0.remindersIdentifier != nil }
                
                // Add reminders as checklist items
                for reminder in reminders {
                    vm.checklistItems.append(ChecklistItemData(
                        title: reminder.title ?? "Untitled",
                        notes: reminder.notes ?? "",
                        remindersIdentifier: reminder.calendarItemIdentifier
                    ))
                }
                
                vm.linkedRemindersListID = calendarID
            } catch {
                AppLogger.app.error("Failed to link reminders list in editor: \(error.localizedDescription)")
            }
            
            isLinking = false
            dismiss()
        }
    }
}
