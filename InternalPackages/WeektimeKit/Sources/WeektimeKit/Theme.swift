import SwiftUI
import SwiftData

@Model
public class Theme: Identifiable {
    public private(set) var id: String
    public private(set) var title: String
    public private(set) var lightColorID: String
    public private(set) var darkColorID: String
    public private(set) var neonColorID: String
    public var light: Color {
        get {
            Color(hex: lightColorID)
        }
        set {
            lightColorID = newValue.toHex() ?? lightColorID
        }
    }
    public var dark: Color {
        get {
            Color(hex: darkColorID)
        }
        set {
            darkColorID = newValue.toHex() ?? darkColorID
        }
    }
    public var neon: Color {
        get {
            Color(hex: neonColorID)
        }
        set {
            neonColorID = newValue.toHex() ?? neonColorID
        }
    }
    
    public init(id: String, title: String, light: Color, dark: Color, neon: Color) {
        self.id = id
        self.title = title
        self.lightColorID = light.toHex() ?? ""
        self.darkColorID = dark.toHex() ?? ""
        self.neonColorID = neon.toHex() ?? ""
    }
    
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
    /// Always returns white for maximum contrast on vibrant gradients
    public func textColor(for colorScheme: ColorScheme) -> Color {
        // For vibrant gradient backgrounds, white provides best contrast
        // Could be customized per theme in the future if needed
        .white
    }
}


// Seed data structure (not persisted)
public struct ThemePreset: Sendable{
    public let id: String
    public let title: String
    public let light: Color
    public let dark: Color
    public let neon: Color
    
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
    /// Always returns white for maximum contrast on vibrant gradients
    public func textColor(for colorScheme: ColorScheme) -> Color {
        // For vibrant gradient backgrounds, white provides best contrast
        .white
    }
    
    public func toTheme() -> Theme {
        Theme(id: id, title: title, light: light, dark: dark, neon: neon)
    }
}

public let themePresets: [ThemePreset] = [
    // 🔴 RED
    ThemePreset(id: "red", title: "Red", light: Color(hex: "#FFCCCC"), dark: Color(hex: "#8B0000"), neon: Color(hex: "#FF4C4C")),
    ThemePreset(id: "red_dc", title: "Red (DC)", light: Color(hex: "E4A3A3"), dark: Color(hex: "7D241C"), neon: Color(hex: "FF6B6B")),
    ThemePreset(id: "crimson", title: "Crimson", light: Color(hex: "#FFE4E1"), dark: Color(hex: "#DC143C"), neon: Color(hex: "#FF1744")),
    ThemePreset(id: "cherry", title: "Cherry", light: Color(hex: "#FFC1CC"), dark: Color(hex: "#990000"), neon: Color(hex: "#FF0033")),
    ThemePreset(id: "cherry_dc", title: "Cherry (DC)", light: Color(hex: "F7C5CC"), dark: Color(hex: "CC313D"), neon: Color(hex: "FF5566")),
    ThemePreset(id: "ruby", title: "Ruby", light: Color(hex: "#FFD6D6"), dark: Color(hex: "#9B111E"), neon: Color(hex: "#E0115F")),
    ThemePreset(id: "coral", title: "Coral", light: Color(hex: "#F7C6B6"), dark: Color(hex: "#FF6F61"), neon: Color(hex: "#FF7F50")),
    ThemePreset(id: "salmon", title: "Salmon", light: Color(hex: "#FFE5E0"), dark: Color(hex: "#FA8072"), neon: Color(hex: "#FF8C8C")),
    
    // 🟠 ORANGE
    ThemePreset(id: "orange", title: "Orange", light: Color(hex: "#FFDAB9"), dark: Color(hex: "#FF8C00"), neon: Color(hex: "#FF6A00")),
    ThemePreset(id: "mandarin", title: "Mandarin", light: Color(hex: "FE8C00"), dark: Color(hex: "BA5500"), neon: Color(hex: "FFA633")),
    ThemePreset(id: "burnt_orange", title: "Burnt Orange", light: Color(hex: "#FFDAB3"), dark: Color(hex: "#FF4500"), neon: Color(hex: "#FF6A00")),
    ThemePreset(id: "ob", title: "OB", light: Color(hex: "F5C046"), dark: Color(hex: "EE833F"), neon: Color(hex: "FFA94D")),
    ThemePreset(id: "peach", title: "Peach", light: Color(hex: "#FFDAB3"), dark: Color(hex: "#FF9966"), neon: Color(hex: "#FFCC99")),
    ThemePreset(id: "amber", title: "Amber", light: Color(hex: "#FFEDCC"), dark: Color(hex: "#FF7E00"), neon: Color(hex: "#FFBF00")),
    ThemePreset(id: "apricot", title: "Apricot", light: Color(hex: "#FFE5CC"), dark: Color(hex: "#FF8B3D"), neon: Color(hex: "#FFAA66")),

    // 🟡 YELLOW
    ThemePreset(id: "yellow", title: "Yellow", light: Color(hex: "#FFFACD"), dark: Color(hex: "#DAA520"), neon: Color(hex: "#FFFF33")),
    ThemePreset(id: "yellow_dc", title: "Yellow (DC)", light: Color(hex: "F6DFAF"), dark: Color(hex: "C88B2F"), neon: Color(hex: "FFD966")),
    ThemePreset(id: "sunshine", title: "Sunshine", light: Color(hex: "#FFF9B1"), dark: Color(hex: "#FFD700"), neon: Color(hex: "#FFEA00")),
    ThemePreset(id: "lemon", title: "Lemon", light: Color(hex: "#FFFACD"), dark: Color(hex: "#FFF44F"), neon: Color(hex: "#FFFF66")),
    ThemePreset(id: "gold", title: "Gold", light: Color(hex: "#FFF8DC"), dark: Color(hex: "#B8860B"), neon: Color(hex: "#FFD700")),
    ThemePreset(id: "mustard", title: "Mustard", light: Color(hex: "#FFEDCC"), dark: Color(hex: "#FFDB58"), neon: Color(hex: "#FFDB00")),
    ThemePreset(id: "bee", title: "Bzz bzz", light: Color(hex: "EAC04A"), dark: Color(hex: "F8D677"), neon: Color(hex: "FFE899")),
    ThemePreset(id: "straw", title: "Straw", light: Color(hex: "D5D887"), dark: Color(hex: "B3B665"), neon: Color(hex: "E8E899")),
    ThemePreset(id: "yellowSalmon", title: "Yellow Salmon", light: Color(hex: "F9E795"), dark: Color(hex: "F96167"), neon: Color(hex: "FF8C94")),
    ThemePreset(id: "beach", title: "Beach", light: Color(hex: "FFF2D7"), dark: Color(hex: "F98866"), neon: Color(hex: "FFA588")),
    ThemePreset(id: "beige", title: "Beige", light: Color(hex: "#F5F5DC"), dark: Color(hex: "#8B7355"), neon: Color(hex: "#E0D5B7")),
    ThemePreset(id: "cream", title: "Cream", light: Color(hex: "#FFFDD0"), dark: Color(hex: "#C8B560"), neon: Color(hex: "#FFF5CC")),

    // 🟢 GREEN
    ThemePreset(id: "lime", title: "Lime", light: Color(hex: "#D9FFB3"), dark: Color(hex: "#6B8E23"), neon: Color(hex: "#BFFF00")),
    ThemePreset(id: "green", title: "Green", light: Color(hex: "#D8EFD5"), dark: Color(hex: "#228B22"), neon: Color(hex: "#39FF14")),
    ThemePreset(id: "emerald", title: "Emerald", light: Color(hex: "#D5F5E3"), dark: Color(hex: "#50C878"), neon: Color(hex: "#00FF7F")),
    ThemePreset(id: "forest", title: "Forest", light: Color(hex: "#D5ECD5"), dark: Color(hex: "#228B22"), neon: Color(hex: "#32CD32")),
    ThemePreset(id: "forest_dc", title: "Forest (DC)", light: Color(hex: "97BC62"), dark: Color(hex: "2C5F2D"), neon: Color(hex: "7FD282")),
    ThemePreset(id: "olive", title: "Olive", light: Color(hex: "#E8F5E3"), dark: Color(hex: "#808000"), neon: Color(hex: "#B5CC18")),
    ThemePreset(id: "sage", title: "Sage", light: Color(hex: "#DDE5D5"), dark: Color(hex: "#87AE73"), neon: Color(hex: "#B2D3A8")),
    ThemePreset(id: "mint", title: "Mint", light: Color(hex: "#AAF0D1"), dark: Color(hex: "#008080"), neon: Color(hex: "#00FFC6")),
    ThemePreset(id: "mint_dc", title: "Mint (DC)", light: Color(hex: "C2EBE2"), dark: Color(hex: "135058"), neon: Color(hex: "7FD6C8")),
    ThemePreset(id: "fresh", title: "Fresh", light: Color(hex: "F1F2B5"), dark: Color(hex: "135058"), neon: Color(hex: "C8E6A0")),
    ThemePreset(id: "seafoam", title: "Seafoam", light: Color(hex: "#CFFFE5"), dark: Color(hex: "#8FBC8F"), neon: Color(hex: "#00FA9A")),
    ThemePreset(id: "seaFoam_dc", title: "Seafoam (DC)", light: Color(hex: "C4DFE6"), dark: Color(hex: "165E81"), neon: Color(hex: "66BDD6")),

    // 🔵 BLUE/CYAN/TEAL
    ThemePreset(id: "cyan", title: "Cyan", light: Color(hex: "#B2FFFF"), dark: Color(hex: "#008B8B"), neon: Color(hex: "#00FFFF")),
    ThemePreset(id: "turquoise", title: "Turquoise", light: Color(hex: "#CCFFF5"), dark: Color(hex: "#30D5C8"), neon: Color(hex: "#40E0D0")),
    ThemePreset(id: "teal", title: "Teal", light: Color(hex: "#B2FFFF"), dark: Color(hex: "#008080"), neon: Color(hex: "#00CED1")),
    ThemePreset(id: "teal_dc", title: "Teal (DC)", light: Color(hex: "7797A0"), dark: Color(hex: "244652"), neon: Color(hex: "6BB6C3")),
    ThemePreset(id: "mint_blue", title: "Mint Blue", light: Color(hex: "#BFFFEA"), dark: Color(hex: "#5F9EA0"), neon: Color(hex: "#7FFFD4")),
    ThemePreset(id: "gb", title: "GB", light: Color(hex: "378982"), dark: Color(hex: "043650"), neon: Color(hex: "66BFB0")),
    ThemePreset(id: "sky_blue", title: "Sky Blue", light: Color(hex: "#C0EFFF"), dark: Color(hex: "#4682B4"), neon: Color(hex: "#87CEEB")),
    ThemePreset(id: "azure", title: "Azure", light: Color(hex: "#D6EFFF"), dark: Color(hex: "#007FFF"), neon: Color(hex: "#00CFFF")),
    ThemePreset(id: "blue", title: "Blue", light: Color(hex: "#BFEFFF"), dark: Color(hex: "#003366"), neon: Color(hex: "#00BFFF")),
    ThemePreset(id: "blue_dc", title: "Blue (DC)", light: Color(hex: "ABC7DD"), dark: Color(hex: "26466F"), neon: Color(hex: "7DA8D9")),
    ThemePreset(id: "babyBlueAndWhite", title: "B&W", light: Color(hex: "FFFFFF"), dark: Color(hex: "8AAAE5"), neon: Color(hex: "A3C2F0")),
    ThemePreset(id: "cobalt", title: "Cobalt", light: Color(hex: "#D6E5FF"), dark: Color(hex: "#0047AB"), neon: Color(hex: "#4169E1")),
    ThemePreset(id: "navy", title: "Navy", light: Color(hex: "#D6E5F5"), dark: Color(hex: "#000080"), neon: Color(hex: "#4169E1")),
    ThemePreset(id: "steel", title: "Steel", light: Color(hex: "#E5F0F5"), dark: Color(hex: "#4682B4"), neon: Color(hex: "#87CEEB")),
    ThemePreset(id: "grey_blue", title: "Grey Blue", light: Color(hex: "#DDEAF6"), dark: Color(hex: "#6A5ACD"), neon: Color(hex: "#7B92FF")),
    ThemePreset(id: "blellow", title: "Blellow", light: Color(hex: "FB6542"), dark: Color(hex: "375E97"), neon: Color(hex: "6B8FD9")),
    ThemePreset(id: "navyAndRed", title: "Navy & Red", light: Color(hex: "C5001A"), dark: Color(hex: "002C54"), neon: Color(hex: "4D7CB8")),
    ThemePreset(id: "blueAndPastelPink", title: "Blue & Pastel Pink", light: Color(hex: "FBEAEB"), dark: Color(hex: "2F3C7E"), neon: Color(hex: "94A5E8")),

    // 🟣 INDIGO/VIOLET/PURPLE
    ThemePreset(id: "indigo", title: "Indigo", light: Color(hex: "#E0D5F0"), dark: Color(hex: "#4B0082"), neon: Color(hex: "#8B00FF")),
    ThemePreset(id: "violet", title: "Violet", light: Color(hex: "#E8D5FF"), dark: Color(hex: "#8B00FF"), neon: Color(hex: "#BF00FF")),
    ThemePreset(id: "purple", title: "Purple", light: Color(hex: "#D6CADD"), dark: Color(hex: "#4B0082"), neon: Color(hex: "#D100FF")),
    ThemePreset(id: "purple_dc", title: "Purple (DC)", light: Color(hex: "ACAED7"), dark: Color(hex: "333869"), neon: Color(hex: "8B8ED6")),
    ThemePreset(id: "ap", title: "AP", light: Color(hex: "734DB9"), dark: Color(hex: "994690"), neon: Color(hex: "B780D1")),
    ThemePreset(id: "grape", title: "Grape", light: Color(hex: "#E0BBE4"), dark: Color(hex: "#5D3FD3"), neon: Color(hex: "#9966FF")),
    ThemePreset(id: "plum", title: "Plum", light: Color(hex: "#DDA0DD"), dark: Color(hex: "#9400D3"), neon: Color(hex: "#DA70D6")),
    ThemePreset(id: "lilac", title: "Lilac", light: Color(hex: "#E6DAF5"), dark: Color(hex: "#9370DB"), neon: Color(hex: "#C8A2FF")),
    ThemePreset(id: "lilac_dc", title: "Lilac (DC)", light: Color(hex: "735DA5"), dark: Color(hex: "D3C5E5"), neon: Color(hex: "B8A3DB")),
    ThemePreset(id: "lavender", title: "Lavender", light: Color(hex: "#F0E6FF"), dark: Color(hex: "#967BB6"), neon: Color(hex: "#E6E6FA")),
    ThemePreset(id: "mauve", title: "Mauve", light: Color(hex: "#E0B0FF"), dark: Color(hex: "#9932CC"), neon: Color(hex: "#DA70D6")),
    ThemePreset(id: "orchid", title: "Orchid", light: Color(hex: "#F5E6FF"), dark: Color(hex: "#DA70D6"), neon: Color(hex: "#FF66FF")),
    ThemePreset(id: "magenta", title: "Magenta", light: Color(hex: "#FFE6FF"), dark: Color(hex: "#FF00FF"), neon: Color(hex: "#FF66FF")),
    
    // 🩷 PINK
    ThemePreset(id: "hot_pink", title: "Hot Pink", light: Color(hex: "#FFB6C1"), dark: Color(hex: "#C71585"), neon: Color(hex: "#FF69B4")),
    ThemePreset(id: "pink0", title: "Pink", light: Color(hex: "#FFE6F0"), dark: Color(hex: "#FF69B4"), neon: Color(hex: "#FFB3D9")),
    ThemePreset(id: "bubblegum", title: "Bubblegum", light: Color(hex: "#FFE6F5"), dark: Color(hex: "#FF69B4"), neon: Color(hex: "#FFC0E0")),
    ThemePreset(id: "fuchsia", title: "Fuchsia", light: Color(hex: "#FFE5F5"), dark: Color(hex: "#FF00FF"), neon: Color(hex: "#FF77FF")),
    ThemePreset(id: "rose", title: "Rose", light: Color(hex: "#FFE4E1"), dark: Color(hex: "#FF007F"), neon: Color(hex: "#FF66B2")),
    
    // 🤎 BROWN/NEUTRAL
    ThemePreset(id: "frappe", title: "Frappe", light: Color(hex: "F1D3B2"), dark: Color(hex: "46211A"), neon: Color(hex: "E8B88B")),
    ThemePreset(id: "chocolate", title: "Chocolate", light: Color(hex: "#E8D5CC"), dark: Color(hex: "#7B3F00"), neon: Color(hex: "#CD853F")),
    ThemePreset(id: "coffee", title: "Coffee", light: Color(hex: "#E5DDD5"), dark: Color(hex: "#6F4E37"), neon: Color(hex: "#A67B5B")),
    ThemePreset(id: "taupe", title: "Taupe", light: Color(hex: "#E8E0D5"), dark: Color(hex: "#8B7355"), neon: Color(hex: "#B38B6D")),
    
    // ⚪️ GRAY/SILVER
    ThemePreset(id: "stone", title: "Stone", light: Color(hex: "EEF2F3"), dark: Color(hex: "8E9EAB"), neon: Color(hex: "B5C2CC")),
    ThemePreset(id: "silver0", title: "Silver", light: Color(hex: "#E8E8E8"), dark: Color(hex: "#757575"), neon: Color(hex: "#C0C0C0")),
    ThemePreset(id: "charcoal", title: "Charcoal", light: Color(hex: "#E0E0E0"), dark: Color(hex: "#36454F"), neon: Color(hex: "#708090")),
    ThemePreset(id: "slate", title: "Slate", light: Color(hex: "#E5E8EA"), dark: Color(hex: "#708090"), neon: Color(hex: "#9BB0C1"))
]

// MARK: - Theme Extensions

public extension Theme {
    /// Default gray theme for when no primary tag is available
    nonisolated(unsafe) static let `default` = Theme(
        id: "default",
        title: "Gray",
        light: Color.gray.opacity(0.3),
        dark: Color.gray,
        neon: Color.gray.opacity(0.7)
    )
    

    
    /// Creates a standard linear gradient for this theme
    var gradient: LinearGradient {
        LinearGradient(
            colors: [neon, dark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Creates a radial gradient for backgrounds
    var radialGradient: RadialGradient {
        RadialGradient(
            colors: [light, neon, dark],
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

public extension ThemePreset {
    /// Creates a standard linear gradient for this theme
    var gradient: LinearGradient {
        LinearGradient(
            colors: [neon, dark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
