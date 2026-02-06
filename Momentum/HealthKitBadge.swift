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
    
    var body: some View {
        if isEnabled, let metric {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Image(systemName: metric.symbolName)
                    .font(.caption2)
            }
            .foregroundStyle(.red)
            .padding(4)
            .background(
                Capsule()
                    .fill(.red.opacity(0.15))
            )
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        HealthKitBadge(metric: .appleExerciseTime, isEnabled: true)
        HealthKitBadge(metric: .mindfulMinutes, isEnabled: true)
        HealthKitBadge(metric: nil, isEnabled: false)
    }
    .padding()
}
