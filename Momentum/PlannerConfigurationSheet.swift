//
//  PlannerConfigurationSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 20/01/2026.
//
import SwiftUI
import EventKit
import MomentumKit

// MARK: - FlowLayout
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - ThemeTag
struct ThemeTag: View {
    let theme: GoalTag
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(theme.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : theme.theme.color(for: colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.theme.color(for: colorScheme) : theme.theme.colors(for: colorScheme).first!.opacity(0.5))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(theme.theme.color(for: colorScheme).opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PlannerConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedThemes: Set<String>
    @Binding var availableTimeMinutes: Int
    @Binding var selectedWeather: WeatherCondition?
    let allThemes: [GoalTag]
    let sessions: [GoalSession]
    let currentWeather: WeatherCondition?
    let nextEvent: EKEvent?
    let calendarFreeMinutes: Int? // nil = no calendar access
    let animation: Namespace.ID
    let onConfirm: () -> Void
    
    // Time range: 5–180 in 5–minute steps
    private let timeStep = 5
    private let timeMin = 5
    private let timeMax = 180
    
    // All weather conditions from the enum
    private let weatherOptions: [WeatherCondition] = WeatherCondition.allCases
    
    @State private var hasAutoSelected = false
    @State private var dragAccumulator: CGFloat = 0
    
    /// Weather to display as active — user override or live weather
    private var effectiveWeather: WeatherCondition? {
        selectedWeather ?? currentWeather
    }
    
    /// Current time of day for context matching
    private var currentTimeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    /// Check if a tag's triggers match the current context
    private func tagMatchesContext(_ tag: GoalTag) -> Bool {
        guard tag.isSmart else { return false }
        
        // Check time of day match
        if let times = tag.timeOfDayPreferencesTyped, !times.isEmpty {
            if !times.contains(currentTimeOfDay) { return false }
        }
        
        // Check weather match
        if let conditions = tag.weatherConditionsTyped, !conditions.isEmpty {
            if let weather = effectiveWeather {
                if !conditions.contains(weather) { return false }
            }
            // If no weather data, don't penalize — just skip weather check
        }
        
        return true
    }
    
    /// Titles of tags whose triggers match right now
    private var suggestedThemeKeys: Set<String> {
        Set(allThemes.filter { tagMatchesContext($0) }.map { $0.title.lowercased() })
    }
    
    /// Themes sorted: suggested first, then alphabetical
    private var sortedThemes: [GoalTag] {
        let suggested = suggestedThemeKeys
        return allThemes.sorted { a, b in
            let aMatches = suggested.contains(a.title.lowercased())
            let bMatches = suggested.contains(b.title.lowercased())
            if aMatches != bMatches { return aMatches }
            return a.title.localizedCompare(b.title) == .orderedAscending
        }
    }
    
    private var matchingSessionCount: Int {
        sessions.filter { session in
            guard session.status == .active,
                  session.unifiedTargetValue > 0,
                  !session.hasMetDailyTarget else { return false }
            
            // Filter by theme
            if !selectedThemes.isEmpty {
                guard let tagTitle = session.goal?.primaryTag?.title.lowercased(),
                      selectedThemes.contains(tagTitle) else { return false }
            }
            
            // Filter by time
            if availableTimeMinutes > 0 {
                let sessionMinutes = session.unifiedTargetValue / 60
                if sessionMinutes > Double(availableTimeMinutes) { return false }
            }
            
            return true
        }.count
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    
                    availableTimeSection
                    
                    weatherSection
                    
                    themesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .safeAreaInset(edge: .bottom) {
                confirmButton
            }
            .navigationTitle("Tune the list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationTransition(
            .zoom(sourceID: "plannerButton", in: animation)
        )
    }
    
    
    // MARK: - Available Time Section
    
    private var availableTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("I HAVE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
        
            
            // Calendar context hint
            if let freeMinutes = calendarFreeMinutes {
                calendarHint(freeMinutes: freeMinutes)
            }
            
            // Digital readout card
            HStack(spacing: 0) {
                // Minus button
                Button {
                    adjustTime(by: -timeStep)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(availableTimeMinutes <= timeMin ? 0.3 : 0.8))
                        .frame(width: 56, height: 100)
                }
                .buttonStyle(.plain)
                .disabled(availableTimeMinutes <= timeMin)
                
                Spacer()
                
                // Center display
                VStack(spacing: 6) {
                    Text(formattedTime)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    
                    PhaseAnimator([0, 1, 2, 3]) { phase in
                        HStack(spacing: 4) {
                            // Left chevrons: index 0 is outermost, 3 is closest to text
                            ForEach(0..<4, id: \.self) { i in
                                let distance = 3 - i // 3,2,1,0 from text
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(phase == distance ? 0.7 : 0.15))
                            }
                            Text("SLIDE TO ADJUST")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(0.5)
                            // Right chevrons: index 0 is closest to text, 3 is outermost
                            ForEach(0..<4, id: \.self) { i in
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(phase == i ? 0.7 : 0.15))
                            }
                        }
                    } animation: { _ in
                        .easeInOut(duration: 0.4)
                    }
                }
                
                Spacer()
                
                // Plus button
                Button {
                    adjustTime(by: timeStep)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(availableTimeMinutes >= timeMax ? 0.3 : 0.8))
                        .frame(width: 56, height: 100)
                }
                .buttonStyle(.plain)
                .disabled(availableTimeMinutes >= timeMax)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemGray5).opacity(0.9),
                                Color(.systemGray6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .environment(\.colorScheme, .dark)
            )
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let delta = value.translation.width - dragAccumulator
                        // Every 20pt of drag = 1 step
                        let steps = Int(delta / 20)
                        if steps != 0 {
                            dragAccumulator += CGFloat(steps) * 20
                            adjustTime(by: steps * timeStep)
                        }
                    }
                    .onEnded { _ in
                        dragAccumulator = 0
                    }
            )
        }
    }
    
    private var formattedTime: String {
        if availableTimeMinutes >= 60 {
            let h = availableTimeMinutes / 60
            let m = availableTimeMinutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(availableTimeMinutes)m"
    }
    
    private func adjustTime(by amount: Int) {
        let newValue = availableTimeMinutes + amount
        let clamped = max(timeMin, min(timeMax, newValue))
        guard clamped != availableTimeMinutes else { return }
        withAnimation(AnimationPresets.quickSpring) {
            availableTimeMinutes = clamped
        }
        HapticFeedbackManager.trigger(.light)
    }
    
    private func calendarHint(freeMinutes: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.blue)
            
            Group {
                if let event = nextEvent {
                    let minutesUntil = Int(event.startDate.timeIntervalSince(Date()) / 60)
                    if minutesUntil > 0 {
                        Text("\(formatFreeTime(freeMinutes)) free today · next event in \(formatFreeTime(minutesUntil))")
                    } else {
                        Text("\(formatFreeTime(freeMinutes)) free remaining today")
                    }
                } else {
                    Text("\(formatFreeTime(freeMinutes)) free today — no upcoming events")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Weather Section
    
    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The current weather is".uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            if let detected = currentWeather {
                Text("\(detected.displayName) detected from weather data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            TagFlowLayout(spacing: 8) {
                ForEach(weatherOptions, id: \.self) { condition in
                    let isSelected = effectiveWeather == condition
                    let isDetected = currentWeather == condition && selectedWeather == nil
                    Button {
                        withAnimation(AnimationPresets.quickSpring) {
                            if selectedWeather == condition {
                                selectedWeather = nil // Revert to auto
                            } else {
                                selectedWeather = condition
                            }
                        }
                        HapticFeedbackManager.trigger(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: condition.icon)
                                .font(.caption)
                            Text(condition.displayName.uppercased())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if isDetected {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.primary : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Themes Section
    
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SHOW ME")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                
                Spacer()
                
                if !selectedThemes.isEmpty {
                    Button {
                        withAnimation(AnimationPresets.quickSpring) {
                            selectedThemes.removeAll()
                        }
                        HapticFeedbackManager.trigger(.light)
                    } label: {
                        Text("CLEAR")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text("Themes")
                .font(.headline)
            
            if !suggestedThemeKeys.isEmpty {
                Text("Auto-selected based on current time & weather.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            TagFlowLayout(spacing: 8) {
                ForEach(sortedThemes, id: \.title) { tag in
                    let tagKey = tag.title.lowercased()
                    let isSelected = selectedThemes.contains(tagKey)
                    let isSuggested = suggestedThemeKeys.contains(tagKey)
                    
                    Button {
                        withAnimation(AnimationPresets.quickSpring) {
                            if isSelected {
                                selectedThemes.remove(tagKey)
                            } else {
                                selectedThemes.insert(tagKey)
                            }
                        }
                        HapticFeedbackManager.trigger(.light)
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tag.theme.color(for: colorScheme))
                                .frame(width: 18, height: 18)
                            
                            Text(tag.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if isSuggested && !isSelected {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 8))
                                    .foregroundStyle(tag.theme.color(for: colorScheme))
                            }
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? tag.theme.color(for: colorScheme) : Color(.systemGray5))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSuggested && !isSelected
                                        ? tag.theme.color(for: colorScheme).opacity(0.4)
                                        : .clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            guard !hasAutoSelected else { return }
            hasAutoSelected = true
            
            // Auto-select themes that match the current context
            let suggested = suggestedThemeKeys
            if !suggested.isEmpty && selectedThemes.isEmpty {
                selectedThemes = suggested
            }
        }
    }
    
    // MARK: - Confirm Button
    
    private var confirmButton: some View {
        Button {
            #if os(iOS)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            #endif
            
            onConfirm()
        } label: {
            HStack {
                Text("SHOW \(matchingSessionCount) GOALS")
                    .font(.headline)
                    .fontWeight(.bold)
                    .tracking(1)
                
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(.primary)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }
    
    // MARK: - Helpers
    
    private func formatFreeTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}
