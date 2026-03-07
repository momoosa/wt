//
//  ManualLogSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct ManualLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let session: GoalSession
    let day: Day
    
    @State private var startDate = Date()
    @State private var duration: TimeInterval = 1800 // Default 30 minutes
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start Time", selection: $startDate, in: day.startDate...day.endDate)
                    
                    Picker("Duration", selection: $duration) {
                        Text("5 min").tag(TimeInterval(300))
                        Text("10 min").tag(TimeInterval(600))
                        Text("15 min").tag(TimeInterval(900))
                        Text("20 min").tag(TimeInterval(1200))
                        Text("30 min").tag(TimeInterval(1800))
                        Text("45 min").tag(TimeInterval(2700))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                    }
                } header: {
                    Text("Activity Details")
                } footer: {
                    Text("Log time you spent on this goal that wasn't captured by HealthKit")
                }
                
                Section("Notes (Optional)") {
                    TextField("Add any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log \(session.goal?.title ?? "Goal")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveManualLog()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveManualLog() {
        // Create a historical session for this manual entry
        let endDate = startDate.addingTimeInterval(duration)
        
        let historicalSession = HistoricalSession(
            id: UUID().uuidString,
            title: "\(session.goal?.title ?? "Goal") - Manual Entry",
            start: startDate,
            end: endDate,
            healthKitType: nil, // Manual entry, not from HealthKit
            needsHealthKitRecord: false,
            notes: notes.isEmpty ? nil : notes
        )
        if let goalID = session.goal?.id.uuidString {
            historicalSession.goalIDs.append(goalID)
        }
        
        // Add to day
        day.add(historicalSession: historicalSession)
        modelContext.insert(historicalSession)
        
        // Save context
        try? modelContext.save()
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
