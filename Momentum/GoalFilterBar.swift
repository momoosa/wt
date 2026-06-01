//
//  SectionPillBar.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import MomentumKit

/// Pill bar showing contextual sections as tappable chips that scroll to sections
struct SectionPillBar: View {
    let sections: [ContextualSection]
    var visibleSectionType: ContextualSection.SectionType?
    var onSectionTapped: ((ContextualSection.SectionType) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollViewReader { pillProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sections) { section in
                        sectionPill(for: section)
                            .id(pillID(for: section.type))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: visibleSectionType) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    pillProxy.scrollTo(pillID(for: newValue), anchor: .center)
                }
            }
        }
    }
    
    private func sectionPill(for section: ContextualSection) -> some View {
        let isVisible = visibleSectionType == section.type
        let tint = section.type.iconColor
        
        return HStack(spacing: 4) {
            if let icon = section.type.icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(isVisible ? tint : .secondary)
            }
            Text(pillTitle(for: section.type))
                .font(.footnote)
                .fontWeight(.semibold)
            Text("\(section.sessions.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(
            Capsule()
                .fill(isVisible ? tint.opacity(0.3) : Color.clear)
        )
        .overlay(
            Capsule()
                .strokeBorder(isVisible ? tint.opacity(0.5) : .clear, lineWidth: 1.5)
        )
        .glassEffect(in: Capsule())
        .onTapGesture {
            HapticFeedbackManager.trigger(.light)
            onSectionTapped?(section.type)
        }
    }
    
    private func pillTitle(for type: ContextualSection.SectionType) -> String {
        switch type {
        case .recommendedNow:
            return "Top Picks"
        default:
            return type.title
        }
    }
    
    private func pillID(for type: ContextualSection.SectionType) -> String {
        "pill_\(type.hashValue)"
    }
}
