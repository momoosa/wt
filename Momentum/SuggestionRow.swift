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
    
    private var textColor: Color {
        isSelected ? themePreset.foregroundColor(for: colorScheme) : .primary
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: suggestion.icon)
                .font(.system(size: 32))
                .foregroundStyle(isSelected ? textColor : themePreset.color(for: colorScheme))
                .frame(width: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(textColor)
                
                Text(suggestion.subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? textColor.opacity(0.9) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? AnyShapeStyle(themePreset.gradient(for: colorScheme)) : AnyShapeStyle(Color(.systemGray6)))
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
