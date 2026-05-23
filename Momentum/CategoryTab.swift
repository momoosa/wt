//
//  CategoryTab.swift
//  Momentum
//
//  Created by Mo Moosa on 06/04/2026.
//

import SwiftUI
import MomentumKit

// MARK: - Category Tab
struct CategoryTab: View {
    let category: GoalCategory
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var preset: ThemePreset {
        category.themePreset
    }
    
    private var textColor: Color {
        isSelected ? preset.foregroundColor(for: colorScheme) : .primary
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? textColor : category.colorValue(for: colorScheme))
            
            Text(category.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isSelected ? AnyShapeStyle(preset.gradient(for: colorScheme)) : AnyShapeStyle(Color(.systemGray6)))
        )
        .overlay(
            Capsule()
                .strokeBorder(preset.gradient(for: colorScheme), lineWidth: isSelected ? 0 : 1.5)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
