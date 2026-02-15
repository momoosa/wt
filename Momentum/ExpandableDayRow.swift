//
//  ExpandableDayRow.swift
//  Momentum
//
//  Created by Mo Moosa on 11/02/2026.
//

import SwiftUI
import MomentumKit

struct ExpandableDayRow: View {
    let weekday: Int
    let name: String
    let isActive: Bool
    let minutes: Int
    let selectedTimes: Set<TimeOfDay>
    let themeColor: Color
    let isExpanded: Bool
    @FocusState.Binding var focusedField: GoalEditorView.Field?
    let onToggleDay: () -> Void
    let onUpdateMinutes: (Int) -> Void
    let onToggleTime: (TimeOfDay) -> Void
    let onToggleExpand: () -> Void
    
    /// Calculate appropriate text color based on background luminance
    private var textColor: Color {
        let luminance = themeColor.luminance ?? 0.5
        return luminance > 0.5 ? .black : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(spacing: 12) {
                // Day toggle button
                Button {
                    onToggleDay()
                } label: {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 40)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? themeColor : Color(.systemGray5))
                                .stroke(themeColor)
                        )
                        .foregroundStyle(isActive ? textColor : .secondary)
                }
                .buttonStyle(.plain)
                
                if isActive {
                    // Minutes input
                    HStack(spacing: 4) {
                        TextField("10", value: Binding(
                            get: { minutes },
                            set: onUpdateMinutes
                        ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray6))
                            )
                            .focused($focusedField, equals: .scheduleDay(weekday))
                        
                        Text("min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Tappable area to expand
                    Button {
                        onToggleExpand()
                    } label: {
                        HStack(spacing: 8) {
                            // Time summary
                            HStack(spacing: 2) {
                                ForEach(TimeOfDay.allCases.filter { selectedTimes.contains($0) }, id: \.self) { time in
                                    Image(systemName: time.icon)
                                        .font(.caption2)
                                        .foregroundStyle(themeColor.opacity(0.7))
                                }
                            }
                            
                            // Expand/collapse chevron
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Rest day")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                }
            }
            
            // Expanded time slots
            if isActive && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When during the day?")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 52)
                    
                    HStack(spacing: 4) {
                        ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                            Button {
                                onToggleTime(timeOfDay)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: timeOfDay.icon)
                                        .font(.caption)
                                    Text(timeOfDay.displayName)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedTimes.contains(timeOfDay) ? 
                                            themeColor.opacity(0.2) : 
                                            Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(selectedTimes.contains(timeOfDay) ? 
                                            themeColor : 
                                            Color.clear, 
                                            lineWidth: 2)
                                )
                                .foregroundStyle(selectedTimes.contains(timeOfDay) ? 
                                    themeColor : 
                                    .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 52)
                }
                .transition(.opacity)
            }
        }
    }
}


