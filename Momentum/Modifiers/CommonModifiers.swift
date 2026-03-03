//
//  CommonModifiers.swift
//  Momentum
//
//  Created by Mo Moosa on 03/03/2026.
//

import SwiftUI

// MARK: - Frame Modifiers

extension View {
    /// Apply max width frame (equivalent to .frame(maxWidth: .infinity))
    func maxWidth(alignment: Alignment = .center) -> some View {
        self.frame(maxWidth: .infinity, alignment: alignment)
    }
    
    /// Apply max height frame (equivalent to .frame(maxHeight: .infinity))
    func maxHeight(alignment: Alignment = .center) -> some View {
        self.frame(maxHeight: .infinity, alignment: alignment)
    }
    
    /// Apply both max width and max height
    func maxFrame(alignment: Alignment = .center) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

// MARK: - Card Style Modifiers

extension View {
    /// Standard card styling with background and corner radius
    func standardCardStyle() -> some View {
        self
            .background(ColorConstants.Background.groupedSecondary)
            .cornerRadius(LayoutConstants.CornerRadius.standard)
    }
    
    /// Card with shadow
    func cardWithShadow(radius: CGFloat = 8, opacity: Double = 0.1) -> some View {
        self
            .background(ColorConstants.Background.primary)
            .cornerRadius(LayoutConstants.CornerRadius.standard)
            .shadow(color: .black.opacity(opacity), radius: radius)
    }
}

// MARK: - List Row Modifiers

extension View {
    /// Standard list row styling
    func standardListRowStyle() -> some View {
        self.listRowInsets(LayoutConstants.EdgeInsets.standard)
    }
    
    /// Compact list row styling (less padding)
    func compactListRowStyle() -> some View {
        self.listRowInsets(LayoutConstants.EdgeInsets.listRowCompact)
    }
}

// MARK: - Edge Insets Constants Enhancement

extension LayoutConstants {
    enum EdgeInsets {
        static let standard = SwiftUI.EdgeInsets(
            top: LayoutConstants.Padding.standard,
            leading: LayoutConstants.Padding.standard,
            bottom: LayoutConstants.Padding.standard,
            trailing: LayoutConstants.Padding.standard
        )
        
        static let listRowCompact = SwiftUI.EdgeInsets(
            top: LayoutConstants.Padding.small,
            leading: LayoutConstants.Padding.standard,
            bottom: LayoutConstants.Padding.small,
            trailing: LayoutConstants.Padding.standard
        )
        
        static let zero = SwiftUI.EdgeInsets()
    }
}

// MARK: - Divider Modifiers

extension Divider {
    /// Standard styled divider
    func standardStyle() -> some View {
        self
            .background(ColorConstants.Divider.standard)
            .frame(height: LayoutConstants.Divider.height)
            .opacity(LayoutConstants.Divider.opacity)
    }
}

// MARK: - Divider Constants Enhancement

extension LayoutConstants {
    enum Divider {
        static let height: CGFloat = 1
        static let opacity: Double = 0.2
    }
}
