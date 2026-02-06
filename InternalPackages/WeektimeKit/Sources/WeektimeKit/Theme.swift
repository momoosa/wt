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
    public func toTheme() -> Theme {
        Theme(id: id, title: title, light: light, dark: dark, neon: neon)
    }
}

public let themePresets: [ThemePreset] = [
    // 🔴 RED
    ThemePreset(id: "red", title: "Red", light: Color(hex: "#FFCCCC"), dark: Color(hex: "#8B0000"), neon: Color(hex: "#FF4C4C")),
    ThemePreset(id: "cherry", title: "Cherry", light: Color(hex: "#FFC1CC"), dark: Color(hex: "#990000"), neon: Color(hex: "#FF0033")),
    ThemePreset(id: "coral", title: "Coral", light: Color(hex: "#F7C6B6"), dark: Color(hex: "#8B0000"), neon: Color(hex: "#FF0033")),
    ThemePreset(id: "hot_pink", title: "Hot Pink", light: Color(hex: "#FFB6C1"), dark: Color(hex: "#C71585"), neon: Color(hex: "#FF69B4")),
    
    // 🟠 ORANGE
    ThemePreset(id: "orange", title: "Orange", light: Color(hex: "#FFDAB9"), dark: Color(hex: "#FF8C00"), neon: Color(hex: "#FF6A00")),
    ThemePreset(id: "burnt_orange", title: "Burnt Orange", light: Color(hex: "#FFDAB3"), dark: Color(hex: "#FF4500"), neon: Color(hex: "#FF6A00")),
    ThemePreset(id: "tangerine", title: "Tangerine", light: Color(hex: "#FFE4B5"), dark: Color(hex: "#CD5700"), neon: Color(hex: "#FFA500")),
    ThemePreset(id: "peach", title: "Peach", light: Color(hex: "#FFDAB3"), dark: Color(hex: "#8B4000"), neon: Color(hex: "#FFA07A")),

    // 🟡 YELLOW
    ThemePreset(id: "yellow", title: "Yellow", light: Color(hex: "#FFFACD"), dark: Color(hex: "#DAA520"), neon: Color(hex: "#FFFF33")),

    ThemePreset(id: "sunshine", title: "Sunshine", light: Color(hex: "#FFF9B1"), dark: Color(hex: "#DAA520"), neon: Color(hex: "#FFFF33")),
    ThemePreset(id: "lemon", title: "Lemon", light: Color(hex: "#FFFACD"), dark: Color(hex: "#556B2F"), neon: Color(hex: "#EEFF41")),
    ThemePreset(id: "gold", title: "Gold", light: Color(hex: "#FFF8DC"), dark: Color(hex: "#B8860B"), neon: Color(hex: "#FFD700")),
    ThemePreset(id: "beige", title: "Beige", light: Color(hex: "#F5F5DC"), dark: Color(hex: "#8B4513"), neon: Color(hex: "#FFEBCD")),

    // 🟢 GREEN
    ThemePreset(id: "green", title: "Green", light: Color(hex: "#D8EFD5"), dark: Color(hex: "#228B22"), neon: Color(hex: "#A3E4A3")),
    ThemePreset(id: "mint", title: "Mint", light: Color(hex: "#AAF0D1"), dark: Color(hex: "#008080"), neon: Color(hex: "#00FFC6")),
    ThemePreset(id: "seafoam", title: "Seafoam", light: Color(hex: "#CFFFE5"), dark: Color(hex: "#8FBC8F"), neon: Color(hex: "#00FA9A")),
    ThemePreset(id: "lime", title: "Lime", light: Color(hex: "#D9FFB3"), dark: Color(hex: "#6B8E23"), neon: Color(hex: "#BFFF00")),

    // 🔵 BLUE
    ThemePreset(id: "blue", title: "Blue", light: Color(hex: "#BFEFFF"), dark: Color(hex: "#003366"), neon: Color(hex: "#00BFFF")),
    ThemePreset(id: "sky_blue", title: "Sky Blue", light: Color(hex: "#C0EFFF"), dark: Color(hex: "#4682B4"), neon: Color(hex: "#00BFFF")),
    ThemePreset(id: "cyan", title: "Cyan", light: Color(hex: "#B2FFFF"), dark: Color(hex: "#008B8B"), neon: Color(hex: "#00FFFF")),
    ThemePreset(id: "teal", title: "Teal", light: Color(hex: "#B2FFFF"), dark: Color(hex: "#006666"), neon: Color(hex: "#00FFFF")),
    ThemePreset(id: "mint_blue", title: "Mint Blue", light: Color(hex: "#BFFFEA"), dark: Color(hex: "#5F9EA0"), neon: Color(hex: "#00FFC6")),
    ThemePreset(id: "grey_blue", title: "Grey Blue", light: Color(hex: "#DDEAF6"), dark: Color(hex: "#6A5ACD"), neon: Color(hex: "#00BFFF")),


    // 🟣 INDIGO/VIOLET
    ThemePreset(id: "purple", title: "Purple", light: Color(hex: "#D6CADD"), dark: Color(hex: "#4B0082"), neon: Color(hex: "#D100FF")),
    ThemePreset(id: "lilac", title: "Lilac", light: Color(hex: "#E6DAF5"), dark: Color(hex: "#5D3A9B"), neon: Color(hex: "#FF00FF")),
    ThemePreset(id: "grape", title: "Grape", light: Color(hex: "#E0BBE4"), dark: Color(hex: "#5D3FD3"), neon: Color(hex: "#D100FF")),
    ThemePreset(id: "plum", title: "Plum", light: Color(hex: "#DDA0DD"), dark: Color(hex: "#9400D3"), neon: Color(hex: "#FF00FF")),
    ThemePreset(id: "mauve", title: "Mauve", light: Color(hex: "#E0B0FF"), dark: Color(hex: "#9932CC"), neon: Color(hex: "#DA70D6")),
    ThemePreset(id: "pink0", title: "Pink", light: Color(hex: "#FFB6C1"), dark: Color(hex: "#C71585"), neon: Color(hex: "#FF69B4")),

    ThemePreset(id: "silver0", title: "Silver", light: Color(hex: "#E1DFE1"), dark: Color(hex: "#C0BFC0"), neon: Color(hex: "#F5F5F5"))

    
]

// MARK: - Theme Extensions

public extension Theme {
    /// Calculates optimal text color (black/white) based on background luminance
    var textColor: Color {
        let colors = [light, neon, dark]
        let luminances = colors.compactMap { $0.luminance }
        let averageLuminance = luminances.isEmpty ? 0.5 : luminances.reduce(0, +) / Double(luminances.count)
        return averageLuminance > 0.5 ? .black : .white
    }
    
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
    /// Calculates optimal text color (black/white) based on background luminance
    var textColor: Color {
        let colors = [light, neon, dark]
        let luminances = colors.compactMap { $0.luminance }
        let averageLuminance = luminances.isEmpty ? 0.5 : luminances.reduce(0, +) / Double(luminances.count)
        return averageLuminance > 0.5 ? .black : .white
    }
    
    /// Creates a standard linear gradient for this theme
    var gradient: LinearGradient {
        LinearGradient(
            colors: [neon, dark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}


#Preview {
    ScrollView {
        VStack {
            ForEach(themePresets, id: \.id) { color in
                
                RoundedRectangle(cornerRadius: 12.5)
                    .fill(color.light.opacity(0.25))
                    .frame(height: 44)
                    .overlay {
                        Text(color.title)
                            .font(.headline)
                            .foregroundStyle(color.dark)
                    }
            }
        }
        
    }
}
#Preview {
    ScrollView {
        VStack {
            ForEach(themePresets, id: \.id) { color in
                
                RoundedRectangle(cornerRadius: 12.5)
                    .fill(color.light.opacity(0.03))
                    .frame(height: 44)
                    .overlay {
                        Text(color.title)
                            .font(.headline)
                            .foregroundStyle(color.neon)
                    }
            }
        }
        
    }
    .preferredColorScheme(.dark)
}
