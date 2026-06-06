//
//  CategoryTab.swift
//  Momentum
//
//  Created by Mo Moosa on 06/04/2026.
//

import SwiftUI
import MomentumKit

// MARK: - Category Tab
struct GoalSuggestionCategoryTab: View {
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
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .black : category.colorValue(for: colorScheme))
                .padding(8)
                .frame(maxHeight: 30)
                .background {
                    Circle()
                        .fill(
                            preset.gradient(for: colorScheme)
                        )
                }
        
            
            Text(category.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? .primary : Color(.secondarySystemGroupedBackground))
                .animation(.spring, value: isSelected)
                .transition(.scale)
        )
    
    }
}

#Preview {
    HStack {
        Spacer()
        GoalSuggestionCategoryTab(category: .init(id: "Test", name: "Learning", icon: "book", color: "", suggestions: []), isSelected: true)
        GoalSuggestionCategoryTab(category: .init(id: "Test", name: "Learning", icon: "book", color: "", suggestions: []), isSelected: false)
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
