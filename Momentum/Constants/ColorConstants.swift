//
//  ColorConstants.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import SwiftUI

/// Centralized color constants for the app
enum ColorConstants {
    
    /// Semantic colors for app-wide consistency
    enum Semantic {
        /// Primary accent color for actions and highlights
        static let accent = Color.blue
        
        /// Destructive actions (delete, remove, etc.)
        static let destructive = Color.red
        
        /// Success states and completion
        static let success = Color.green
        
        /// Warning states
        static let warning = Color.orange
        
        /// Secondary text and elements
        static let secondary = Color.secondary
    }
    
    /// Background colors for different contexts
    enum Background {
        /// Primary grouped background (like Settings)
        static let groupedPrimary = Color(.systemGroupedBackground)
        
        /// Secondary grouped background (list rows in grouped style)
        static let groupedSecondary = Color(.secondarySystemGroupedBackground)
        
        /// Tertiary grouped background (inner containers)
        static let groupedTertiary = Color(.tertiarySystemGroupedBackground)
        
        /// Primary background for standard views
        static let primary = Color(.systemBackground)
        
        /// Secondary background for layered content
        static let secondary = Color(.secondarySystemBackground)
    }
    
    /// Foreground/text colors
    enum Text {
        /// Primary text color
        static let primary = Color.primary
        
        /// Secondary text color (less emphasis)
        static let secondary = Color.secondary
        
        /// Tertiary text color (least emphasis)
        static let tertiary = Color(.tertiaryLabel)
    }
    
    /// Divider and separator colors
    enum Divider {
        /// Standard divider color
        static let standard = Color(.separator)
        
        /// Opaque divider
        static let opaque = Color(.opaqueSeparator)
    }
}
