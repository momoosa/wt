//
//  HistoricalSessionEditorView.swift
//  Momentum
//
//  Created by Claude on 09/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct HistoricalSessionEditorView: View {
    @Bindable var session: HistoricalSession
    let goalSession: GoalSession?
    let day: Day?
    let isNewSession: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String
    
    init(session: HistoricalSession, goalSession: GoalSession? = nil, day: Day? = nil, isNewSession: Bool = false) {
        self.session = session
        self.goalSession = goalSession
        self.day = day
        self.isNewSession = isNewSession
        _startDate = State(initialValue: session.startDate)
        _endDate = State(initialValue: session.endDate)
        _notes = State(initialValue: session.notes ?? "")
    }
    
    private var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    private var isValid: Bool {
        // End date must be after start date
        endDate > startDate
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(isNewSession ? "Add a manual session entry" : "Edit the time range for this session")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Time Range") {
                    DatePicker("Start Time", selection: $startDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("End Time", selection: $endDate, in: startDate...Date(), displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Duration")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(duration.formatted(style: .components))
                            .fontWeight(.medium)
                    }
                }
                
                Section("Notes") {
                    TextField("Add notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if !isValid {
                    Section {
                        Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isNewSession ? "New Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveChanges() {
        session.startDate = startDate
        session.endDate = endDate
        session.notes = notes.isEmpty ? nil : notes
        
        if isNewSession {
            // Insert the new session into the context
            modelContext.insert(session)
            
            // Associate with goal session
            if let goalSession = goalSession {
                session.goalIDs = [goalSession.goalID]
            }
            
            // Add to day
            if let day = day {
                day.add(historicalSession: session)
            }
        }
        
        try? modelContext.save()
        
        HapticFeedbackManager.trigger(.success)
    }
}

#Preview {
    HistoricalSessionEditorView(
        session: HistoricalSession(
            title: "Test Session",
            start: Date().addingTimeInterval(-3600),
            end: Date(),
            needsHealthKitRecord: false
        )
    )
}
