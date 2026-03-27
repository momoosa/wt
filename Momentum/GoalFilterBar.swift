//
//  GoalFilterBar.swift
//  Momentum
//
//  Created by Mo Moosa on 10/02/2026.
//

import SwiftUI
import MomentumKit

/// Filter bar showing available filters as chips
struct GoalFilterBar: View {
    let filters: [ContentView.Filter]
    @Binding var activeFilter: ContentView.Filter
    let sessionCounts: [ContentView.FilterCount]
    var onFilterTap: ((ContentView.Filter) -> Void)? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(filters, id: \.id) { filter in
                    filterChip(for: filter)
                }
            }
            .padding([.leading, .trailing])
            .padding([.top, .bottom], 8)
        }
    }
    
    private func filterChip(for filter: ContentView.Filter) -> some View {
        let isSelected = filter.id == activeFilter.id
        
        // Calculate text color based on background luminance for better contrast
        let textColor: Color = {
            if isSelected {
                let luminance = filter.tintColor.luminance ?? 0.5
                return luminance > 0.5 ? .black : .white
            } else {
                return .primary
            }
        }()
        
        return filterText(for: filter)
            .foregroundStyle(textColor)
            .fontWeight(.semibold)
            .padding([.top, .bottom], 6)
            .padding([.leading, .trailing], 10)
            .frame(minWidth: 60.0, minHeight: 40)
            .background(
                Capsule()
                    .fill(isSelected ? filter.tintColor : Color.clear)
            )
            .glassEffect(in: Capsule())
            .onTapGesture {
                withAnimation {
                    activeFilter = filter
                }
                onFilterTap?(filter)
            }
    }
    
    @ViewBuilder
    private func filterText(for filter: ContentView.Filter) -> some View {
        let count = sessionCounts.first(where: { $0.filter.id == filter.id })?.count ?? 0
        HStack {
            Text(filter.text)
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}
