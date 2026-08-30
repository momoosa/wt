//
//  AnimationPresets.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import SwiftUI

/// Standard animation presets used throughout the app
enum AnimationPresets {
    
    /// Quick spring animation (response: 0.3)
    static let quickSpring = Animation.spring(response: 0.3)
    
    /// Quick spring with custom damping (response: 0.3, dampingFraction: 0.8)
    static let quickSpringDamped = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    /// Smooth spring animation (response: 0.4, dampingFraction: 0.8)
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    
    /// Slow smooth spring (response: 0.6, dampingFraction: 0.8)
    static let slowSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    /// Standard spring animation (response: 0.5)
    static let standardSpring = Animation.spring(response: 0.5)
    
    /// Bouncy spring (response: 0.5, dampingFraction: 0.6)
    static let bouncySpring = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    /// Snappy animation (duration: 0.2)
    static let snappy = Animation.snappy(duration: 0.2)
    
    /// Linear animation (duration: 0.3)
    static let linearFast = Animation.linear(duration: 0.3)
}

// MARK: - Stagger Reveal Modifier

extension View {
    /// Applies a stagger-in effect that works inside List rows.
    /// Animates content opacity and a subtle vertical offset without
    /// trying to hide the List row chrome (which List controls).
    func staggerReveal(isRevealed: Bool) -> some View {
        self
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 8)
            .allowsHitTesting(isRevealed)
            .animation(.easeOut(duration: 0.35), value: isRevealed)
    }
}
