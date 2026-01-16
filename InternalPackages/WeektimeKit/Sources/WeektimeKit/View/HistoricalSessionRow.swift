//
//  HistoricalSessionRow.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 20/08/2025.
//
import SwiftUI

public struct HistoricalSessionRow: View {
    let session: HistoricalSession
    let showsTimeSummaryInsteadOfTitle: Bool
    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if showsTimeSummaryInsteadOfTitle {
                        Text("\(Duration.seconds(session.endDate.timeIntervalSince(session.startDate)).formatted())")
                    } else {
                        Text(session.title)
                    }
                    
                    // Show HealthKit badge if this is from HealthKit
                    if session.healthKitType != nil {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                }
                Text("\(session.startDate.formatted(.dateTime.hour().minute().second())) - \(session.endDate.formatted(.dateTime.hour().minute().second()))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    public init(session: HistoricalSession, showsTimeSummaryInsteadOfTitle: Bool = false) {
        self.session = session
        self.showsTimeSummaryInsteadOfTitle = showsTimeSummaryInsteadOfTitle
    }
}

#Preview {
    HistoricalSessionRow(session: HistoricalSession(title: "Test", start: .now, end: .now.addingTimeInterval(300), needsHealthKitRecord: false))
}
