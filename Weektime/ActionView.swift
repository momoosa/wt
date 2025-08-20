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
    @Bindable var details: ActiveSessionDetails
    let eventHandler: (Event) -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                if let timeText = details.timeText {
                    Text(timeText)
                        .font(.caption)
                        .contentTransition(.numericText())
                }
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
}

    

