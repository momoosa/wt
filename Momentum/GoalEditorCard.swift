//
//  GoalEditorCard.swift
//  Momentum
//
//  A sentence-style goal editor card, wired to GoalEditorViewModel.
//

import SwiftUI
import MomentumKit
import FamilyControls
import ManagedSettings

// MARK: - Goal Editor Card

struct GoalEditorCard: View {
    @Bindable var vm: GoalEditorViewModel
    @Binding var isExpanded: Bool
    @State private var activePicker: ActivePicker?
    @State private var showAppPicker = false
    @Namespace private var cardAnimation
    @FocusState private var isNameFocused: Bool
    @FocusState private var isValueFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    enum ActivePicker: Equatable {
        case value, unit, period, style
    }
    
    // MARK: UI-level unit display
    
    /// Sentence-friendly unit labels derived from the VM's goal type
    private var unitLabel: String {
        switch vm.selectedGoalType {
        case .seconds: "min"
        case .steps: "steps"
        case .kilocalories: "kcal"
        case .screenTime: "min"
        }
    }
    
    /// The numeric target shown in the sentence chip (per-day for time goals)
    private var displayTarget: Int {
        switch vm.selectedGoalType {
        case .seconds:
            let dayCount = max(vm.activeDays.count, 1)
            return vm.durationInMinutes / dayCount
        case .steps, .kilocalories:
            return Int(vm.primaryMetricTarget)
        case .screenTime:
            return Int(vm.primaryMetricTarget)
        }
    }
    
    /// Period label based on active day count
    private var periodLabel: String {
        if vm.activeDays.count == 7 { return "day" }
        return "week"
    }
    
    /// The resolved icon name
    private var iconName: String {
        vm.selectedIcon ?? "chart.line.uptrend.xyaxis"
    }
    
    /// The resolved theme color
    private var themeColor: Color {
        vm.getActiveThemeColor(colorScheme: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            minimisedRow
            
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
        .sheet(isPresented: $showAppPicker) {
            NavigationStack {
                FamilyActivityPicker(selection: $vm.screenTimeSelection)
                    .navigationTitle("Select Apps")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showAppPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showAppPicker = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Minimised Row
    
    private var minimisedRow: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: isExpanded ? 14 : 12)
                .fill(themeColor.opacity(0.3))
                .frame(width: isExpanded ? 52 : 44, height: isExpanded ? 52 : 44)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: isExpanded ? 22 : 18, weight: .medium))
                        .foregroundStyle(themeColor.opacity(0.8))
                }
                .matchedGeometryEffect(id: "icon", in: cardAnimation)
            
            if isExpanded, let theme = vm.selectedGoalTheme?.title {
                Text(theme.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .matchedGeometryEffect(id: "label", in: cardAnimation)
                

                Spacer()
                
                styleButton
            } else {
                Spacer()
            }
        }
        .padding(.bottom, isExpanded ? 20 : 0)
    }
    
    // MARK: - Style Button
    
    private var styleButton: some View {
        let isStyleMode = activePicker == .style
        
        return Button {
            withAnimation {
                activePicker = isStyleMode ? nil : .style
            }
        } label: {
            Text(isStyleMode ? "Done".uppercased() : "Edit".uppercased())
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
                stylePicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                sentenceEditor
                    .padding(.bottom, 12)
                
                summaryText
                    .padding(.bottom, activePicker != nil ? 16 : 0)
                
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
                
                if vm.selectedGoalType == .screenTime {
                    screenTimeAppPickerSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    // MARK: - Sentence Editor
    
    private var sentenceEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                TextField("Goal name", text: $vm.userInput, axis: .vertical)
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .focused($isNameFocused)
                    .textFieldStyle(.plain)
            }
            
            // Sentence: [value] [unit] a [period]
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                valueChip
                
                chipButton(
                    text: unitLabel,
                    isActive: activePicker == .unit,
                    picker: .unit
                )
                
                Text("a")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.secondary)
                
                chipButton(
                    text: periodLabel,
                    isActive: activePicker == .period,
                    picker: .period
                )
            }
        }
    }
    
    /// Formatted display string for the target value (e.g. "10,000")
    private var formattedTarget: String {
        displayTarget.formatted(.number)
    }
    
    /// The value chip — a TextField that accepts only numbers
    private var valueChip: some View {
        TextField("0", value: Binding(
            get: { displayTarget },
            set: { applyTarget($0) }
        ), format: .number)
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .focused($isValueFocused)
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(.primary)
        .fixedSize()
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeColor.opacity(isValueFocused || activePicker == .value ? 0.3 : 0.15))
        )
        .onTapGesture {
            withAnimation {
                activePicker = activePicker == .value ? nil : .value
            }
        }
        .onChange(of: isValueFocused) { _, focused in
            if focused {
                withAnimation { activePicker = .value }
            }
        }
    }
    
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
        let dayCount = vm.activeDays.count
        return Text("Surfaced on your **\(dayCount)** best-fit moments each \(periodLabel)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    // MARK: - Unit Picker
    
    private var unitPicker: some View {
        let options: [(type: Goal.TargetUnit, title: String, subtitle: String, icon: String)] = [
            (.seconds, "Minutes", "Total time", "clock"),
            (.steps, "Steps", "Step count from Health", "shoeprints.fill"),
            (.kilocalories, "Calories", "Active energy burned", "flame"),
            (.screenTime, "Screen Time", "Limit app & category usage", "hourglass"),
        ]
        
        return VStack(spacing: 4) {
            ForEach(options, id: \.type) { option in
                Button {
                    withAnimation {
                        vm.selectedGoalType = option.type
                        vm.handleGoalTypeChange(option.type)
                        activePicker = nil
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.icon)
                            .font(.body)
                            .foregroundStyle(option.type == vm.selectedGoalType ? themeColor : .secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if option.type == vm.selectedGoalType {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(option.type == vm.selectedGoalType ? themeColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Period Picker
    
    private var periodPicker: some View {
        let options: [(label: String, title: String, subtitle: String, icon: String, days: Set<Int>)] = [
            ("day", "Daily", "Every single day", "sun.max", Set(1...7)),
            ("week", "Weekly", "Choose your active days", "calendar", vm.activeDays.isEmpty ? Set(2...6) : vm.activeDays),
        ]
        
        return VStack(spacing: 4) {
            ForEach(options, id: \.label) { option in
                let isSelected = (option.label == "day" && vm.activeDays.count == 7) ||
                    (option.label == "week" && vm.activeDays.count < 7)
                
                Button {
                    withAnimation {
                        vm.activeDays = option.days
                        // Redistribute the weekly target across the new day count
                        let weekly = vm.calculatedWeeklyTarget
                        vm.updateWeeklyTarget(weekly)
                        activePicker = nil
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.icon)
                            .font(.body)
                            .foregroundStyle(isSelected ? themeColor : .secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(themeColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? themeColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Value Picker
    
    private var valuePicker: some View {
        let currentValue = displayTarget
        
        return VStack(spacing: 16) {
            // Quick-select strip
            HStack(spacing: 0) {
                ForEach(quickSelectValues, id: \.self) { value in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            applyTarget(value)
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
    
    /// Write the target value back to the VM
    private func applyTarget(_ value: Int) {
        switch vm.selectedGoalType {
        case .seconds:
            // value is daily minutes — distribute across active days
            let weeklyMinutes = value * max(vm.activeDays.count, 1)
            vm.updateWeeklyTarget(weeklyMinutes)
        case .steps, .kilocalories:
            vm.primaryMetricTarget = Double(value)
        case .screenTime:
            vm.primaryMetricTarget = Double(value)
        }
    }
    
    private var quickSelectValues: [Int] {
        switch vm.selectedGoalType {
        case .seconds:
            return [10, 15, 20, 30, 45, 60]
        case .steps:
            return [2000, 5000, 7500, 10000, 15000]
        case .kilocalories:
            return [200, 300, 400, 500, 600]
        case .screenTime:
            return [30, 60, 90, 120, 180, 240]
        }
    }
    
    // MARK: - Screen Time App Picker Section
    
    private var screenTimeAppPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)
            
            Button {
                showAppPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "app.badge")
                        .font(.body)
                        .foregroundStyle(themeColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select Apps & Categories")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if screenTimeSelectionCount > 0 {
                            Text(screenTimeSelectionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Choose which apps to track")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(themeColor.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            
            // Show selected apps and categories
            if screenTimeSelectionCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(vm.screenTimeSelection.categoryTokens), id: \.self) { token in
                            Label(token)
                                .labelStyle(.titleAndIcon)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeColor.opacity(0.1))
                                )
                        }
                        ForEach(Array(vm.screenTimeSelection.applicationTokens), id: \.self) { token in
                            Label(token)
                                .labelStyle(.titleAndIcon)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeColor.opacity(0.1))
                                )
                        }
                    }
                }
            }
        }
    }
    
    private var screenTimeSelectionCount: Int {
        vm.screenTimeSelection.applicationTokens.count +
        vm.screenTimeSelection.categoryTokens.count
    }
    
    private var screenTimeSelectionSummary: String {
        let apps = vm.screenTimeSelection.applicationTokens.count
        let categories = vm.screenTimeSelection.categoryTokens.count
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ") + " selected"
    }
    
    // MARK: - Style Picker
    
    private static let iconOptions: [String] = [
        "figure.run", "figure.walk", "figure.yoga", "dumbbell.fill",
        "bicycle", "figure.pool.swim", "figure.hiking", "shoeprints.fill",
        "heart.fill", "sparkles", "leaf.fill", "drop.fill",
        "sun.max.fill", "moon.stars.fill", "bed.double.fill", "brain.fill",
        "book.fill", "graduationcap.fill", "lightbulb.fill", "pencil",
        "paintbrush.fill", "camera.fill", "music.note", "guitars.fill",
        "checkmark.circle.fill", "list.bullet", "calendar", "clock.fill",
        "flag.fill", "star.fill", "target", "chart.line.uptrend.xyaxis",
        "house.fill", "fork.knife", "cup.and.saucer.fill", "mug.fill",
        "person.2.fill", "bubble.fill", "gift.fill", "party.popper.fill",
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
                            let isSelected = vm.selectedColorPreset?.id == preset.id
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    vm.handleColorSelection(preset)
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
                                    vm.selectedIcon = icon
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
            }
        }
    }
}

// MARK: - Section Header

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
    @Bindable var vm: GoalEditorViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    /// The resolved theme color
    private var themeColor: Color {
        vm.getActiveThemeColor(colorScheme: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RECOMMEND WHEN")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Day color strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.activeDays.sorted(), id: \.self) { day in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeColor.opacity(0.5))
                            .frame(width: 40, height: 28)
                    }
                }
            }
            
            // Day selector (1=Sun .. 7=Sat)
            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { weekday in
                    let isActive = vm.activeDays.contains(weekday)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            vm.toggleActiveDay(weekday)
                        }
                    } label: {
                        Text(dayLabels[weekday - 1])
                            .font(.subheadline)
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundStyle(isActive ? .primary : .tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Text(daySummary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Context tags from selectedTags
                if !vm.selectedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("themes")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            ForEach(vm.selectedTags, id: \.title) { tag in
                                contextTag(icon: "tag.fill", label: tag.title)
                            }
                        }
                    }
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
        let sorted = vm.activeDays.sorted()
        let names = sorted.map { dayNames[$0 - 1] }
        guard !names.isEmpty else { return "No days selected" }
        
        let joined: String
        if names.count == 1 {
            joined = names[0]
        } else if names.count == 7 {
            joined = "Every day"
        } else {
            joined = names.dropLast().joined(separator: ", ") + " & " + names.last!
        }
        return joined
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
    @Bindable var vm: GoalEditorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingHealthKitBrowser = false
    
    private var themeColor: Color {
        vm.getActiveThemeColor(colorScheme: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            themeSection
            
            sectionDivider
            
            healthKitSection
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .sheet(isPresented: $showingHealthKitBrowser) {
            HealthKitMetricsBrowserView(
                selectedMetric: $vm.selectedHealthKitMetric,
                currentGoal: vm.existingGoal
            )
        }
    }
    
    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    
    // MARK: - Theme Tags Section
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Themes".uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Primary tag
                    if let primary = vm.selectedGoalTheme {
                        HStack(spacing: 6) {
                            Text(primary.title)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    vm.selectedGoalTheme = nil
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
                                .fill(themeColor.opacity(0.15))
                        )
                    }
                    
                    // Other tags
                    ForEach(vm.selectedTags.filter({ $0.id != vm.selectedGoalTheme?.id }), id: \.title) { tag in
                        HStack(spacing: 6) {
                            Text(tag.title)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    vm.removeGoalTheme(tag)
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
                        vm.showingAddThemeSheet = true
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
            Button {
                showingHealthKitBrowser = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: vm.selectedHealthKitMetric?.symbolName ?? "heart.fill")
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
                        Text(vm.selectedHealthKitMetric?.displayName ?? "None")
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
            
            // Sync toggle
            HStack(spacing: 12) {
                Text("Auto-sync from Health")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $vm.healthKitSyncEnabled)
                    .labelsHidden()
                    .tint(themeColor)
            }
            .padding(.horizontal, 16)
            
            if vm.healthKitSyncEnabled {
                Text("Data from Apple Health will be automatically synced and counted towards your goal progress.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Notes & Checklist Card

struct NotesChecklistCard: View {
    @Bindable var vm: GoalEditorViewModel
    
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
    @State private var newItemTitle: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabHeader
            
            Divider()
                .padding(.horizontal, 16)
            
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
            TextField("Add notes...", text: $vm.goalNotes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemFill))
                )
            
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Add link or resource...", text: $vm.goalLink)
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
            ForEach($vm.checklistItems) { $item in
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    TextField("Item title", text: $item.title)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            vm.checklistItems.removeAll { $0.id == item.id }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            
            // Add item row
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                
                TextField("Add item...", text: $newItemTitle)
                    .font(.subheadline)
                    .onSubmit {
                        guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        withAnimation(.snappy(duration: 0.2)) {
                            vm.checklistItems.append(ChecklistItemData(title: newItemTitle))
                            newItemTitle = ""
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
        
        var nextStage: Stage? {
            switch self {
            case .title: .goal
            case .goal: .schedule
            case .schedule: .extras
            case .extras: nil
            }
        }
        
        var previousStage: Stage? {
            switch self {
            case .title: nil
            case .goal: .title
            case .schedule: .goal
            case .extras: .schedule
            }
        }
        
        var buttonLabel: String {
            switch self {
            case .title: "Next"
            case .goal: "Next"
            case .schedule: "Next"
            case .extras: "Save Goal"
            }
        }
    }
    
    @State private var stage: Stage = .title
    @State private var cardExpanded: Bool = false
    @State private var vm = GoalEditorViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: Goal card
                    section(number: 1, title: stage == .title ? "Name it" : "Goal & target") {
                        GoalEditorCard(vm: vm, isExpanded: $cardExpanded)
                    }
                    
                    // Section 2: Recommend when
                    if stage.index >= Stage.schedule.index {
                        section(number: 2, title: "Recommend when") {
                            RecommendWhenCard(vm: vm)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    }
                    
                    // Section 3: Settings
                    if stage.index >= Stage.extras.index {
                        section(number: 3, title: "Settings") {
                            SettingsEditorCard(vm: vm)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                        
                        section(number: 4, title: "Notes & checklist") {
                            NotesChecklistCard(vm: vm)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(Color(.secondarySystemBackground))
            
            // Bottom navigation bar
            bottomBar
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stage)
        .onChange(of: stage) {
            cardExpanded = stage != .title
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Back button
                if let previous = stage.previousStage {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            stage = previous
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Next / Save button
                Button {
                    if let next = stage.nextStage {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            stage = next
                        }
                    } else {
                        // Save action
                    }
                } label: {
                    Text(stage.buttonLabel)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.label))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
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
