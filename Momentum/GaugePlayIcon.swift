//
//  GaugePlayIcon.swift
//  Momentum
//
//  Created by Mo Moosa on 06/11/2025.
//

import SwiftUI

public struct GaugePlayIcon: View {
    public let imageName: String
    public let progress: Double
    public let color: Color
    public let size: CGFloat
    public let lineWidth: CGFloat
    
    /// The plain icon name (without .circle.fill suffix)
    private var plainIcon: String {
        imageName
            .replacingOccurrences(of: ".circle.fill", with: ".fill")
            .replacingOccurrences(of: ".circle", with: "")
    }
    
    public var body: some View {
        ZStack {
            // Background circle (replaces the SF Symbol's built-in circle)
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            
            // Progress arc — only when there's progress to show
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size - lineWidth, height: size - lineWidth)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            
            // Plain icon centered inside
            Image(systemName: plainIcon)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .accessibilityValue(progress > 0 ? "\(Int(min(progress, 1.0) * 100)) percent" : "")
    }
    
    public init(imageName: String, progress: Double, color: Color, size: CGFloat = 28, lineWidth: CGFloat = 2.5) {
        self.imageName = imageName
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }
}
