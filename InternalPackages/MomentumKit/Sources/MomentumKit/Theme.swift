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
    
    // MARK: - Backward-Compatible Color Accessors
    
    /// First color in the light palette
    public var light: Color { lightColors.first ?? .gray }
    
    /// Last color in the dark palette (deepest)
    public var dark: Color { darkColors.last ?? .gray }
    
    /// First color in the dark palette (brightest/neon)
    public var neon: Color { darkColors.first ?? .gray }
    
    // MARK: - Color Scheme Methods
    
    public func color(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            dark
        case .dark:
            neon
        default:
            light
        }
    }
    
    /// Text color optimized for the theme's gradient background
    public func textColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            foregroundLight
        case .dark:
            foregroundDark
        default:
            foregroundLight
        }
    }
    
    /// Foreground color for use on non-gradient backgrounds
    public func foregroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            foregroundLight
        case .dark:
            foregroundDark
        default:
            foregroundLight
        }
    }
}

// MARK: - ThemePreset Extensions

public extension ThemePreset {
    /// Creates a standard linear gradient using the dark color palette
    var gradient: LinearGradient {
        LinearGradient(
            colors: darkColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Creates a light variant linear gradient using the light color palette
    var lightGradient: LinearGradient {
        LinearGradient(
            colors: lightColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Creates a radial gradient for backgrounds
    var radialGradient: RadialGradient {
        RadialGradient(
            colors: darkColors,
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
    
    /// Creates an angular gradient for circular progress indicators
    var angularGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.white, neon, .white]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
}

// MARK: - Legacy Theme ID Migration

/// Maps old theme IDs (from before the palette refactor) to new palette IDs.
/// Used to preserve existing user data when looking up themes.
public let legacyThemeIDMap: [String: String] = [
    // Reds / Warm
    "red": "palette_01", "crimson": "palette_01", "cherry": "palette_13",
    "coral": "palette_12", "salmon": "palette_12",
    // Orange
    "orange": "palette_04", "marmalade": "palette_09", "burnt_orange": "palette_09",
    "peach": "palette_11", "amber": "palette_11", "apricot": "palette_11",
    // Yellow
    "yellow": "palette_11", "yellow_dc": "palette_11", "sunshine": "palette_11",
    "lemon": "palette_11", "mustard": "palette_11", "bee": "palette_11",
    "straw": "palette_20", "yellowSalmon": "palette_01", "beach": "palette_12",
    "beige": "palette_20", "cream": "palette_20",
    // Green
    "lime": "palette_06", "emerald": "palette_10", "forest": "palette_19",
    "forest_dc": "palette_19", "olive": "palette_19", "sage": "palette_19",
    "mint": "palette_10", "mint_dc": "palette_10", "fresh": "palette_06",
    "seafoam": "palette_10", "seaFoam_dc": "palette_18",
    // Blue / Cyan / Teal
    "cyan": "palette_03", "turquoise": "palette_03", "teal": "palette_03",
    "teal_dc": "palette_03", "mint_blue": "palette_03", "gb": "palette_03",
    "sky_blue": "palette_17", "azure": "palette_17", "blue": "palette_17",
    "blue_dc": "palette_17", "babyBlueAndWhite": "palette_18",
    "cobalt": "palette_17", "navy": "palette_17", "steel": "palette_18",
    "grey_blue": "palette_18", "blellow": "palette_17",
    "navyAndRed": "palette_17", "blueAndPastelPink": "palette_05",
    // Purple
    "indigo": "palette_16", "violet": "palette_16", "purple": "palette_16",
    "purple_dc": "palette_16", "ap": "palette_15", "grape": "palette_16",
    "plum": "palette_15", "lilac": "palette_05", "lilac_dc": "palette_05",
    "lavender": "palette_05", "mauve": "palette_15", "orchid": "palette_15",
    "magenta": "palette_15",
    // Pink
    "hot_pink": "palette_14", "pink0": "palette_07", "bubblegum": "palette_14",
    "fuchsia": "palette_14", "rose": "palette_13",
    // Brown / Neutral
    "frappe": "palette_20", "chocolate": "palette_20", "coffee": "palette_20",
    "taupe": "palette_20",
    // Gray / Silver
    "stone": "palette_18", "silver0": "palette_18", "charcoal": "palette_18",
    "slate": "palette_18",
    // Other
    "tangerine": "palette_09", "gold": "palette_04", "green": "palette_19",
    "ruby": "palette_13"
]

/// Resolves a theme ID (old or new) to a ThemePreset.
/// Falls back to `themePresets[0]` if not found.
public func resolveThemePreset(for themeID: String) -> ThemePreset {
    // Try direct match first (new palette IDs)
    if let preset = themePresets.first(where: { $0.id == themeID }) {
        return preset
    }
    // Try legacy mapping
    if let newID = legacyThemeIDMap[themeID],
       let preset = themePresets.first(where: { $0.id == newID }) {
        return preset
    }
    return themePresets[0]
}

// MARK: - Bundle Access

/// Public accessor for MomentumKit's resource bundle
public let momentumKitBundle: Bundle = Bundle.module

// MARK: - Theme Loading

public let themePresets: [ThemePreset] = loadThemePresets()

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
        let secondary = preset.neon
        let primary = preset.dark
        let tertiary = Color.white
        
        return VStack {
            HStack {
                Spacer()
                Text(preset.title)
                    .fontWeight(.bold)
                    .foregroundStyle(tertiary)
                Spacer()
            }
            .background(primary)
            
            Spacer()
            
            VStack {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(tertiary, lineWidth: 10)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .overlay {
                        Text("30%")
                            .font(.footnote)
                            .foregroundStyle(tertiary)
                    }
                
                Toggle(isOn: .constant(true)) {
                    Text("Test")
                        .foregroundStyle(tertiary)
                }
                .tint(tertiary)
                
                Spacer()
                
                HStack {
                    Button {
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.largeTitle)
                    }
                    .foregroundStyle(tertiary)
                }
            }
            .padding()
        }
        .background(preset.gradient)
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
