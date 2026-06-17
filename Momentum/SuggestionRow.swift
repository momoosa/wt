//
//  SuggestionRow.swift
//  Momentum
//
//  Created by Mo Moosa on 06/04/2026.
//

import SwiftUI
import MomentumKit


// MARK: - Suggestion Row

struct SuggestionRow: View {
    let suggestion: GoalTemplateSuggestion
    let isSelected: Bool
    let themePreset: ThemePreset
    @Environment(\.colorScheme) private var colorScheme
    
    private var themeColor: Color {
        themePreset.color(for: colorScheme)
    }
    
    private var textColor: Color {
        isSelected ? themePreset.foregroundColor(for: colorScheme) : .primary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon area
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? themeColor.opacity(0.3) : themeColor.opacity(0.12))
                .frame(height: 64)
                .overlay {
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isSelected ? textColor : themeColor)
                }
                .padding(.bottom, 10)
            
            // Title
            Text(suggestion.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(textColor)
                .lineLimit(1)
            
            // Subtitle
            Text(suggestion.subtitle)
                .font(.caption)
                .foregroundStyle(isSelected ? textColor.opacity(0.8) : .secondary)
                .lineLimit(1)
                .padding(.top, 1)
            
            Spacer(minLength: 8)
            
            // USE THIS →
            HStack(spacing: 4) {
                Text("USE THIS")
                    .font(.caption2)
                    .fontWeight(.bold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(isSelected ? textColor.opacity(0.9) : themeColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? AnyShapeStyle(themePreset.gradient(for: colorScheme)) : AnyShapeStyle(Color(.systemBackground)))
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
