//
//  HapticFeedbackManager.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import Foundation
#if os(iOS)
import UIKit
#endif

/// Manages haptic feedback across the app
@MainActor
struct HapticFeedbackManager {
    
    enum FeedbackStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid
        case success
        case warning
        case error
    }
    
    /// Trigger haptic feedback with the specified style
    static func trigger(_ style: FeedbackStyle) {
        #if os(iOS)
        switch style {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .soft:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        case .rigid:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        #endif
    }
}
