//
//  ShimmerEffect.swift
//  Momentum
//
//  Created by Assistant on 25/03/2026.
//

import SwiftUI

/// Rainbow shimmer effect similar to Xcode's Apple Intelligence text field
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    var speed: Double = 2.0
    var colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: colors + colors, // Repeat colors for seamless loop
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 3)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 3))
                    .blendMode(.overlay)
                    .mask {
                        content
                    }
                }
            }
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

/// Alternative shimmer that uses hue rotation for smoother animation
struct HueShimmerEffect: ViewModifier {
    @State private var hueRotation: Double = 0
    var speed: Double = 3.0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .red, .orange, .yellow, .green, .blue, .purple, .pink, .red
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .hueRotation(Angle(degrees: hueRotation))
                .blendMode(.overlay)
                .mask {
                    content
                }
            }
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    hueRotation = 360
                }
            }
    }
}

/// Subtle shimmer border effect
struct ShimmerBorderEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    var speed: Double = 2.0
    var lineWidth: CGFloat = 2
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: geometry.size.height / 2)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .hueRotation(Angle(degrees: phase * 360)),
                            lineWidth: lineWidth
                        )
                }
            }
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Apply rainbow shimmer effect
    func shimmer(speed: Double = 2.0) -> some View {
        modifier(ShimmerEffect(speed: speed))
    }
    
    /// Apply hue-rotating shimmer effect
    func hueShimmer(speed: Double = 3.0) -> some View {
        modifier(HueShimmerEffect(speed: speed))
    }
    
    /// Apply shimmer border effect
    func shimmerBorder(speed: Double = 2.0, lineWidth: CGFloat = 2) -> some View {
        modifier(ShimmerBorderEffect(speed: speed, lineWidth: lineWidth))
    }
}

/// Shimmer border view for recommended sessions
struct ShimmerBorderView: View {
    @State private var hueRotation: Double = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .strokeBorder(lineWidth: 5)
            .foregroundStyle(
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .hueRotation(Angle(degrees: hueRotation))
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    hueRotation = 360
                }
            }
    }
}

/// Shimmer background view for recommended sessions
struct ShimmerBackgroundView: View {
    @State private var hueRotation: Double = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .hueRotation(Angle(degrees: hueRotation))
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    hueRotation = 360
                }
            }
    }
}
