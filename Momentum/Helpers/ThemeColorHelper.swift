//
//  ThemeColorHelper.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import SwiftUI
import MomentumKit

/// Helper for consistent theme color selection across the app
/// Avoids static references for better testability
struct ThemeColorHelper {
    let colorScheme: ColorScheme
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }
    
    /// Get the appropriate accent color for a theme based on current color scheme
    func accentColor(for theme: ThemePreset) -> Color {
        switch colorScheme {
        case .light:
            return theme.dark
        case .dark:
            return theme.neon
        @unknown default:
            return theme.light
        }
    }
    
    /// Get the appropriate tint color for a goal session
    func tintColor(for session: GoalSession) -> Color {
        return accentColor(for: session.goal?.primaryTag?.theme ?? themePresets[0])
    }
    
    /// Get the appropriate tint color for a goal
    func tintColor(for goal: Goal) -> Color {
        return accentColor(for: goal.primaryTag?.theme ?? themePresets[0])
    }
    
    /// Get the appropriate tint color for a goal tag
    func tintColor(for tag: GoalTag) -> Color {
        return accentColor(for: tag.theme)
    }
}

/// View extension for easy access to theme color helper
extension View {
    /// Get theme color helper for current environment
    func themeColorHelper(colorScheme: ColorScheme) -> ThemeColorHelper {
        ThemeColorHelper(colorScheme: colorScheme)
    }
}
