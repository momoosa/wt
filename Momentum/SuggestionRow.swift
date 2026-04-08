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
    let categoryColor: Color
    
    // Calculate text colors based on luminance
    private var iconAndTextColor: Color {
        if isSelected {
            let luminance = categoryColor.luminance ?? 0.5
            return luminance > 0.5 ? .black : .white
        } else {
            return .primary
        }
    }
    
    private var durationBadgeTextColor: Color {
        if isSelected {
            // When selected, badge background is white, so use black text
            return .black
        } else {
            // When not selected, badge background is categoryColor
            let luminance = categoryColor.luminance ?? 0.5
            return luminance > 0.5 ? .black : .white
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: suggestion.icon)
                .font(.system(size: 32))
                .foregroundStyle(isSelected ? iconAndTextColor : categoryColor)
                .frame(width: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(iconAndTextColor)
                
                Text(suggestion.subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? iconAndTextColor.opacity(0.9) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? categoryColor : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? categoryColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
