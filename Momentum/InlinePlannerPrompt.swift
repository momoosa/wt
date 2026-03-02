//
//  InlinePlannerPrompt.swift
//  Momentum
//
//  Created by Mo Moosa on 01/03/2026.
//
import SwiftUI
import MomentumKit

struct InlinePlannerPrompt: View {
    @Binding var selectedThemes: Set<String>
    @Binding var availableTimeMinutes: Int
    let allThemes: [GoalTag]
    let onConfirm: () -> Void
    
    @State private var showingTimePicker = false
    @State private var showingThemePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Inline sentence with tappable sections
            HStack(spacing: 4) {
                Text("I have")
                    .foregroundStyle(.secondary)
                
                timeButton
                
                Text("free and want to work on something")
                    .foregroundStyle(.secondary)
                
                themeButton
            }
            .font(.body)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            
            // Generate button
            Button(action: onConfirm) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Plan")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.gradient)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Subviews
    
    private var timeButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingTimePicker.toggle()
                if showingTimePicker {
                    showingThemePicker = false
                }
            }
        } label: {
            Text(formatTime(availableTimeMinutes))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.15))
                )
        }
        .popover(isPresented: $showingTimePicker, arrowEdge: .top) {
            timePickerContent
                .presentationCompactAdaptation(.popover)
        }
    }
    
    private var themeButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingThemePicker.toggle()
                if showingThemePicker {
                    showingTimePicker = false
                }
            }
        } label: {
            Text(themeButtonText)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.15))
                )
        }
        .popover(isPresented: $showingThemePicker, arrowEdge: .top) {
            themePickerContent
                .presentationCompactAdaptation(.popover)
        }
    }
    
    private var timePickerContent: some View {
        VStack(spacing: 16) {
            // Quick time buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([30, 60, 90, 120, 180, 240], id: \.self) { minutes in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                availableTimeMinutes = minutes
                            }
                        } label: {
                            Text(formatTime(minutes))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(availableTimeMinutes == minutes ? .white : .purple)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(availableTimeMinutes == minutes ? Color.purple : Color.purple.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Custom slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("15 min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: Binding(
                        get: { Double(availableTimeMinutes) },
                        set: { availableTimeMinutes = Int($0) }
                    ), in: 15...480, step: 15)
                    .tint(.purple)
                    
                    Text("8 hrs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .frame(width: 350)
    }
    
    private var themePickerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Focus Themes")
                    .font(.headline)
                    .foregroundStyle(.purple)
                
                Spacer()
                
                if !selectedThemes.isEmpty {
                    Button("Clear All") {
                        withAnimation(.spring(response: 0.3)) {
                            selectedThemes.removeAll()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
            }
            
            if allThemes.isEmpty {
                Text("No active goals with themes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Text(selectedThemes.isEmpty ? "All themes will be considered" : "Planning will focus on selected themes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Tag cloud
                TagFlowLayout(spacing: 8) {
                    ForEach(allThemes, id: \.theme.id) { theme in
                        ThemeTag(
                            theme: theme,
                            isSelected: selectedThemes.contains(theme.theme.id)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedThemes.contains(theme.theme.id) {
                                    selectedThemes.remove(theme.theme.id)
                                } else {
                                    selectedThemes.insert(theme.theme.id)
                                }
                            }
                            
                            #if os(iOS)
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            #endif
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 350)
    }
    
    // MARK: - Helpers
    
    private var themeButtonText: String {
        if selectedThemes.isEmpty {
            return "anything"
        } else if selectedThemes.count == 1,
                  let theme = allThemes.first(where: { selectedThemes.contains($0.theme.id) }) {
            return theme.title.lowercased()
        } else {
            return "\(selectedThemes.count) themes"
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}
