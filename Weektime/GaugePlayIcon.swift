//
//  GaugePlayIcon.swift
//  Weektime
//
//  Created by Mo Moosa on 06/11/2025.
//

import SwiftUI

public struct GaugePlayIcon: View {
    public let isActive: Bool
    public let imageName: String
    public let progress: Double
    public let color: Color
    public let font: Font
    public let gaugeScale: Double
    public var body: some View {
        Image(systemName: imageName)
            .contentTransition(.symbolEffect(.replace))
            .font(font)
            .background {
                if isActive {
                 
                    Gauge(value: progress) {
                        
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .scaleEffect(gaugeScale)
                    .transition(.scale.combined(with: .blurReplace))
                    .tint(color)
                }
            }
    }
    
    public init(isActive: Bool, imageName: String, progress: Double, color: Color, font: Font = .title2, gaugeScale: Double = 0.4) {
        self.isActive = isActive
        self.imageName = imageName
        self.progress = progress
        self.color = color
        self.font = font
        self.gaugeScale = gaugeScale
    }
}

