//
//  GoalEditorCard.swift
//  Momentum
//
//  A sentence-style goal editor card.
//

import SwiftUI
import MomentumKit

struct GoalEditorCard: View {
    @State var goalName: String
    @State var targetValue: Int
    @State var selectedUnit: TargetUnitType
    @State var selectedPeriod: TargetPeriod
    @State var iconName: String
    @State var themeColor: Color
    @State var selectedThemeID: String
    @State private var activePicker: ActivePicker?
    @Binding var isExpanded: Bool
    @Namespace private var cardAnimation
    @FocusState private var isNameFocused: Bool
    
    enum ActivePicker: Equatable {
        case value
        case unit
        case period
        case style
    }
    
    /// Binding init — caller owns the expanded state
    init(
        goalName: String = "Afternoon walk",
        targetValue: Int = 3,
        selectedUnit: TargetUnitType = .times,
        selectedPeriod: TargetPeriod = .week,
        iconName: String = "chart.line.uptrend.xyaxis",
        themeColor: Color = Color(red: 0.6, green: 0.85, blue: 0.75),
        selectedThemeID: String = "palette_10",
        isExpanded: Binding<Bool>,
        initialActivePicker: ActivePicker? = nil
    ) {
        self._goalName = State(initialValue: goalName)
        self._targetValue = State(initialValue: targetValue)
        self._selectedUnit = State(initialValue: selectedUnit)
        self._selectedPeriod = State(initialValue: selectedPeriod)
        self._iconName = State(initialValue: iconName)
        self._themeColor = State(initialValue: themeColor)
        self._selectedThemeID = State(initialValue: selectedThemeID)
        self._isExpanded = isExpanded
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
            // Minimised row — always present, tappable when collapsed
            minimisedRow
            
            // Expanded content — slides in/out
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(isExpanded ? 20 : 16)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activePicker)
    }
    
    // MARK: - Minimised Row
    
    private var minimisedRow: some View {
        Button {
            if !isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded = true
                }
            }
        } label: {
            HStack(spacing: 14) {
                // Icon — shared between states
                RoundedRectangle(cornerRadius: isExpanded ? 14 : 12)
                    .fill(themeColor.opacity(0.3))
                    .frame(width: isExpanded ? 52 : 44, height: isExpanded ? 52 : 44)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: isExpanded ? 22 : 18, weight: .medium))
                            .foregroundStyle(themeColor.opacity(0.8))
                    }
                    .matchedGeometryEffect(id: "icon", in: cardAnimation)
                
                if isExpanded {
                    // Expanded: "THE GOAL" label + collapse + style
                    Text("THE GOAL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                        .matchedGeometryEffect(id: "label", in: cardAnimation)
                    
                    // Collapse button
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            activePicker = nil
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .matchedGeometryEffect(id: "chevron", in: cardAnimation)
                    
                    Spacer()
                    
                    styleButton
                } else {
                    // Collapsed: goal name + chevron
                    Text(goalName.isEmpty ? "Goal name" : goalName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(goalName.isEmpty ? .secondary : .primary)
                        .matchedGeometryEffect(id: "label", in: cardAnimation)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .matchedGeometryEffect(id: "chevron", in: cardAnimation)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, isExpanded ? 20 : 0)
    }
    
    // MARK: - Style Button
    
    private var styleButton: some View {
        let isStyleMode = activePicker == .style
        
        return Button {
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
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        Group {
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
                
                if activePicker == .value {
                    valuePicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
            
            defaultSentence
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
        Text("Surfaced on your **\(targetValue)** best-fit moments \(selectedPeriod == .day ? "today" : "each \(selectedPeriod.label)")")
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
        let minValue = 1
        let maxValue = selectedUnit == .minutes ? 180 : 99
        let step = selectedUnit == .minutes ? 5 : 1
        
        return VStack(spacing: 16) {
            // Stepper row: minus / value / plus
            HStack(spacing: 16) {
                Spacer()
                
                Button {
                    let newValue = targetValue - step
                    if newValue >= minValue {
                        withAnimation(.snappy(duration: 0.2)) {
                            targetValue = newValue
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
                    let newValue = targetValue + step
                    if newValue <= maxValue {
                        withAnimation(.snappy(duration: 0.2)) {
                            targetValue = newValue
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
            .animation(.snappy(duration: 0.2), value: targetValue)
            
            // Quick-select strip
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
    
    // MARK: - Style Picker
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Icon options for the style picker — curated from IconCategory
    private static let iconOptions: [String] = [
        // Fitness
        "figure.run", "figure.walk", "figure.yoga", "dumbbell.fill",
        "bicycle", "figure.pool.swim", "figure.hiking", "shoeprints.fill",
        // Wellness
        "heart.fill", "sparkles", "leaf.fill", "drop.fill",
        "sun.max.fill", "moon.stars.fill", "bed.double.fill", "brain.fill",
        // Learning
        "book.fill", "graduationcap.fill", "lightbulb.fill", "pencil",
        // Creative
        "paintbrush.fill", "camera.fill", "music.note", "guitars.fill",
        // Productivity
        "checkmark.circle.fill", "list.bullet", "calendar", "clock.fill",
        "flag.fill", "star.fill", "target", "chart.line.uptrend.xyaxis",
        // Home
        "house.fill", "fork.knife", "cup.and.saucer.fill", "mug.fill",
        // Social
        "person.2.fill", "bubble.fill", "gift.fill", "party.popper.fill",
        // Nature
        "tree.fill", "flower.fill", "pawprint.fill", "flame.fill",
    ]
    
    private var stylePicker: some View {
        let rows = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)]
        
        return VStack(alignment: .leading, spacing: 20) {
            // COLOR section
            VStack(alignment: .leading, spacing: 10) {
                Text("COLOR")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        ForEach(ThemeStore.presets, id: \.id) { preset in
                            let presetColor = preset.color(for: colorScheme)
                            let isSelected = selectedThemeID == preset.id
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedThemeID = preset.id
                                    themeColor = presetColor
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(preset.gradient(for: colorScheme))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.label), lineWidth: isSelected ? 2.5 : 0)
                                            .padding(isSelected ? -1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 96)
            }
            
            // ICON section
            VStack(alignment: .leading, spacing: 10) {
                Text("ICON")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        ForEach(Self.iconOptions, id: \.self) { icon in
                            let isSelected = icon == iconName
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    iconName = icon
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? themeColor.opacity(0.15) : Color(.tertiarySystemFill))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(isSelected ? themeColor : .secondary)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.label), lineWidth: isSelected ? 2 : 0)
                                            .padding(isSelected ? -1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 96)
            }
        }
    }
    
    /// Returns appropriate quick-select values based on unit type
    private var quickSelectValues: [Int] {
        if selectedUnit == .minutes {
            return [10, 15, 20, 30, 45, 60]
        } else {
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

// MARK: - Recommend When Card

struct RecommendWhenCard: View {
    @State private var selectedDays: Set<Int> = [0, 1, 2, 4] // Mon, Tue, Wed, Fri
    @State private var timeOfDay: String = "afternoons"
    
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // Gradient fills for selected days
    private let selectedColors: [Color] = [
        Color(red: 0.6, green: 0.85, blue: 0.75),
        Color(red: 0.65, green: 0.88, blue: 0.78),
        Color(red: 0.7, green: 0.90, blue: 0.80),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("RECOMMEND WHEN")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("EDIT") {}
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            
            // Day color strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(selectedDays.sorted(), id: \.self) { day in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: selectedColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: 28)
                    }
                }
            }
            
            // Day selector
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if selectedDays.contains(index) {
                                selectedDays.remove(index)
                            } else {
                                selectedDays.insert(index)
                            }
                        }
                    } label: {
                        Text(dayLabels[index])
                            .font(.subheadline)
                            .fontWeight(selectedDays.contains(index) ? .bold : .regular)
                            .foregroundStyle(selectedDays.contains(index) ? .primary : .tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Summary text
            VStack(alignment: .leading, spacing: 8) {
                Text(daySummary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Context tags
                HStack(spacing: 6) {
                    Text("great when")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    contextTag(icon: "sun.max.fill", label: "Sunny")
                    contextTag(icon: "calendar", label: "Calendar free")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    private var daySummary: String {
        let sorted = selectedDays.sorted()
        let names = sorted.map { dayNames[$0] }
        guard !names.isEmpty else { return "No days selected" }
        
        let joined: String
        if names.count == 1 {
            joined = names[0]
        } else {
            joined = names.dropLast().joined(separator: ", ") + " & " + names.last!
        }
        return "\(joined) — \(timeOfDay)"
    }
    
    private func contextTag(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemFill))
        )
    }
}

// MARK: - Settings Card

struct SettingsEditorCard: View {
    @State private var autoTrackEnabled: Bool = true
    @State private var themeTags: [String] = ["Fitness"]
    @State private var healthMetric: String = "Apple Move Minutes"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Theme Section
            themeSection
            
            sectionDivider
            
            // MARK: HealthKit Integration Section
            healthKitSection
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Section Divider
    
    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    
    // MARK: - Theme Section
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THEME")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            // Color + Icon pills side by side
            HStack(spacing: 10) {
                // Color pill
                Button {} label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(selectedColorValue)
                            .frame(width: 20, height: 20)
                        
                        Text(selectedColorName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemFill))
                    )
                }
                .buttonStyle(.plain)
                
                // Icon pill
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedIconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Text("Icon")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemFill))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Theme tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(themeTags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    themeTags.removeAll { $0 == tag }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        )
                    }
                    
                    // Add Theme button
                    Button {
                        // TODO: show theme picker
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add Theme")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - HealthKit Integration Section
    
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HEALTHKIT INTEGRATION")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            // Health Metric row
            Button {} label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.pink)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Health Metric")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(healthMetric)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            
            // Description
            Text("Data from Apple Health will be automatically synced and counted towards your goal progress.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            // Sync status
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                
                Text("Connected · Last synced just now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
        }
    }
    
}

// MARK: - Notes & Checklist Card

struct NotesChecklistCard: View {
    enum Tab: String, CaseIterable, Identifiable {
        case notes = "Notes"
        case checklist = "Checklist"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .notes: "note.text"
            case .checklist: "checklist"
            }
        }
    }
    
    @State private var selectedTab: Tab = .notes
    @Namespace private var tabAnimation
    
    // Notes state
    @State private var notesText: String = ""
    @State private var linkText: String = ""
    
    // Checklist state
    @State private var checklistItems: [ChecklistItem] = [
        ChecklistItem(text: "Get running shoes", isChecked: true),
        ChecklistItem(text: "Plan route", isChecked: false),
    ]
    @State private var newItemText: String = ""
    
    struct ChecklistItem: Identifiable {
        let id = UUID()
        var text: String
        var isChecked: Bool
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrolling tab header
            tabHeader
            
            Divider()
                .padding(.horizontal, 16)
            
            // Page content
            TabView(selection: $selectedTab) {
                notesPage
                    .tag(Tab.notes)
                
                checklistPage
                    .tag(Tab.checklist)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 180)
            .animation(.snappy(duration: 0.3), value: selectedTab)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Tab Header
    
    private var tabHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .medium))
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Notes Page
    
    private var notesPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Notes text field
            TextField("Add notes...", text: $notesText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemFill))
                )
            
            // Link field
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Add link or resource...", text: $linkText)
                    .font(.subheadline)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemFill))
            )
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
    
    // MARK: - Checklist Page
    
    private var checklistPage: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Existing items
            ForEach($checklistItems) { $item in
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            item.isChecked.toggle()
                        }
                    } label: {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(item.isChecked ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text(item.text)
                        .font(.subheadline)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Add item row
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                
                TextField("Add item...", text: $newItemText)
                    .font(.subheadline)
                    .onSubmit {
                        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        withAnimation(.snappy(duration: 0.2)) {
                            checklistItems.append(ChecklistItem(text: newItemText, isChecked: false))
                            newItemText = ""
                        }
                    }
            }
            .padding(.vertical, 4)
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Preview

struct GoalEditorCardPreview: View {
    enum Stage: String, CaseIterable, Identifiable {
        case title = "Title"
        case goal = "Goal"
        case schedule = "Schedule"
        case extras = "Extras"
        
        var id: String { rawValue }
        
        var index: Int {
            switch self {
            case .title: 0
            case .goal: 1
            case .schedule: 2
            case .extras: 3
            }
        }
    }
    
    @State private var stage: Stage = .title
    @State private var cardExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Goal card — minimised at title stage, expanded for all others
                    section(number: 1, title: stage == .title ? "Name it" : "Goal & target") {
                        GoalEditorCard(isExpanded: $cardExpanded)
                    }
                    
                    // Recommend when
                    if stage.index >= Stage.schedule.index {
                        section(number: 2, title: "Recommend when") {
                            RecommendWhenCard()
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    }
                    
                    // Settings
                    if stage.index >= Stage.extras.index {
                        section(number: 3, title: "Settings") {
                            SettingsEditorCard()
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                        
                        section(number: 4, title: "Notes & checklist") {
                            NotesChecklistCard()
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.secondarySystemBackground))
            
            // Stage picker
            VStack(spacing: 8) {
                Divider()
                
                Picker("Stage", selection: $stage) {
                    ForEach(Stage.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stage)
        .onChange(of: stage) {
            cardExpanded = stage != .title
        }
    }
    
    private func section<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GoalEditorSectionHeader(number: number, title: title)
                .padding(.horizontal, 20)
            
            content()
                .padding(.horizontal, 16)
        }
    }
}

#Preview("Goal Editor Card") {
    GoalEditorCardPreview()
}

