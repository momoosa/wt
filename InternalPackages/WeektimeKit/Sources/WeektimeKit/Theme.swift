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


@MainActor public let themes: [Theme] = [
    // 🔴 RED
    Theme(id: "red", title: "Red", light: Color(hex: "#FFCCCC"), dark: Color(hex: "#8B0000"), neon: Color(hex: "#FF4C4C")),
    Theme(id: "cherry", title: "Cherry", light: Color(hex: "#FFC1CC"), dark: Color(hex: "#990000"), neon: Color(hex: "#FF0033")),
    Theme(id: "coral", title: "Coral", light: Color(hex: "#F7C6B6"), dark: Color(hex: "#8B0000"), neon: Color(hex: "#FF0033")),
    Theme(id: "hot_pink", title: "Hot Pink", light: Color(hex: "#FFB6C1"), dark: Color(hex: "#C71585"), neon: Color(hex: "#FF69B4")),
    
    // 🟠 ORANGE
    Theme(id: "orange", title: "Orange", light: Color(hex: "#FFDAB9"), dark: Color(hex: "#FF8C00"), neon: Color(hex: "#FF6A00")),
    Theme(id: "burnt_orange", title: "Burnt Orange", light: Color(hex: "#FFDAB3"), dark: Color(hex: "#FF4500"), neon: Color(hex: "#FF6A00")),
    Theme(id: "tangerine", title: "Tangerine", light: Color(hex: "#FFE4B5"), dark: Color(hex: "#CD5700"), neon: Color(hex: "#FFA500")),
    Theme(id: "peach", title: "Peach", light: Color(hex: "#FFDAB3"), dark: Color(hex: "#8B4000"), neon: Color(hex: "#FFA07A")),

    // 🟡 YELLOW
    Theme(id: "yellow", title: "Yellow", light: Color(hex: "#FFFACD"), dark: Color(hex: "#DAA520"), neon: Color(hex: "#FFFF33")),

    Theme(id: "sunshine", title: "Sunshine", light: Color(hex: "#FFF9B1"), dark: Color(hex: "#DAA520"), neon: Color(hex: "#FFFF33")),
    Theme(id: "lemon", title: "Lemon", light: Color(hex: "#FFFACD"), dark: Color(hex: "#556B2F"), neon: Color(hex: "#EEFF41")),
    Theme(id: "gold", title: "Gold", light: Color(hex: "#FFF8DC"), dark: Color(hex: "#B8860B"), neon: Color(hex: "#FFD700")),
    Theme(id: "beige", title: "Beige", light: Color(hex: "#F5F5DC"), dark: Color(hex: "#8B4513"), neon: Color(hex: "#FFEBCD")),

    // 🟢 GREEN
    Theme(id: "green", title: "Green", light: Color(hex: "#D8EFD5"), dark: Color(hex: "#228B22"), neon: Color(hex: "#A3E4A3")),
    Theme(id: "mint", title: "Mint", light: Color(hex: "#AAF0D1"), dark: Color(hex: "#008080"), neon: Color(hex: "#00FFC6")),
    Theme(id: "seafoam", title: "Seafoam", light: Color(hex: "#CFFFE5"), dark: Color(hex: "#8FBC8F"), neon: Color(hex: "#00FA9A")),
    Theme(id: "lime", title: "Lime", light: Color(hex: "#D9FFB3"), dark: Color(hex: "#6B8E23"), neon: Color(hex: "#BFFF00")),

    // 🔵 BLUE
    Theme(id: "blue", title: "Blue", light: Color(hex: "#BFEFFF"), dark: Color(hex: "#003366"), neon: Color(hex: "#00BFFF")),
    Theme(id: "sky_blue", title: "Sky Blue", light: Color(hex: "#C0EFFF"), dark: Color(hex: "#4682B4"), neon: Color(hex: "#00BFFF")),
    Theme(id: "cyan", title: "Cyan", light: Color(hex: "#B2FFFF"), dark: Color(hex: "#008B8B"), neon: Color(hex: "#00FFFF")),
    Theme(id: "teal", title: "Teal", light: Color(hex: "#B2FFFF"), dark: Color(hex: "#006666"), neon: Color(hex: "#00FFFF")),
    Theme(id: "mint_blue", title: "Mint Blue", light: Color(hex: "#BFFFEA"), dark: Color(hex: "#5F9EA0"), neon: Color(hex: "#00FFC6")),
    Theme(id: "grey_blue", title: "Grey Blue", light: Color(hex: "#DDEAF6"), dark: Color(hex: "#6A5ACD"), neon: Color(hex: "#00BFFF")),


    // 🟣 INDIGO/VIOLET
    Theme(id: "purple", title: "Purple", light: Color(hex: "#D6CADD"), dark: Color(hex: "#4B0082"), neon: Color(hex: "#D100FF")),
    Theme(id: "lilac", title: "Lilac", light: Color(hex: "#E6DAF5"), dark: Color(hex: "#5D3A9B"), neon: Color(hex: "#FF00FF")),
    Theme(id: "grape", title: "Grape", light: Color(hex: "#E0BBE4"), dark: Color(hex: "#5D3FD3"), neon: Color(hex: "#D100FF")),
    Theme(id: "plum", title: "Plum", light: Color(hex: "#DDA0DD"), dark: Color(hex: "#9400D3"), neon: Color(hex: "#FF00FF")),
    Theme(id: "mauve", title: "Mauve", light: Color(hex: "#E0B0FF"), dark: Color(hex: "#9932CC"), neon: Color(hex: "#DA70D6")),
    Theme(id: "pink0", title: "Pink", light: Color(hex: "#FFB6C1"), dark: Color(hex: "#C71585"), neon: Color(hex: "#FF69B4")),

    Theme(id: "silver0", title: "Silver", light: Color(hex: "#E1DFE1"), dark: Color(hex: "#C0BFC0"), neon: Color(hex: "#F5F5F5"))

    
]


#Preview {
    ScrollView {
        VStack {
            ForEach(themes, id: \.id) { color in
                
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
            ForEach(themes, id: \.id) { color in
                
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
