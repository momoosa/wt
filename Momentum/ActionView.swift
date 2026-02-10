//
//  ActionView.swift
//  Momentum
//
//  Created by Mo Moosa on 19/08/2025.
//


import SwiftUI
import MomentumKit

struct ActionView: View {
    enum Event {
        case stopTapped
    }
    @Environment(\.colorScheme) var colorScheme
    let session: GoalSession
    @Bindable var details: ActiveSessionDetails
    let eventHandler: (Event) -> Void
    var body: some View {
        HStack {
            Spacer()
                .frame(width: 8)
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
                GaugePlayIcon(isActive: true, imageName: "stop.circle.fill", progress: session.progress, color: session.goal.primaryTag.themePreset.color(for: colorScheme) ?? .gray, font: .title2, gaugeScale: 0.5)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
            }
        }
        .foregroundStyle(session.goal.primaryTag.theme.dark ?? .gray)
    }
}

    

