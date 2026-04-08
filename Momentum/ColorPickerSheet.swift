//
//  ColorPickerSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 06/04/2026.
//

import SwiftUI
import MomentumKit

struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedColorPreset: ThemePreset?
    let onSelect: (ThemePreset) -> Void
    
    // Rainbow-sorted color order
    private var sortedPresets: [ThemePreset] {
        let order = [
            // Red family
            "red", "cherry", "crimson", "ruby", "coral", "salmon", "hot_pink", "rose",
            // Orange family
            "orange", "burnt_orange", "tangerine", "peach", "amber", "apricot",
            // Yellow family
            "yellow", "sunshine", "lemon", "gold", "mustard", "beige", "cream",
            // Green family
            "green", "emerald", "mint", "seafoam", "lime", "olive", "sage", "forest",
            // Blue family
            "blue", "navy", "sky_blue", "azure", "cyan", "teal", "turquoise", "mint_blue", "steel", "grey_blue", "cobalt",
            // Purple/Violet family
            "purple", "indigo", "violet", "lilac", "grape", "plum", "mauve", "lavender", "orchid", "magenta",
            // Pink family
            "pink0", "bubblegum", "fuchsia",
            // Brown/Neutral family
            "chocolate", "coffee", "taupe",
            // Gray family
            "silver0", "charcoal", "slate"
        ]
        
        return order.compactMap { id in
            themePresets.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(sortedPresets, id: \.id) { preset in
                        ColorPresetButton(
                            preset: preset,
                            isSelected: selectedColorPreset?.id == preset.id,
                            colorScheme: colorScheme
                        ) {
                            onSelect(preset)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ColorPresetButton: View {
    let preset: ThemePreset
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Color preview with gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [preset.neon, preset.dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.primary : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .shadow(color: preset.neon.opacity(0.3), radius: 6)
                
                // Color name
                Text(preset.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

