//
//  SectionPillBar.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import MomentumKit

/// Pill bar showing contextual sections as toggleable chips
struct SectionPillBar: View {
    let sections: [ContextualSection]
    @Binding var expandedSections: Set<ContextualSection.SectionType>
    var scrollProxy: ScrollViewProxy?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sections) { section in
                    sectionPill(for: section)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func sectionPill(for section: ContextualSection) -> some View {
        let isExpanded = expandedSections.contains(section.type)
        let tint = section.type.iconColor
        
        return HStack(spacing: 4) {
            if let icon = section.type.icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(isExpanded ? tint : .secondary)
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
                .fill(isExpanded ? tint.opacity(0.2) : Color.clear)
        )
        .glassEffect(in: Capsule())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isExpanded {
                    // Collapse the section
                    expandedSections.remove(section.type)
                } else {
                    // Expand and scroll to it
                    expandedSections.insert(section.type)
                    scrollProxy?.scrollTo(section.type, anchor: .top)
                }
            }
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
}
