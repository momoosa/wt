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
    @State var selectedPeriod: TargetPeriod
    @State var daysPerWeek: Int
    @State var iconName: String
    @State var themeColor: Color
    @State private var activePicker: ActivePicker?
    @FocusState private var isNameFocused: Bool
    
    enum ActivePicker: Equatable {
        case value
        case unit
        case period
        case days
        case style
    }
    
    init(
        goalName: String = "Afternoon walk",
        targetValue: Int = 3,
        selectedUnit: TargetUnitType = .times,
        selectedPeriod: TargetPeriod = .week,
        daysPerWeek: Int = 5,
        iconName: String = "chart.line.uptrend.xyaxis",
        themeColor: Color = Color(red: 0.6, green: 0.85, blue: 0.75),
        initialActivePicker: ActivePicker? = nil
    ) {
        self._goalName = State(initialValue: goalName)
        self._targetValue = State(initialValue: targetValue)
        self._selectedUnit = State(initialValue: selectedUnit)
        self._selectedPeriod = State(initialValue: selectedPeriod)
        self._daysPerWeek = State(initialValue: daysPerWeek)
        self._iconName = State(initialValue: iconName)
        self._themeColor = State(initialValue: themeColor)
        self._activePicker = State(initialValue: initialActivePicker)
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
    
    enum TargetPeriod: String, CaseIterable {
        case day
        case week
        case month
        
        var label: String {
            switch self {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            }
        }
        
        var title: String {
            switch self {
            case .day: return "Daily"
            case .week: return "Weekly"
            case .month: return "Monthly"
            }
        }
        
        var subtitle: String {
            switch self {
            case .day: return "Every single day"
            case .week: return "Each calendar week"
            case .month: return "Each calendar month"
            }
        }
        
        var icon: String {
            switch self {
            case .day: return "sun.max"
            case .week: return "calendar"
            case .month: return "calendar.badge.clock"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: icon + label + style/done button
            headerRow
                .padding(.bottom, 20)
            
            if activePicker == .style {
                // Style picker replaces sentence content
                stylePicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Sentence-style editor
                sentenceEditor
                    .padding(.bottom, 12)
                
                // Summary text
                summaryText
                    .padding(.bottom, activePicker != nil ? 16 : 0)
                
                // Expandable pickers
                if activePicker == .unit {
                    unitPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                if activePicker == .period {
                    periodPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                if activePicker == .value || activePicker == .days {
                    valuePicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activePicker)
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        let isStyleMode = activePicker == .style
        
        return HStack(alignment: .center) {
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
                
                // Edit badge (hidden in style mode)
                if !isStyleMode {
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
            }
            
            Text("THE GOAL")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
            
            Spacer()
            
            Button {
                withAnimation {
                    if isStyleMode {
                        activePicker = nil
                    } else {
                        activePicker = .style
                    }
                }
            } label: {
                Text(isStyleMode ? "DONE" : "STYLE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundStyle(isStyleMode ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isStyleMode ? Color(.label) : Color.clear)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: isStyleMode ? 0 : 1)
                    )
            }
            .buttonStyle(.plain)
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
            
            if selectedUnit == .minutes {
                minutesSentence
            } else {
                defaultSentence
            }
        }
    }
    
    /// "3 times a week."
    private var defaultSentence: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            chipButton(
                text: "\(targetValue)",
                isActive: activePicker == .value,
                picker: .value
            )
            
            chipButton(
                text: selectedUnit.label,
                isActive: activePicker == .unit,
                picker: .unit
            )
            
            Text("a")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.secondary)
            
            chipButton(
                text: selectedPeriod.label,
                isActive: activePicker == .period,
                picker: .period
            )
        }
    }
    
    /// "30 min a day, 5 days a week."
    private var minutesSentence: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: "30 min a day,"
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                chipButton(
                    text: "\(targetValue)",
                    isActive: activePicker == .value,
                    picker: .value
                )
                
                chipButton(
                    text: "min",
                    isActive: activePicker == .unit,
                    picker: .unit
                )
                
                Text("a day,")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            
            // Line 2: "5 days a week."
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                chipButton(
                    text: "\(daysPerWeek)",
                    isActive: activePicker == .days,
                    picker: .days
                )
                
                Text("days a")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.secondary)
                
                chipButton(
                    text: selectedPeriod.label,
                    isActive: activePicker == .period,
                    picker: .period
                )
            }
        }
    }
    
    /// A tappable chip button used in sentences
    private func chipButton(text: String, isActive: Bool, picker: ActivePicker) -> some View {
        Button {
            withAnimation {
                activePicker = activePicker == picker ? nil : picker
            }
        } label: {
            Text(text)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.opacity(isActive ? 0.3 : 0.15))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Summary
    
    private var summaryText: some View {
        Group {
            if selectedUnit == .minutes {
                Text("**\(periodTotalFormatted)** across **\(daysPerWeek) days** a \(selectedPeriod.label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Surfaced on your **\(targetValue)** best-fit moments \(selectedPeriod == .day ? "today" : "each \(selectedPeriod.label)")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    /// Formats the total minutes for the selected period as "Xh Ym" or "Xm"
    private var periodTotalFormatted: String {
        let total = targetValue * daysPerWeek
        let hours = total / 60
        let mins = total % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    // MARK: - Unit Picker
    
    private var unitPicker: some View {
        VStack(spacing: 4) {
            ForEach(TargetUnitType.allCases, id: \.self) { unit in
                Button {
                    withAnimation {
                        selectedUnit = unit
                        activePicker = nil
                        // Reset to sensible defaults when switching units
                        if unit == .minutes && targetValue < 5 {
                            targetValue = 30
                        } else if unit != .minutes && targetValue > 7 {
                            targetValue = 3
                        }
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
    
    // MARK: - Period Picker
    
    private var periodPicker: some View {
        VStack(spacing: 4) {
            ForEach(TargetPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation {
                        selectedPeriod = period
                        activePicker = nil
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: period.icon)
                            .font(.body)
                            .foregroundStyle(period == selectedPeriod ? themeColor : .secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(period.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(period.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if period == selectedPeriod {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(period == selectedPeriod ? themeColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Value Picker
    
    private var valuePicker: some View {
        let isDaysPicker = activePicker == .days
        let currentValue = isDaysPicker ? daysPerWeek : targetValue
        let unitLabel = isDaysPicker ? "days" : selectedUnit.label
        let minValue = 1
        let maxValue = isDaysPicker ? 7 : (selectedUnit == .minutes ? 180 : 99)
        let step = selectedUnit == .minutes && !isDaysPicker ? 5 : 1
        
        return VStack(spacing: 16) {
            // Stepper row: minus / value / plus
            HStack(spacing: 16) {
                Spacer()
                
                Button {
                    let newValue = currentValue - step
                    if newValue >= minValue {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isDaysPicker { daysPerWeek = newValue } else { targetValue = newValue }
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(.label)))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(currentValue)")
                        .font(.system(size: 36, weight: .bold))
                        .contentTransition(.numericText(value: Double(currentValue)))
                    
                    Text(unitLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 80)
                
                Button {
                    let newValue = currentValue + step
                    if newValue <= maxValue {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isDaysPicker { daysPerWeek = newValue } else { targetValue = newValue }
                        }
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
            .animation(.snappy(duration: 0.2), value: currentValue)
            
            // Quick-select strip
            HStack(spacing: 0) {
                ForEach(quickSelectValues(for: activePicker), id: \.self) { value in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isDaysPicker { daysPerWeek = value } else { targetValue = value }
                        }
                    } label: {
                        Text("\(value)")
                            .font(.body)
                            .fontWeight(value == currentValue ? .bold : .regular)
                            .foregroundStyle(value == currentValue ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(value == currentValue ? Color(.label) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Style Picker
    
    /// Color swatches for the style picker
    private static let colorSwatches: [(Color, Color)] = [
        (Color(red: 0.95, green: 0.55, blue: 0.45), Color(red: 0.90, green: 0.45, blue: 0.40)),   // Warm red
        (Color(red: 0.95, green: 0.70, blue: 0.45), Color(red: 0.90, green: 0.60, blue: 0.35)),   // Orange
        (Color(red: 0.90, green: 0.80, blue: 0.55), Color(red: 0.80, green: 0.75, blue: 0.50)),   // Sand
        (Color(red: 0.60, green: 0.85, blue: 0.75), Color(red: 0.50, green: 0.80, blue: 0.70)),   // Mint (default)
        (Color(red: 0.55, green: 0.85, blue: 0.90), Color(red: 0.45, green: 0.75, blue: 0.85)),   // Cyan
        (Color(red: 0.70, green: 0.70, blue: 0.90), Color(red: 0.60, green: 0.60, blue: 0.85)),   // Lavender
        (Color(red: 0.70, green: 0.55, blue: 0.85), Color(red: 0.65, green: 0.45, blue: 0.80)),   // Purple
        (Color(red: 0.85, green: 0.55, blue: 0.75), Color(red: 0.80, green: 0.45, blue: 0.70)),   // Pink
    ]
    
    /// Icon options for the style picker
    private static let iconOptions: [String] = [
        "chart.line.uptrend.xyaxis", "face.smiling", "book.fill",
        "wrench.and.screwdriver.fill", "drop.fill", "trash.fill",
        "list.bullet.rectangle.portrait.fill", "heart.fill", "star.fill",
        "drop", "bolt.fill", "moon.fill",
    ]
    
    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            // COLOR section
            VStack(alignment: .leading, spacing: 10) {
                Text("COLOR")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(Array(Self.colorSwatches.enumerated()), id: \.offset) { index, swatch in
                        let isSelected = swatch.0 == themeColor
                        
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                themeColor = swatch.0
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [swatch.0, swatch.1],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(.label), lineWidth: isSelected ? 2.5 : 0)
                                        .padding(isSelected ? -1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // ICON section
            VStack(alignment: .leading, spacing: 10) {
                Text("ICON")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(Self.iconOptions, id: \.self) { icon in
                        let isSelected = icon == iconName
                        
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                iconName = icon
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? themeColor.opacity(0.15) : Color(.tertiarySystemFill))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    Image(systemName: icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(isSelected ? themeColor : .secondary)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.label), lineWidth: isSelected ? 2 : 0)
                                        .padding(isSelected ? -1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    /// Returns appropriate quick-select values based on picker mode
    private func quickSelectValues(for picker: ActivePicker?) -> [Int] {
        if picker == .days {
            // Days per week: show all 7 options
            return Array(1...7)
        } else if selectedUnit == .minutes {
            // Minutes: show common daily durations
            return [10, 15, 20, 30, 45, 60]
        } else {
            // Times/Days: centered range
            let center = targetValue
            let start = max(center - 2, 1)
            let end = start + 4
            return Array(start...end)
        }
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

#Preview("Card - Period Picker") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard(initialActivePicker: .period)
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
            
            GoalEditorCard(initialActivePicker: .unit)
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}

#Preview("Card - Minutes Mode") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard(
                goalName: "Morning run",
                targetValue: 30,
                selectedUnit: .minutes,
                daysPerWeek: 5,
                iconName: "figure.run",
                themeColor: .orange
            )
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}
#Preview("Card - Style Picker") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard(initialActivePicker: .style)
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}

#Preview("Card - Minutes with Days Picker") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            GoalEditorSectionHeader(number: 1, title: "Goal & target")
                .padding(.horizontal, 20)
            
            GoalEditorCard(
                goalName: "Morning run",
                targetValue: 30,
                selectedUnit: .minutes,
                daysPerWeek: 5,
                iconName: "figure.run",
                themeColor: .orange,
                initialActivePicker: .days
            )
                .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
    .background(Color(.secondarySystemBackground))
}

