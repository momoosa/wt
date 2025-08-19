//
//  ActionView.swift
//  Weektime
//
//  Created by Mo Moosa on 19/08/2025.
//


import SwiftUI
import WeektimeKit

struct ActionView: View {
    enum Event {
        case stopTapped
    }
    let session: GoalSession
    @Binding var activeSessionID: UUID?
    @Binding var activeSessionStartDate: Date?
    @Binding var activeSessionElapsedTime: TimeInterval
    @Binding var currentTime: Date
    let eventHandler: (Event) -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(timerText(for: session))
                    .font(.caption)
            }
            Button {
                eventHandler(.stopTapped)
            } label: {
                Image(systemName: "stop.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .foregroundStyle(session.goal.primaryTheme.theme.dark)
    }
    
    private func timerText(for session: GoalSession) -> String {
        let elapsed: TimeInterval
        if activeSessionID == session.id, let startDate = activeSessionStartDate {
            elapsed = activeSessionElapsedTime + currentTime.timeIntervalSince(startDate)
        } else {
            elapsed = 0
        }
        return Duration.seconds(elapsed).formatted()
    }
}

    

