//
//  HealthKitBadge.swift
//  Momentum
//
//  Created by Mo Moosa on 16/01/2026.
//

import SwiftUI
import MomentumKit

struct HealthKitBadge: View {
    let metric: HealthKitMetric?
    let isEnabled: Bool
    let color: Color
    var body: some View {
        if isEnabled, let metric {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Image(systemName: metric.symbolName)
                    .font(.caption2)
            }
            .foregroundStyle(color)
            .padding(4)
            .background(
                Capsule()
                    .fill(color.opacity(0.3))
            )
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        HealthKitBadge(metric: .appleExerciseTime, isEnabled: true, color: .red)
        HealthKitBadge(metric: .mindfulMinutes, isEnabled: true, color: .blue)
        HealthKitBadge(metric: nil, isEnabled: false, color: .white)
            .background(.red)
    }
    .padding()
}
