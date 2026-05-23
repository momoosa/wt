import SwiftUI

// MARK: - JSON Decoding Helper

private struct ThemePresetDTO: Decodable {
    let id: String
    let title: String
    let darkColors: [String]
    let lightColors: [String]
    let darkForegroundColor: String
    let lightForegroundColor: String
}

// MARK: - Theme Data Structure

public struct ThemePreset: Sendable {
    public let id: String
    public let title: String
    public let lightColors: [Color]
    public let darkColors: [Color]
    public let foregroundLight: Color
    public let foregroundDark: Color
    
    public init(id: String, title: String, lightColors: [Color], darkColors: [Color], foregroundLight: Color = .black, foregroundDark: Color = .white) {
        self.id = id
        self.title = title
        self.lightColors = lightColors
        self.darkColors = darkColors
        self.foregroundLight = foregroundLight
        self.foregroundDark = foregroundDark
    }
    
    // MARK: - Color Scheme Methods
    
    /// Returns the color palette for the given color scheme
    public func colors(for scheme: ColorScheme) -> [Color] {
        scheme == .dark ? darkColors : lightColors
    }
    
    /// Adaptive gradient for the given color scheme
    public func gradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colors(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Primary accent color — brightest in dark mode, deepest in light mode
    public func color(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            darkColors.first ?? .gray
        default:
            darkColors.last ?? .gray
        }
    }
    
    /// Foreground color appropriate for the theme's gradient background
    public func foregroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            foregroundDark
        default:
            foregroundLight
        }
    }
}



// MARK: - Legacy Theme ID Migration

/// Maps removed theme IDs to surviving preset IDs.
/// Only contains IDs that no longer exist in Themes.json.
/// `resolveThemePreset` tries direct ID match first, then falls back here.
public let legacyThemeIDMap: [String: String] = [
    // Removed reds/warm
    "salmon": "palette_12", "coral": "palette_12",
    // Removed orange
    "apricot": "palette_04",
    // Removed yellow
    "yellow": "palette_04", "yellow_dc": "palette_04", "sunshine": "palette_04",
    "lemon": "palette_04", "mustard": "palette_04", "palette_11": "palette_04",
    "yellowSalmon": "palette_01", "beach": "palette_12", "cream": "palette_20",
    // Removed green
    "lime": "palette_06", "forest_dc": "palette_19",
    "mint_dc": "palette_10", "seafoam": "palette_10",
    // Removed blue/cyan/teal
    "cyan": "palette_03", "turquoise": "palette_03", "teal": "palette_03",
    "teal_dc": "palette_03", "gb": "palette_03",
    "sky_blue": "palette_17", "azure": "palette_17",
    "blue_dc": "palette_17", "babyBlueAndWhite": "palette_18",
    "cobalt": "palette_17", "navy": "palette_17", "steel": "palette_18",
    "grey_blue": "palette_18", "blellow": "palette_17",
    // Removed purple
    "violet": "palette_16", "purple": "palette_16",
    "purple_dc": "palette_16", "ap": "palette_15",
    "lilac": "palette_05",
    "lavender": "palette_05", "mauve": "palette_15", "orchid": "palette_15",
    // Removed pink
    "pink0": "palette_07", "bubblegum": "palette_14",
    "fuchsia": "palette_14", "rose": "palette_13",
    // Removed brown/neutral
    "coffee": "palette_20", "taupe": "palette_20",
    // Removed gray
    "silver0": "palette_18", "slate": "palette_18",
    // Other removed
    "tangerine": "palette_09", "gold": "palette_04", "green": "palette_19",
    "ruby": "palette_13", "cherry": "palette_13",
]

/// Resolves a theme ID (old or new) to a ThemePreset.
/// Falls back to `defaultThemePreset` if not found.
public func resolveThemePreset(for themeID: String) -> ThemePreset {
    if let preset = themePresets.first(where: { $0.id == themeID }) {
        return preset
    }
    if let newID = legacyThemeIDMap[themeID],
       let preset = themePresets.first(where: { $0.id == newID }) {
        return preset
    }
    return defaultThemePreset
}

// MARK: - Bundle Access

/// Public accessor for MomentumKit's resource bundle
public let momentumKitBundle: Bundle = Bundle.module

// MARK: - Theme Loading

public let themePresets: [ThemePreset] = loadThemePresets()

/// Default fallback theme when no theme is assigned
public var defaultThemePreset: ThemePreset { themePresets[0] }

private func loadThemePresets() -> [ThemePreset] {
    guard let url = Bundle.module.url(forResource: "Themes", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let dtos = try? JSONDecoder().decode([ThemePresetDTO].self, from: data) else {
        assertionFailure("Failed to load Themes.json from bundle")
        return []
    }
    
    return dtos.map { dto in
        ThemePreset(
            id: dto.id,
            title: dto.title,
            lightColors: dto.lightColors.map { Color(hex: $0) },
            darkColors: dto.darkColors.map { Color(hex: $0) },
            foregroundLight: Color(hex: dto.lightForegroundColor),
            foregroundDark: Color(hex: dto.darkForegroundColor)
        )
    }
}

// MARK: - Preview Card
private struct ThemePreviewCard: View {
    let preset: ThemePreset
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let textColor = preset.foregroundColor(for: colorScheme)
        
        return VStack {
            HStack {
                Spacer()
                Text(preset.title)
                    .fontWeight(.bold)
                    .foregroundStyle(textColor)
                Spacer()
            }
            .background(preset.color(for: colorScheme))
            
            Spacer()
            
            VStack {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(textColor, lineWidth: 10)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .overlay {
                        Text("30%")
                            .font(.footnote)
                            .foregroundStyle(textColor)
                    }
                
                Toggle(isOn: .constant(true)) {
                    Text("Test")
                        .foregroundStyle(textColor)
                }
                .tint(textColor)
                
                Spacer()
                
                HStack {
                    Button {
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.largeTitle)
                    }
                    .foregroundStyle(textColor)
                }
            }
            .padding()
        }
        .background(preset.gradient(for: colorScheme))
    }
}

#Preview("All Themes", traits: .fixedLayout(width: 2000, height: 6000)) {
    ScrollView {
        LazyVGrid(columns: [GridItem(), GridItem(), GridItem(), GridItem(), GridItem()], spacing: 8) {
            ForEach(themePresets, id: \.id) { preset in
                ThemePreviewCard(preset: preset)
                    .frame(height: 200)
                }
        }
        .padding(8)
    }
}
