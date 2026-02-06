//
//  CardModifiers.swift
//  WeektimeKit
//
//  Reusable card and container styling modifiers
//

import SwiftUI

// MARK: - Card Style Modifier

public struct CardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    let backgroundColor: Color?

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor ?? Color(.systemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadowColor.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
    }
}

// MARK: - Glass Effect Card Style

public struct GlassCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOpacity: Double

    public func body(content: Content) -> some View {
        content
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadowColor.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
    }
}

// MARK: - View Extensions

public extension View {
    /// Applies a standard card style with rounded corners and shadow
    /// - Parameters:
    ///   - cornerRadius: The corner radius (default: 12)
    ///   - shadowColor: The shadow color (default: .black)
    ///   - shadowRadius: The shadow blur radius (default: 2)
    ///   - shadowOpacity: The shadow opacity (default: 0.05)
    ///   - backgroundColor: Optional background color (default: system background)
    /// - Returns: View with card styling applied
    func cardStyle(
        cornerRadius: CGFloat = 12,
        shadowColor: Color = .black,
        shadowRadius: CGFloat = 2,
        shadowOpacity: Double = 0.05,
        backgroundColor: Color? = nil
    ) -> some View {
        modifier(CardStyle(
            cornerRadius: cornerRadius,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity,
            backgroundColor: backgroundColor
        ))
    }

    /// Applies a glass effect card style with rounded corners and shadow
    /// - Parameters:
    ///   - cornerRadius: The corner radius (default: 20)
    ///   - shadowColor: The shadow color (default: .black)
    ///   - shadowRadius: The shadow blur radius (default: 20)
    ///   - shadowOpacity: The shadow opacity (default: 0.4)
    /// - Returns: View with glass card styling applied
    func glassCardStyle(
        cornerRadius: CGFloat = 20,
        shadowColor: Color = .black,
        shadowRadius: CGFloat = 20,
        shadowOpacity: Double = 0.4
    ) -> some View {
        modifier(GlassCardStyle(
            cornerRadius: cornerRadius,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity
        ))
    }
}

// MARK: - Reusable Button Components

/// A circular icon button with customizable styling
public struct IconButton: View {
    let icon: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    public init(
        icon: String,
        size: CGFloat = 60,
        backgroundColor: Color = Color.white.opacity(0.2),
        foregroundColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(Circle().fill(backgroundColor))
        }
        .buttonStyle(.plain)
    }
}

/// A rounded rectangle button with icon and optional label
public struct RoundedButton: View {
    let icon: String?
    let label: String
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let action: () -> Void

    public init(
        icon: String? = nil,
        label: String,
        backgroundColor: Color = .accentColor,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 12,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(label)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}
