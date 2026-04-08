//
//  IconPickerSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 06/04/2026.
//
import SwiftUI
import MomentumKit

// MARK: - Icon Picker Sheet
struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String?
    let themeColor: Color
    let onSelect: (String) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedCategory: IconCategory = .fitness
    
    var filteredIcons: [String] {
        let categoryIcons = selectedCategory.icons
        if searchText.isEmpty {
            return categoryIcons
        }
        return categoryIcons.filter { icon in
            icon.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(IconCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                themeColor: themeColor
                            ) {
                                withAnimation(AnimationPresets.quickSpring) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Icon grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(filteredIcons, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon,
                                themeColor: themeColor
                            ) {
                                onSelect(icon)
                            }
                        }
                    }
                    .padding()
                }
                .searchable(text: $searchText, prompt: "Search icons")
            }
            .navigationTitle("Choose Icon")
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
