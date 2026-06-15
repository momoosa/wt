//
//  GoalEditorCard.swift
//  Momentum
//
//  A sentence-style goal editor card.
//

import SwiftUI

struct GoalEditorCard: View {
    @State var goalName: String
    @State var targetValue: Int
    @State var selectedUnit: TargetUnitType
    @State private var showingUnitPicker: Bool
    @State private var showingValuePicker: Bool
    @FocusState private var isNameFocused: Bool
    
    // Icon
    var iconName: String
    var themeColor: Color
    
    init(
        goalName: String = "Afternoon walk",
        targetValue: Int = 3,
        selectedUnit: TargetUnitType = .times,
        iconName: String = "chart.line.uptrend.xyaxis",
        themeColor: Color = Color(red: 0.6, green: 0.85, blue: 0.75),
        initialShowingUnitPicker: Bool = false,
        initialShowingValuePicker: Bool = false
    ) {
        self._goalName = State(initialValue: goalName)
        self._targetValue = State(initialValue: targetValue)
        self._selectedUnit = State(initialValue: selectedUnit)
        self._showingUnitPicker = State(initialValue: initialShowingUnitPicker)
        self._showingValuePicker = State(initialValue: initialShowingValuePicker)
        self.iconName = iconName
        self.themeColor = themeColor
    }
    
    enum TargetUnitType: String, CaseIterable {
        case times
        case days
        case minutes
        
        var label: String {
            switch self {
            case .times: return "times"
            case .days: return "days"
            case .minutes: return "minutes"
            }
        }
        
        var title: String {
            switch self {
            case .times: return "Times"
            case .days: return "Days"
            case .minutes: return "Minutes"
            }
        }
        
        var subtitle: String {
            switch self {
            case .times: return "Sessions a week"
            case .days: return "Distinct days a week"
            case .minutes: return "Total time a week"
            }
        }
        
        var icon: String {
            switch self {
            case .times: return "arrow.counterclockwise"
            case .days: return "calendar"
            case .minutes: return "clock"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: icon + label + style button
            headerRow
                .padding(.bottom, 20)
            
            // Sentence-style editor
            sentenceEditor
                .padding(.bottom, 12)
            
            // Summary text
            summaryText
                .padding(.bottom, showingUnitPicker || showingValuePicker ? 16 : 0)
            
            // Expandable pickers
            if showingUnitPicker {
                unitPicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if showingValuePicker {
                valuePicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showingUnitPicker)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showingValuePicker)
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack(alignment: .center) {
            // Icon with edit badge
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeColor.opacity(0.3))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(themeColor.opacity(0.8))
                    }
                
                // Edit badge
                Circle()
                    .fill(Color(.label))
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(.systemBackground))
                    }
                    .offset(x: 4, y: 4)
            }
            
            Text("THE GOAL")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
            
            Spacer()
            
            Button {
                // Style action
            } label: {
                Text("STYLE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Sentence Editor
    
    private var sentenceEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Goal name line: "Afternoon walk —"
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                TextField("Goal name", text: $goalName)
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .focused($isNameFocused)
                    .textFieldStyle(.plain)
                
                Text(" —")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .layoutPriority(1)
            }
            
            // Target line: "3 times a week."
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Number chip
                Button {
                    withAnimation {
                        showingValuePicker.toggle()
                        showingUnitPicker = false
                    }
                } label: {
                    Text("\(targetValue)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeColor.opacity(showingValuePicker ? 0.3 : 0.15))
                        )
                }
                .buttonStyle(.plain)
                
                // Unit chip
                Button {
                    withAnimation {
                        showingUnitPicker.toggle()
                        showingValuePicker = false
                    }
                } label: {
                    Text(selectedUnit.label)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeColor.opacity(showingUnitPicker ? 0.3 : 0.15))
                        )
                }
                .buttonStyle(.plain)
                
                Text("a week.")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Summary
    
    private var summaryText: some View {
        (Text("Surfaced on your ")
         + Text("\(targetValue)").fontWeight(.bold)
         + Text(" best-fit moments each week"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    // MARK: - Unit Picker
    
    private var unitPicker: some View {
        VStack(spacing: 4) {
            ForEach(TargetUnitType.allCases, id: \.self) { unit in
                Button {
                    withAnimation {
                        selectedUnit = unit
                        showingUnitPicker = false
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: unit.icon)
                            .font(.body)
                            .foregroundStyle(unit == selectedUnit ? themeColor : .secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(unit.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(unit.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if unit == selectedUnit {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(unit == selectedUnit ? themeColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Value Picker
    
    private var valuePicker: some View {
        VStack(spacing: 16) {
            // Stepper row: minus / value / plus
            HStack(spacing: 16) {
                Spacer()
                
                Button {
                    if targetValue > 1 {
                        targetValue -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(.label)))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(targetValue)")
                        .font(.system(size: 36, weight: .bold))
                        .contentTransition(.numericText(value: Double(targetValue)))
                    
                    Text(selectedUnit.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 80)
                
                Button {
                    if targetValue < 99 {
                        targetValue += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(themeColor.opacity(0.25)))
                }
                
                Spacer()
            }
            .animation(.snappy(duration: 0.2), value: targetValue)
            
            // Quick-select number strip
            HStack(spacing: 0) {
                ForEach(quickSelectValues, id: \.self) { value in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            targetValue = value
                        }
                    } label: {
                        Text("\(value)")
                            .font(.body)
                            .fontWeight(value == targetValue ? .bold : .regular)
                            .foregroundStyle(value == targetValue ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(value == targetValue ? Color(.label) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    /// Returns a range of values centered around the current targetValue
    private var quickSelectValues: [Int] {
        let center = targetValue
        let start = max(center - 2, 1)
        let end = start + 4
        return Array(start...end)
    }
}

// MARK: - Section Header (external)

struct GoalEditorSectionHeader: View {
    let number: Int
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(.label)))
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

#Preview("Goal Editor Card") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard()
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}

#Preview("Card - Expanded Unit Picker") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard(initialShowingUnitPicker: true)
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}

#Preview("Card - Expanded Value Picker") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard(initialShowingValuePicker: true)
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}
