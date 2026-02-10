//
//  HistoricalSessionRow.swift
//  MomentumKit
//
//  Created by Mo Moosa on 20/08/2025.
//
import SwiftUI

public struct HistoricalSessionRow: View {
    let session: HistoricalSession
    let showsTimeSummaryInsteadOfTitle: Bool
    let allSessions: [HistoricalSession]
    let goalTitle: String?
    
    private var hasOverlap: Bool {
        allSessions.contains { otherSession in
            // Don't compare session with itself
            guard otherSession.id != session.id else { return false }
            
            // Check if time ranges overlap
            return session.startDate < otherSession.endDate && otherSession.startDate < session.endDate
        }
    }
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if showsTimeSummaryInsteadOfTitle {
                        Text("\(Duration.seconds(session.endDate.timeIntervalSince(session.startDate)).formatted())")
                    } else {
                        // Show goal title if available
                        if let goalTitle = goalTitle {
                            Text(goalTitle)
                                .fontWeight(.semibold)
                        } else {
                            Text(session.title)
                        }
                    }
                    
                    // Show HealthKit badge if this is from HealthKit
                    if session.healthKitType != nil {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    
                    // Show overlap indicator
                    if hasOverlap {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    // Show duration
                    Text(Duration.seconds(session.endDate.timeIntervalSince(session.startDate)).formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Show time range
                    Text("\(session.startDate.formatted(.dateTime.hour().minute().second())) - \(session.endDate.formatted(.dateTime.hour().minute().second()))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    public init(session: HistoricalSession, showsTimeSummaryInsteadOfTitle: Bool = false, allSessions: [HistoricalSession] = [], goalTitle: String? = nil) {
        self.session = session
        self.showsTimeSummaryInsteadOfTitle = showsTimeSummaryInsteadOfTitle
        self.allSessions = allSessions
        self.goalTitle = goalTitle
    }
}

#Preview {
    HistoricalSessionRow(session: HistoricalSession(title: "Test", start: .now, end: .now.addingTimeInterval(300), needsHealthKitRecord: false))
}
