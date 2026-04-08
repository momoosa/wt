//
//  ThemeTagButton.swift
//  Momentum
//
//  Created by Mo Moosa on 07/04/2026.
//
import SwiftUI
import MomentumKit

struct ThemeTagButton: View {
    @Environment(\.colorScheme) var colorScheme
    let goalTheme: GoalTag
    let isSelected: Bool
    let action: () -> Void
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        let themeColor = goalTheme.themePreset.color(for: colorScheme)
        let backgroundColor = colorScheme == .dark ? goalTheme.themePreset.dark : goalTheme.themePreset.light
        Button(action: action) {
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goalTheme.themePreset.light, goalTheme.themePreset.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
                    )
                
                Text(goalTheme.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                // Remove button
                if let onRemove = onRemove {
                    Button(action: {
                        onRemove()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? backgroundColor.opacity(0.3) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? themeColor : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? themeColor : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(AnimationPresets.quickSpring, value: isSelected)
    }
}

// Button for selecting and editing tags - similar to ThemeTagButton but for GoalTag objects
struct TagButton: View {
    let tag: GoalTag
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Color indicator
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tag.themePreset.light, tag.themePreset.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? tag.themePreset.dark : Color.clear, lineWidth: 2)
                    )
                
                Text(tag.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .fontWeight(isSelected ? .semibold : .regular)
             
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? tag.themePreset.light.opacity(0.3) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? tag.themePreset.dark : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? tag.themePreset.dark : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(AnimationPresets.quickSpring, value: isSelected)
    }
}
