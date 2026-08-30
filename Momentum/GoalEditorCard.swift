//
//  GoalEditorCard.swift
//  Momentum
//
//  A sentence-style goal editor card, wired to GoalEditorViewModel.
//

import SwiftUI
import MomentumKit
import EventKit
import FamilyControls
import ManagedSettings

// MARK: - Goal Editor Card

struct GoalEditorCard: View {
    @Bindable var vm: GoalEditorViewModel
    @Binding var isExpanded: Bool
    @State private var activePicker: ActivePicker?
    @State private var showAppPicker = false
    @State private var showingPremiumPaywall = false
    @Namespace private var cardAnimation
    @FocusState private var isNameFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)

    enum ActivePicker: Equatable {
        case count, amount, unit, period, freq, style
    }
    
    // MARK: - Sentence helpers

    /// Plural-aware session noun for the current metric ("session"/"sessions").
    private var nounPlural: String {
        let noun = vm.sentenceMetric.noun
        return vm.sessionCount == 1 ? noun : noun + "s"
    }

    /// The period word shown in the sentence ("day"/"week").
    private var periodWord: String {
        vm.targetPeriod == .day ? "day" : "week"
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
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallSheet()
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
            
            if isExpanded {
                // Expanded: the goal name lives inline in the sentence below, so the
                // header shows the theme label (or "THE GOAL") + the style toggle.
                Text((vm.selectedGoalTheme?.title ?? "The Goal").uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Spacer()

                styleButton
            } else {
                TextField("Write your own goal...", text: $vm.userInput)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .focused($isNameFocused)
                    .matchedGeometryEffect(id: "label", in: cardAnimation)

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
                VStack(alignment: .leading, spacing: 0) {
                    titleField
                        .padding(.bottom, 12)

                    sentenceFlow
                        .padding(.bottom, 14)

                    rollupChip

                    if let recommended = vm.recommendedDailyMinutes, vm.selectedGoalType == .seconds {
                        recommendedTargetButton(dailyMinutes: recommended)
                            .padding(.top, 12)
                    }

                    activePanel

                    if vm.selectedGoalType == .screenTime {
                        screenTimeAppPickerSection
                            .padding(.top, 12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    // MARK: - Sentence

    private static let titleFont = Font.system(size: 25, weight: .heavy)

    /// The goal name — on its own line so it can wrap. An invisible `Text` mirror
    /// drives the width so the field (and its highlight fill) hugs the content for
    /// short titles and only wraps once the title fills the available width. A
    /// subtle fill appears while it's empty or focused to advertise the tap target,
    /// then fades to a clean heading once the goal is named.
    private var titleField: some View {
        let highlighted = vm.userInput.isEmpty || isNameFocused
        let measure = vm.userInput.isEmpty ? "Name your goal" : vm.userInput
        return Text(measure)
            .font(Self.titleFont)
            .lineLimit(1...4)
            .hidden()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(highlighted ? themeColor.opacity(0.12) : Color.clear)
            )
            .overlay(alignment: .leading) {
                TextField("Name your goal", text: $vm.userInput, axis: .vertical)
                    .font(Self.titleFont)
                    .foregroundStyle(.primary)
                    .focused($isNameFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sentenceFlow: some View {
        let m = vm.sentenceMetric

        return SentenceFlowLayout(spacing: 3, lineSpacing: 6) {
            if m.isSession {
                token("\(vm.sessionCount)", active: activePicker == .count) { toggle(.count) }
                token(m.format(vm.sessionMinutes), active: activePicker == .amount) { toggle(.amount) }
                dropToken(m.amountUnitLabel, active: activePicker == .unit) { toggle(.unit) }
                word("\(nounPlural) a")
            } else {
                token(m.format(vm.tallyTarget), active: activePicker == .amount) { toggle(.amount) }
                dropToken(m.amountUnitLabel, active: activePicker == .unit) { toggle(.unit) }
                word("a")
            }

            token(periodWord, active: activePicker == .period) { toggle(.period) }

            if vm.targetPeriod == .day {
                word(",")
                token(vm.dayPhrase, active: activePicker == .freq) { toggle(.freq) }
            }

            word(".")
        }
    }

    private func token(_ text: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(text)
                .font(.system(size: 21, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(active ? themeColor.contrastingTextColor : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? AnyShapeStyle(themeColor) : AnyShapeStyle(themeColor.opacity(0.15)))
                )
        }
        .buttonStyle(.plain)
    }

    /// A token with a trailing chevron — the unit, which opens the metric/unit picker.
    private func dropToken(_ text: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 3) {
                Text(text)
                    .font(.system(size: 21, weight: .heavy))
                    .tracking(-0.4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .heavy))
                    .opacity(0.75)
            }
            .foregroundStyle(active ? themeColor.contrastingTextColor : .primary)
            .padding(.leading, 10)
            .padding(.trailing, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? AnyShapeStyle(themeColor) : AnyShapeStyle(themeColor.opacity(0.15)))
            )
        }
        .buttonStyle(.plain)
    }

    private func word(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 21, weight: .semibold))
            .tracking(-0.3)
            .foregroundStyle(.secondary)
    }

    private func toggle(_ picker: ActivePicker) {
        withAnimation(spring) {
            activePicker = activePicker == picker ? nil : picker
        }
        HapticFeedbackManager.trigger(.light)
    }

    // MARK: - Rollup Chip

    private var rollupChip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "equal")
                    .font(.system(size: 8, weight: .bold))
                Text("WEEKLY")
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundStyle(themeColor.contrastingTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 7).fill(themeColor))

            Text(vm.sentenceRollupText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    // MARK: - Accordion Panels

    @ViewBuilder private var activePanel: some View {
        switch activePicker {
        case .count:
            countPanel.transition(.opacity.combined(with: .move(edge: .top)))
        case .amount:
            amountPanel.transition(.opacity.combined(with: .move(edge: .top)))
        case .unit:
            unitPanel.transition(.opacity.combined(with: .move(edge: .top)))
        case .period:
            periodPanel.transition(.opacity.combined(with: .move(edge: .top)))
        case .freq:
            freqPanel.transition(.opacity.combined(with: .move(edge: .top)))
        default:
            EmptyView()
        }
    }

    private var countPanel: some View {
        let m = vm.sentenceMetric
        let noun = m.noun.isEmpty ? "Session" : m.noun.capitalized
        return panelBox {
            panelTitle(vm.targetPeriod == .day ? "\(noun)s on each day" : "\(noun)s a week")
            bigStepper(
                text: "\(vm.sessionCount)", unit: nounPlural,
                canDec: vm.sessionCount > SentenceMetric.countRange.lowerBound,
                canInc: vm.sessionCount < SentenceMetric.countRange.upperBound,
                dec: { vm.setSessionCount(vm.sessionCount - 1) },
                inc: { vm.setSessionCount(vm.sessionCount + 1) }
            )
            presetRow(values: SentenceMetric.countPresets, current: vm.sessionCount,
                      label: { "\($0)" }, pick: { vm.setSessionCount($0) })
        }
    }

    private var amountPanel: some View {
        let m = vm.sentenceMetric
        let value = m.isSession ? vm.sessionMinutes : vm.tallyTarget
        let set: (Int) -> Void = m.isSession ? { vm.setSessionMinutes($0) } : { vm.setTallyTarget($0) }
        let title = m.isSession
            ? "How long each \(m.noun)"
            : (vm.targetPeriod == .day ? "Target each active day" : "Target for the week")
        return panelBox {
            panelTitle(title)
            bigStepper(
                text: m.format(value), unit: m.amountUnitLabel,
                canDec: value > m.amountMin, canInc: value < m.amountMax,
                dec: { set(value - m.amountStep) },
                inc: { set(value + m.amountStep) }
            )
            presetRow(values: m.amountPresets, current: value,
                      label: { m.chip($0) }, pick: set)
        }
    }

    private var unitPanel: some View {
        panelBox {
            panelTitle("Measure in")
            VStack(spacing: 4) {
                ForEach(SentenceMetric.all, id: \.unit) { metric in
                    let on = vm.selectedGoalType == metric.unit
                    Button {
                        if metric.unit == .screenTime && !SubscriptionManager.shared.isSubscribed {
                            showingPremiumPaywall = true
                        } else {
                            withAnimation(spring) {
                                vm.switchMetric(metric.unit)
                                activePicker = nil
                            }
                            HapticFeedbackManager.trigger(.light)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: metric.sfSymbol)
                                .font(.body)
                                .foregroundStyle(on ? themeColor : .secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(metric.pickerLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(metric.menuSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if on {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(themeColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(on ? themeColor.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var periodPanel: some View {
        let m = vm.sentenceMetric
        return panelBox {
            panelTitle(m.isSession ? "Count sessions per…" : "Reach the target per…")
            HStack(spacing: 8) {
                perOption(
                    title: "A week",
                    sub: m.isSession ? "Any days — hit the count" : "Cumulative — any days",
                    on: vm.targetPeriod == .week
                ) {
                    withAnimation(spring) { vm.setTargetPeriod(.week); activePicker = nil }
                }
                perOption(
                    title: "A day",
                    sub: m.isSession ? "Same count each active day" : "Reach it on each active day",
                    on: vm.targetPeriod == .day
                ) {
                    withAnimation(spring) { vm.setTargetPeriod(.day); activePicker = nil }
                }
            }
        }
    }

    private var freqPanel: some View {
        panelBox {
            panelTitle("On how many days a week")
            HStack(spacing: 5) {
                ForEach(1...7, id: \.self) { n in
                    let on = vm.daysPerWeek == n
                    Button {
                        withAnimation(spring) { vm.setDaysPerWeek(n) }
                        HapticFeedbackManager.trigger(.light)
                    } label: {
                        Text(n == 7 ? "∀" : "\(n)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(on ? themeColor.contrastingTextColor : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(on ? AnyShapeStyle(themeColor) : AnyShapeStyle(Color(.tertiarySystemFill)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text("1 day").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
                Spacer()
                Text("every day").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
            }
            .padding(.top, 7)
        }
    }

    // MARK: - Panel Building Blocks

    private func panelBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
            }
            .padding(.top, 12)
    }

    private func panelTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
    }

    private func bigStepper(
        text: String, unit: String,
        canDec: Bool, canInc: Bool,
        dec: @escaping () -> Void, inc: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            stepperCircle("minus", enabled: canDec, action: dec)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(text)
                    .font(.system(size: text.count > 4 ? 30 : 40, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.opacity(0.15)))
            }
            .frame(minWidth: 92)
            stepperCircle("plus", enabled: canInc, action: inc)
        }
        .frame(maxWidth: .infinity)
    }

    private func stepperCircle(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticFeedbackManager.trigger(.light)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? themeColor : Color.secondary.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(Circle().fill(enabled ? themeColor.opacity(0.15) : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }

    private func presetRow(
        values: [Int], current: Int,
        label: @escaping (Int) -> String, pick: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { p in
                let on = current == p
                Button {
                    withAnimation(.snappy(duration: 0.2)) { pick(p) }
                    HapticFeedbackManager.trigger(.light)
                } label: {
                    Text(label(p))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(on ? themeColor.contrastingTextColor : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(on ? AnyShapeStyle(themeColor) : AnyShapeStyle(Color(.tertiarySystemFill)))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 14)
    }

    private func perOption(title: String, sub: String, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(on ? themeColor.contrastingTextColor : .primary)
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(themeColor.contrastingTextColor)
                    }
                }
                Text(sub)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(on ? themeColor.contrastingTextColor.opacity(0.85) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(on ? AnyShapeStyle(themeColor) : AnyShapeStyle(Color(.tertiarySystemFill)))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Duration Formatting

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins) min"
        }
    }
    
    // MARK: - Recommended Target

    private func recommendedTargetButton(dailyMinutes: Int) -> some View {
        Button {
            if SubscriptionManager.shared.isSubscribed {
                withAnimation(spring) {
                    // Apply the suggestion as a single session on each active day.
                    vm.targetPeriod = .day
                    vm.sessionCount = 1
                    vm.setSessionMinutes(dailyMinutes)
                }
                HapticFeedbackManager.trigger(.success)
            } else {
                showingPremiumPaywall = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: SubscriptionManager.shared.isSubscribed ? "sparkles" : "lock.fill")
                    .font(.caption2.weight(.semibold))
                Text("Suggested: \(formatDuration(dailyMinutes))/day")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(themeColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
    
    private var themeColor: Color {
        vm.getActiveThemeColor(colorScheme: colorScheme)
    }
    
    var body: some View {
        Button {
            vm.showingRelevanceRuleSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Text("RECOMMENDED WHEN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                // Condition pills
                conditionPills
                
                // Summary
                Text(vm.compactRelevanceSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var conditionPills: some View {
        let preferred = (1...7).filter { vm.dayAvailabilities[$0] == .preferred }
        let allTimes = Set((1...7).flatMap { vm.dayTimePreferences[$0] ?? [] })
        let hasSpecificTimes = !allTimes.isEmpty && allTimes.count < TimeOfDay.allCases.count
        let hasWeather = vm.weatherEnabled && !vm.selectedWeatherConditions.isEmpty
        let hasDayTime = !preferred.isEmpty || hasSpecificTimes
        let hasSequence = vm.sequenceEnabled && vm.sequenceGoalTitle != nil
        let hasAny = hasDayTime || hasWeather || hasSequence
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if hasDayTime {
                    conditionPill(
                        icon: "clock.fill",
                        label: dayTimePillLabel(preferred: preferred, times: hasSpecificTimes ? allTimes : nil),
                        signalType: .timeOfDay
                    )
                }
                
                if hasWeather {
                    conditionPill(
                        icon: "cloud.sun.fill",
                        label: vm.selectedWeatherConditions
                            .sorted(by: { $0.displayName < $1.displayName })
                            .map { $0.displayName.lowercased() }
                            .joined(separator: ", "),
                        signalType: .weather
                    )
                }
                
                if hasSequence {
                    let dir = vm.sequenceDirection == "before" ? "Before" : "After"
                    conditionPill(
                        icon: "arrow.right.arrow.left",
                        label: "\(dir) \(vm.sequenceGoalTitle ?? "")",
                        signalType: .goalSequence
                    )
                }
                
                if !hasAny {
                    conditionPill(icon: "plus", label: "Add conditions")
                }
            }
        }
    }
    
    private func dayTimePillLabel(preferred: [Int], times: Set<TimeOfDay>?) -> String {
        let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var parts: [String] = []
        
        if !preferred.isEmpty {
            if preferred.count == 7 {
                parts.append("Every day")
            } else {
                parts.append(preferred.map { weekdayNames[$0] }.joined(separator: ", "))
            }
        }
        
        if let times, !times.isEmpty {
            parts.append(times.sorted().map { $0.displayName.lowercased() }.joined(separator: ", "))
        }
        
        return parts.isEmpty ? "Any day" : parts.joined(separator: " · ")
    }
    
    private func conditionPill(icon: String, label: String, signalType: SignalType? = nil) -> some View {
        HStack(spacing: 5) {
            // Strength chevron or green dot
            if let signalType, let strength = vm.signalStrengths[signalType] {
                let (chevronIcon, color): (String, Color) = switch strength {
                case .boost: ("chevron.up", .green)
                case .require: ("chevron.up.2", .green)
                case .avoid: ("chevron.down", .red)
                }
                Image(systemName: chevronIcon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(color)
            } else {
                Circle()
                    .fill(themeColor)
                    .frame(width: 5, height: 5)
            }
            
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
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
    
    enum AddMode: String, CaseIterable {
        case item = "Item"
        case group = "Group"
    }
    
    @State private var selectedTab: Tab = .notes
    @Namespace private var tabAnimation
    @State private var newItemTitle: String = ""
    @State private var addMode: AddMode = .item
    @State private var showingRemindersLinkSheet = false
    @State private var linkedCalendarTitle: String?
    @State private var linkedCalendarColor: CGColor?
    
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
            .frame(minHeight: 260)
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
    
    /// Ordered list of unique group names preserving insertion order
    private var orderedGroups: [String] {
        var seen = Set<String>()
        var groups: [String] = []
        for item in vm.checklistItems {
            if !item.group.isEmpty && seen.insert(item.group).inserted {
                groups.append(item.group)
            }
        }
        return groups
    }
    
    private var ungroupedItems: [ChecklistItemData] {
        vm.checklistItems.filter { $0.group.isEmpty }
    }
    
    private func itemsInGroup(_ group: String) -> [ChecklistItemData] {
        vm.checklistItems.filter { $0.group == group }
    }
    
    /// The group that new items should be added to (last group, or empty for ungrouped)
    private var activeGroup: String {
        orderedGroups.last ?? ""
    }
    
    private var checklistPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: CHECKLIST + item count
            HStack {
                Text("CHECKLIST")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(vm.checklistItems.count) item\(vm.checklistItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Linked Reminders header
            if vm.linkedRemindersListID != nil {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        if let linkedCalendarColor {
                            Circle()
                                .fill(Color(cgColor: linkedCalendarColor))
                                .frame(width: 8, height: 8)
                        }
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(linkedCalendarTitle ?? "Reminders")
                        .font(.caption.weight(.medium))
                    
                    Text("· linked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingRemindersLinkSheet = true
                    } label: {
                        Text("Change")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Progress bar
            if !vm.checklistItems.isEmpty {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.2))
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(width: geo.size.width * min(1.0, CGFloat(vm.checklistItems.count) / max(CGFloat(vm.checklistItems.count), 1.0)))
                        }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            
            // Scrollable item list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Ungrouped items first
                    ForEach(ungroupedItems) { item in
                        checklistItemRow(item: item)
                    }
                    
                    // Grouped items
                    ForEach(orderedGroups, id: \.self) { group in
                        checklistGroupSection(group: group)
                    }
                }
                .padding(.top, 8)
            }
            
            // Link Reminders List button (when not linked)
            if vm.linkedRemindersListID == nil {
                Button {
                    showingRemindersLinkSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.caption)
                        Text("Link Reminders List")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
            
            Spacer(minLength: 0)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Bottom toolbar: [Item] [Group] + text field + add button
            checklistToolbar
        }
        .sheet(isPresented: $showingRemindersLinkSheet) {
            RemindersListLinkSheetForEditor(vm: vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: vm.linkedRemindersListID) {
            if let calendarID = vm.linkedRemindersListID {
                let manager = RemindersManager()
                _ = try? await manager.requestAccess()
                if let cal = manager.calendar(for: calendarID) {
                    linkedCalendarTitle = cal.title
                    linkedCalendarColor = cal.cgColor
                }
            } else {
                linkedCalendarTitle = nil
                linkedCalendarColor = nil
            }
        }
    }
    
    // MARK: - Checklist Item Row
    
    private func checklistItemRow(item: ChecklistItemData) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(.secondary.opacity(0.4))
            
            if let index = vm.checklistItems.firstIndex(where: { $0.id == item.id }) {
                TextField("Item title", text: $vm.checklistItems[index].title)
                    .font(.body)
            }
            
            Spacer()
            
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    vm.checklistItems.removeAll { $0.id == item.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.quaternary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Checklist Group Section
    
    private func checklistGroupSection(group: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 8) {
                Text(group.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        vm.checklistItems.removeAll { $0.group == group }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.top, 4)
            
            // Items in this group
            ForEach(itemsInGroup(group)) { item in
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary.opacity(0.4))
                    
                    if let index = vm.checklistItems.firstIndex(where: { $0.id == item.id }) {
                        TextField("Item title", text: $vm.checklistItems[index].title)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            vm.checklistItems.removeAll { $0.id == item.id }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.quaternary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
    
    // MARK: - Checklist Toolbar
    
    private var checklistToolbar: some View {
        HStack(spacing: 8) {
            // Item / Group toggle
            HStack(spacing: 2) {
                ForEach(AddMode.allCases, id: \.self) { mode in
                    Button {
                        addMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(addMode == mode ? Color(.tertiarySystemFill) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(addMode == mode ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            
            // Text field
            TextField(
                addMode == .item ? "Add a task \u{2014} paste a list for many" : "Group name",
                text: $newItemTitle
            )
            .font(.subheadline)
            .onSubmit(addItem)
            
            // Add button
            Button(action: addItem) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        withAnimation(.snappy(duration: 0.2)) {
            switch addMode {
            case .item:
                // Check for multi-line paste
                let lines = trimmed.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                if lines.count > 1 {
                    for line in lines {
                        vm.checklistItems.append(ChecklistItemData(title: line, group: activeGroup))
                    }
                } else {
                    vm.checklistItems.append(ChecklistItemData(title: trimmed, group: activeGroup))
                }
                
            case .group:
                // Add a placeholder item to register the group, then switch to item mode
                vm.checklistItems.append(ChecklistItemData(title: "", group: trimmed))
                addMode = .item
            }
            newItemTitle = ""
        }
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
