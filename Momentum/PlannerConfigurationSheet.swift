//
//  PlannerConfigurationSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 20/01/2026.
//
import SwiftUI
import MomentumKit

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
    let theme: GoalTag
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
    let allThemes: [GoalTag]
    let animation: Namespace.ID
    let onConfirm: () -> Void
    
    @State private var showingTimePicker = false
    @State private var showingThemePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                
                // Sentence with tappable parts
                sentenceView
                    .padding(.horizontal)
                
                Spacer()
                
                confirmButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .navigationTransition(
            .zoom(sourceID: "plannerButton", in: animation)
        )
    }
    
    // MARK: - Subviews
    
    private var sentenceView: some View {
        TagFlowLayout(spacing: 8) {
            Text("I have")
                .foregroundStyle(.primary)
            
            if showingTimePicker {
                timePickerInline
            } else {
                timeButton
            }
            
            Text("free and want to work on")
                .foregroundStyle(.primary)
            
            if showingThemePicker {
                themePickerInline
            } else {
                themeButton
            }
        }
        .font(.title3)
    }
    
    private var timePickerInline: some View {
        // Time options: 5, 15, 30 mins, 1-6 hours
        let timeOptions = [5, 15, 30, 60, 120, 180, 240, 300, 360]
        
        return ForEach(timeOptions, id: \.self) { minutes in
            Button {
                withAnimation(.spring(response: 0.3)) {
                    availableTimeMinutes = minutes
                    showingTimePicker = false
                }
            } label: {
                Text(formatTime(minutes))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(availableTimeMinutes == minutes ? .white : .purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(availableTimeMinutes == minutes ? Color.purple : Color.purple.opacity(0.1))
                    )
            }
        }
    }
    
    private var timeButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingTimePicker = true
            }
        } label: {
            Text(formatTime(availableTimeMinutes))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.purple)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.3), lineWidth: 2)
                )
        }
    }
    
    private var themePickerInline: some View {
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
    
    private var themeButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showingThemePicker = true
            }
        } label: {
            Text(themeButtonText)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.purple)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.3), lineWidth: 2)
                )
        }
    }
    
    private var confirmButton: some View {
        Button {
            #if os(iOS)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            #endif
            
            onConfirm()
        } label: {
                Text("Generate Plan")
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
