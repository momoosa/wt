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
    
    private var liveProgress: Double {
        _ = details.tickCount
        let liveElapsed = details.elapsedTime + Date().timeIntervalSince(details.startDate)
        guard details.unifiedTargetValue > 0 else { return 0 }
        return liveElapsed / details.unifiedTargetValue
    }
    
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
                GaugePlayIcon(imageName: "stop.circle.fill", progress: liveProgress, color: session.theme.color(for: colorScheme))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
            }
        }
        .foregroundStyle(session.theme.color(for: colorScheme))
    }
}

    

