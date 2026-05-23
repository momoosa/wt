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
    
    private var sortedPresets: [ThemePreset] {
        themePresets
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
                    .fill(preset.gradient(for: colorScheme))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.primary : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .shadow(color: preset.color(for: colorScheme).opacity(0.3), radius: 6)
                
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

