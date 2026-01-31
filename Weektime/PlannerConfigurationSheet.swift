//
//  PlannerConfigurationSheet.swift
//  Weektime
//
//  Created by Mo Moosa on 20/01/2026.
//
import SwiftUI
import WeektimeKit

// MARK: - FlowLayout
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - ThemeTag
struct ThemeTag: View {
    let theme: GoalTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(theme.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : theme.theme.dark)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.theme.dark : theme.theme.light.opacity(0.5))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(theme.theme.dark.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PlannerConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedThemes: Set<String>
    @Binding var availableTimeMinutes: Int
    let allThemes: [GoalTheme]
    let animation: Namespace.ID
    let onConfirm: () -> Void
    
    @State private var showingTimePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                    // Available Time Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Available Time", systemImage: "clock.fill")
                            .font(.headline)
                            .foregroundStyle(.purple)
                        
                        HStack {
                            Button {
                                showingTimePicker.toggle()
                            } label: {
                                HStack {
                                    Text(formatTime(availableTimeMinutes))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .rotationEffect(.degrees(showingTimePicker ? 90 : 0))
                                }
                                .foregroundStyle(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                        }
                        
                        if showingTimePicker {
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
//                                                            .fill(availableTimeMinutes == minutes ? Color.purple.gradient : Color.purple.opacity(0.1))
                                                    )
                                            }
                                        }
                                    }
                                }
//                                
//                                // Custom slider
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
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Theme Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Focus Themes", systemImage: "tag.fill")
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
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        } else {
                            Text(selectedThemes.isEmpty ? "All themes will be considered" : "Planning will focus on selected themes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                            
                            // Tag cloud
                            FlowLayout(spacing: 8) {
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
                    .padding(.horizontal)
                    
                    Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Confirm button at bottom
                Button {
                    #if os(iOS)
                    let impact = UINotificationFeedbackGenerator()
                    impact.notificationOccurred(.success)
                    #endif
                    
                    onConfirm()
                } label: {
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
                .padding()
                .background(.thinMaterial)
            }
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
