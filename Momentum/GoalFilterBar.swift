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
    let sessionCounts: [ContentView.Filter: Int]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(filters, id: \.self) { filter in
                    filterChip(for: filter)
                }
            }
            .padding([.leading, .trailing])
            .padding([.top, .bottom], 8)
        }
    }
    
    private func filterChip(for filter: ContentView.Filter) -> some View {
        let isSelected = filter.id == activeFilter.id
        
        return filterText(for: filter)
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
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
            }
    }
    
    @ViewBuilder
    private func filterText(for filter: ContentView.Filter) -> some View {
        let count = sessionCounts[filter] ?? 0
        HStack {
            Text(filter.text)
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}
