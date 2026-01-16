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
//            if let imageName = goal.imageName {
//                        Image(systemName: imageName)
//                            .symbolRenderingMode(.hierarchical)
//                            .foregroundStyle(color.primary) // TODO: Make a view
//                            .frame(width: 30, height: 30)
//                            .background(GoalIcon(color: color.secondary))
//
//                    }
            VStack(alignment: .leading) {
                HStack {
                    if showsTimeSummaryInsteadOfTitle {
                        Text("\(Duration.seconds(session.endDate.timeIntervalSince(session.startDate)).formatted())")
                    } else {
                        Text(session.title)
                    }
                    Spacer()
                }
                Text("\(session.startDate.formatted(.dateTime.hour().minute().second())) - \(session.endDate.formatted(.dateTime.hour().minute().second()))")
                    .font(.footnote)
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
