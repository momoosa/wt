// MARK: - Category Tab
struct CategoryTab: View {
    let category: GoalCategory
    let isSelected: Bool
    
    // Helper to match category theme colors
    private var categoryThemeColors: (light: Color, dark: Color) {
        // Find matching theme from themes array
        let themeKeywords: [String: String] = [
            "fitness": "exercise",
            "wellness": "wellness",
            "learning": "learning",
            "creative": "creative",
            "productivity": "productivity",
            "lifestyle": "home",
            "social": "social",
            "personal growth": "growth"
        ]
        
        let normalizedName = category.name.lowercased()
        var matchedTheme: ThemePreset?
        
        // Try to find matching theme
        if let themeId = themeKeywords[normalizedName] {
            matchedTheme = themePresets.first(where: { $0.id == themeId })
        }
        
        // Fallback to first theme with matching title
        if matchedTheme == nil {
            matchedTheme = themePresets.first(where: { $0.title.lowercased() == normalizedName })
        }
        
        // Use matched theme colors or fallback to category color
        if let theme = matchedTheme {
            return (theme.light, theme.dark)
        } else {
            return (category.colorValue.opacity(0.2), category.colorValue)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? categoryThemeColors.dark.contrastingTextColor : categoryThemeColors.dark)
            
            Text(category.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? categoryThemeColors.dark.contrastingTextColor : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isSelected ? categoryThemeColors.dark : Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .strokeBorder(categoryThemeColors.dark, lineWidth: isSelected ? 0 : 1.5)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
