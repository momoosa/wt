import SwiftUI
import MapKit
import CoreLocation
import MomentumKit

struct RelevanceRuleView: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color
    let allGoals: [Goal]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingPremiumPaywall = false
    @State private var expandedCondition: ConditionType?
    @State private var locationSearchText = ""
    @State private var locationSearchResults: [MKMapItem] = []
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var locationManager = LocationManagerHelper()
    @State private var isFetchingCurrentLocation = false
    
    private enum ConditionType: Hashable {
        case dayTime
        case weather
        case location
        case goalSequence
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    conditionCards
                    if activeConditionCount >= 2 {
                        matchModeToggle
                    }
                    addConditionSection
                }
                .padding()
                .padding(.bottom, 180)
            }
            .background(Color(.secondarySystemBackground))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    summaryCard
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("SAVE RULE")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(viewModel.activeThemePreset?.foregroundColor(for: colorScheme) ?? .white)
                            .background(Color(.label))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPremiumPaywall) {
                PremiumPaywallSheet()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECOMMENDED WHEN")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                // Goal icon
                if let icon = viewModel.selectedIcon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(activeThemeColor)
                        .frame(width: 36, height: 36)
                        .background(activeThemeColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Text(viewModel.userInput.isEmpty ? "New Goal" : viewModel.userInput)
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }
    
    // MARK: - Condition Cards
    
    private var conditionCards: some View {
        VStack(spacing: 10) {
            // Day & Time condition (always shown if configured)
            if hasDayTimeCondition {
                conditionCard(
                    type: .dayTime,
                    label: "DAY & TIME",
                    summary: dayTimeSummary,
                    icon: "clock.fill",
                    signalType: .timeOfDay
                ) {
                    dayTimeDetail
                }
            }
            
            // Weather condition
            if viewModel.weatherEnabled {
                conditionCard(
                    type: .weather,
                    label: "WEATHER",
                    summary: weatherSummary,
                    icon: "cloud.sun.fill",
                    signalType: .weather
                ) {
                    weatherDetail
                }
            }
            
            // Location condition
            if viewModel.locationEnabled {
                conditionCard(
                    type: .location,
                    label: "LOCATION",
                    summary: locationSummary,
                    icon: "location.fill",
                    signalType: .location
                ) {
                    locationDetail
                }
            }
            
            // Goal sequence condition
            if viewModel.sequenceEnabled {
                conditionCard(
                    type: .goalSequence,
                    label: "GOAL SEQUENCE",
                    summary: goalSequenceSummary,
                    icon: "arrow.right.arrow.left.circle.fill",
                    signalType: .goalSequence
                ) {
                    goalSequenceDetail
                }
            }
        }
    }
    
    private func conditionCard<Detail: View>(
        type: ConditionType,
        label: String,
        summary: String,
        icon: String,
        signalType: SignalType? = nil,
        @ViewBuilder detail: @escaping () -> Detail
    ) -> some View {
        VStack(spacing: 0) {
            // Card header row
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    expandedCondition = expandedCondition == type ? nil : type
                }
            } label: {
                HStack(spacing: 12) {
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text(summary)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // Strength chevron indicator
                        if let signalType, let strength = viewModel.signalStrengths[signalType] {
                            strengthChevron(strength)
                        } else {
                            // Default green dot indicator
                            Circle()
                                .fill(activeThemeColor)
                                .frame(width: 6, height: 6)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expandedCondition == type ? 90 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            
            // Expanded detail
            if expandedCondition == type {
                Divider()
                    .padding(.horizontal, 16)
                
                detail()
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Remove button at bottom when expanded
            if expandedCondition == type {
                Divider()
                    .padding(.horizontal, 16)
                
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        removeCondition(type)
                        expandedCondition = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Remove condition")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Add Condition Section
    
    private var addConditionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD A CONDITION")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if !hasDayTimeCondition {
                    addConditionButton(label: "Day & time", icon: "clock") {
                        withAnimation(.snappy(duration: 0.2)) {
                            // Set some preferred days to activate day/time
                            let preferredCount = (1...7).filter { viewModel.dayAvailabilities[$0] == .preferred }.count
                            if preferredCount == 0 {
                                // Default: weekdays preferred
                                for weekday in 2...6 {
                                    viewModel.dayAvailabilities[weekday] = .preferred
                                }
                                viewModel.syncActiveDaysFromAvailabilities()
                            }
                            expandedCondition = .dayTime
                        }
                    }
                }
                
                if !viewModel.locationEnabled {
                    addConditionButton(label: "Location", icon: "location") {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.locationEnabled = true
                            if viewModel.signalStrengths[.location] == nil {
                                viewModel.signalStrengths[.location] = .boost
                            }
                            expandedCondition = .location
                        }
                    }
                }
                
                if !viewModel.weatherEnabled {
                    addConditionButton(label: "Weather", icon: "cloud") {
                        if !SubscriptionManager.shared.isSubscribed {
                            showingPremiumPaywall = true
                        } else {
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.weatherEnabled = true
                                if viewModel.selectedWeatherConditions.isEmpty {
                                    viewModel.selectedWeatherConditions = [.clear]
                                }
                                if viewModel.signalStrengths[.weather] == nil {
                                    viewModel.signalStrengths[.weather] = .boost
                                }
                                expandedCondition = .weather
                            }
                        }
                    }
                }
                
                if !viewModel.sequenceEnabled {
                    addConditionButton(label: "Goal sequence", icon: "arrow.right.arrow.left") {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.sequenceEnabled = true
                            if viewModel.signalStrengths[.goalSequence] == nil {
                                viewModel.signalStrengths[.goalSequence] = .boost
                            }
                            expandedCondition = .goalSequence
                        }
                    }
                }
            }
        }
    }
    
    private func addConditionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Match Mode Toggle
    
    /// Number of active signal conditions (not counting day scheduling).
    private var activeConditionCount: Int {
        var count = 0
        if hasDayTimeCondition { count += 1 }
        if viewModel.weatherEnabled { count += 1 }
        if viewModel.locationEnabled { count += 1 }
        if viewModel.sequenceEnabled { count += 1 }
        return count
    }
    
    private var matchModeToggle: some View {
        HStack(spacing: 0) {
            matchModeButton(.any)
            matchModeButton(.all)
        }
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func matchModeButton(_ mode: ConditionMatchMode) -> some View {
        let isSelected = viewModel.conditionMatchMode == mode
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                viewModel.conditionMatchMode = mode
            }
        } label: {
            VStack(spacing: 2) {
                Text(mode == .any ? "Match ANY" : "Match ALL")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                Text(mode == .any ? "Any condition boosts ranking" : "All conditions must match")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(.systemBackground) : .clear)
                    .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Day & Time Detail
    
    private var hasDayTimeCondition: Bool {
        let hasPreferred = (1...7).contains { viewModel.dayAvailabilities[$0] == .preferred }
        let hasNever = (1...7).contains { viewModel.dayAvailabilities[$0] == .never }
        let allTimes = Set((1...7).flatMap { viewModel.dayTimePreferences[$0] ?? [] })
        let hasSpecificTimes = !allTimes.isEmpty && allTimes.count < TimeOfDay.allCases.count
        return hasPreferred || hasNever || hasSpecificTimes
    }
    
    private var dayTimeSummary: String {
        let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let preferred = (1...7).filter { viewModel.dayAvailabilities[$0] == .preferred }
        var parts: [String] = []
        
        if !preferred.isEmpty {
            parts.append(preferred.map { weekdayNames[$0] }.joined(separator: ", "))
        }
        
        let allTimes = Set((1...7).flatMap { viewModel.dayTimePreferences[$0] ?? [] })
        if !allTimes.isEmpty && allTimes.count < TimeOfDay.allCases.count {
            parts.append(allTimes.sorted().map { $0.displayName.lowercased() }.joined(separator: ", "))
        }
        
        return parts.isEmpty ? "Any" : parts.joined(separator: " · ")
    }
    
    private var dayTimeDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            signalStrengthPicker(for: .timeOfDay)
            
            Divider()
            
            // Day picker
            Text("Days")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                ForEach(WeekdayConstants.weekdays, id: \.0) { weekday, name in
                    let availability = viewModel.dayAvailabilities[weekday] ?? .open
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.cycleDayAvailability(weekday)
                        }
                    } label: {
                        Text(String(name.prefix(1)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: 34, height: 34)
                            .foregroundStyle(dayPillForeground(availability))
                            .background(dayPillBackground(availability))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Legend
            HStack(spacing: 12) {
                legendDot(color: activeThemeColor, label: "Preferred")
                legendDot(color: Color(.systemGray4), label: "Open")
                legendDot(color: .red.opacity(0.6), label: "Never")
            }
            .font(.caption2)
            
            Divider()
            
            // Time of day picker
            Text("Time of day")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                ForEach(TimeOfDay.allCases, id: \.self) { time in
                    let isSelected = isTimeSelected(time)
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            toggleGlobalTime(time)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: time.icon)
                                .font(.caption2)
                            Text(time.displayName)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? activeThemeColor.opacity(0.2) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? activeThemeColor : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? activeThemeColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func isTimeSelected(_ time: TimeOfDay) -> Bool {
        // A time is considered selected if it's in any preferred day's preferences
        let preferredDays = (1...7).filter { viewModel.dayAvailabilities[$0] == .preferred }
        let daysToCheck = preferredDays.isEmpty ? Array(1...7) : preferredDays
        return daysToCheck.contains { viewModel.dayTimePreferences[$0]?.contains(time) ?? false }
    }
    
    private func toggleGlobalTime(_ time: TimeOfDay) {
        let selected = isTimeSelected(time)
        for weekday in 1...7 where viewModel.dayAvailabilities[weekday] != .never {
            if selected {
                viewModel.dayTimePreferences[weekday]?.remove(time)
            } else {
                viewModel.dayTimePreferences[weekday, default: []].insert(time)
                if viewModel.dayAvailabilities[weekday] == .open {
                    viewModel.dayAvailabilities[weekday] = .preferred
                    viewModel.syncActiveDaysFromAvailabilities()
                }
            }
        }
        if viewModel.signalStrengths[.timeOfDay] == nil {
            viewModel.signalStrengths[.timeOfDay] = .boost
        }
    }
    
    // MARK: - Weather Detail
    
    private var weatherSummary: String {
        var parts: [String] = []
        if !viewModel.selectedWeatherConditions.isEmpty {
            parts.append(viewModel.selectedWeatherConditions
                .sorted(by: { $0.displayName < $1.displayName })
                .map { $0.displayName.lowercased() }
                .joined(separator: ", "))
        }
        if viewModel.hasMinTemperature || viewModel.hasMaxTemperature {
            var tempParts: [String] = []
            if viewModel.hasMinTemperature { tempParts.append("≥\(Int(viewModel.minTemperature))°") }
            if viewModel.hasMaxTemperature { tempParts.append("≤\(Int(viewModel.maxTemperature))°") }
            parts.append(tempParts.joined(separator: " "))
        }
        if viewModel.hasMaxWindSpeed {
            parts.append("wind ≤\(Int(viewModel.maxWindSpeed))km/h")
        }
        return parts.isEmpty ? "Any" : parts.joined(separator: " · ")
    }
    
    private var weatherDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            signalStrengthPicker(for: .weather)
            
            Divider()
            
            Text("Weather conditions")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 8) {
                ForEach(WeatherCondition.allCases, id: \.self) { condition in
                    let isSelected = viewModel.selectedWeatherConditions.contains(condition)
                    Button {
                        if isSelected {
                            viewModel.selectedWeatherConditions.remove(condition)
                        } else {
                            viewModel.selectedWeatherConditions.insert(condition)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: condition.icon)
                                .font(.title3)
                            Text(condition.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? activeThemeColor.opacity(0.2) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? activeThemeColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // Temperature
            Toggle(isOn: $viewModel.hasMinTemperature) {
                Text("Minimum temperature")
                    .font(.subheadline)
            }
            if viewModel.hasMinTemperature {
                HStack {
                    Text("\(Int(viewModel.minTemperature))°C")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 50)
                    Slider(value: $viewModel.minTemperature, in: -10...40, step: 1)
                        .tint(activeThemeColor)
                }
            }
            
            Toggle(isOn: $viewModel.hasMaxTemperature) {
                Text("Maximum temperature")
                    .font(.subheadline)
            }
            if viewModel.hasMaxTemperature {
                HStack {
                    Text("\(Int(viewModel.maxTemperature))°C")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 50)
                    Slider(value: $viewModel.maxTemperature, in: -10...40, step: 1)
                        .tint(activeThemeColor)
                }
            }
            
            Toggle(isOn: $viewModel.hasMaxWindSpeed) {
                Text("Maximum wind speed")
                    .font(.subheadline)
            }
            if viewModel.hasMaxWindSpeed {
                HStack {
                    Text("\(Int(viewModel.maxWindSpeed)) km/h")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 65)
                    Slider(value: $viewModel.maxWindSpeed, in: 5...80, step: 5)
                        .tint(activeThemeColor)
                }
            }
        }
    }
    
    // MARK: - Strength Chevron
    
    private func strengthChevron(_ strength: SignalStrength) -> some View {
        let (iconName, color): (String, Color) = switch strength {
        case .boost: ("chevron.up", .green)
        case .require: ("chevron.up.2", .green)
        case .avoid: ("chevron.down", .red)
        }
        return Image(systemName: iconName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
    }
    
    private func signalStrengthPicker(for signalType: SignalType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal effect")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                ForEach(SignalStrength.allCases, id: \.self) { strength in
                    let isSelected = viewModel.signalStrengths[signalType] == strength
                    let (iconName, color): (String, Color) = switch strength {
                    case .boost: ("chevron.up", .green)
                    case .require: ("chevron.up.2", .green)
                    case .avoid: ("chevron.down", .red)
                    }
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            viewModel.signalStrengths[signalType] = strength
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: iconName)
                                .font(.caption2.weight(.bold))
                            Text(strength.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(isSelected ? .white : color)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? color : color.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Goal Sequence Detail
    
    private var goalSequenceSummary: String {
        guard let title = viewModel.sequenceGoalTitle else { return "Not set" }
        let dir = viewModel.sequenceDirection == "before" ? "Before" : "After"
        return "\(dir) \(title)"
    }
    
    /// Goals available for sequence linking (active, excluding the current goal being edited)
    private var availableGoals: [Goal] {
        allGoals.filter { goal in
            goal.status == .active && goal.id.uuidString != viewModel.existingGoal?.id.uuidString
        }
    }
    
    private var goalSequenceDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            signalStrengthPicker(for: .goalSequence)
            
            Divider()
            
            // Direction picker
            Text("Direction")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                directionButton("before", label: "Before", icon: "arrow.left")
                directionButton("after", label: "After", icon: "arrow.right")
            }
            
            Divider()
            
            // Goal picker
            Text("Linked goal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            if availableGoals.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text("No other active goals to link to")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(availableGoals) { goal in
                        let isSelected = viewModel.sequenceGoalID == goal.id.uuidString
                        Button {
                            withAnimation(.snappy(duration: 0.15)) {
                                viewModel.sequenceGoalID = goal.id.uuidString
                                viewModel.sequenceGoalTitle = goal.title
                                viewModel.sequenceGoalIcon = goal.iconName
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: goal.iconName ?? "circle")
                                    .font(.body)
                                    .foregroundStyle(isSelected ? activeThemeColor : .secondary)
                                    .frame(width: 28)
                                
                                Text(goal.title)
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(activeThemeColor)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if goal.id != availableGoals.last?.id {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
            
            // Summary
            if let title = viewModel.sequenceGoalTitle {
                let dir = viewModel.sequenceDirection == "before" ? "before" : "after"
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(activeThemeColor)
                    Text("Recommend this \(dir) completing **\(title)**")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func directionButton(_ direction: String, label: String, icon: String) -> some View {
        let isSelected = viewModel.sequenceDirection == direction
        return Button {
            withAnimation(.snappy(duration: 0.15)) {
                viewModel.sequenceDirection = direction
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? (viewModel.activeThemePreset?.foregroundColor(for: colorScheme) ?? .white) : .primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? activeThemeColor : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Location Detail
    
    private var locationSummary: String {
        if let _ = viewModel.locationLatitude {
            var parts: [String] = []
            if !viewModel.locationName.isEmpty {
                parts.append(viewModel.locationName)
            } else {
                parts.append("Pinned")
            }
            parts.append("\(Int(viewModel.locationRadius))m")
            return parts.joined(separator: " · ")
        }
        return "Not set"
    }
    
    private var locationDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            signalStrengthPicker(for: .location)
            
            Divider()
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search for a place", text: $locationSearchText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        searchLocation()
                    }
                if !locationSearchText.isEmpty {
                    Button {
                        locationSearchText = ""
                        locationSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            
            // Current location button
            Button {
                useCurrentLocation()
            } label: {
                HStack(spacing: 8) {
                    if isFetchingCurrentLocation {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.subheadline)
                            .foregroundStyle(activeThemeColor)
                    }
                    Text("Use Current Location")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
            .disabled(isFetchingCurrentLocation)
            
            // Search results
            if !locationSearchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(locationSearchResults, id: \.self) { item in
                        Button {
                            selectMapItem(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(activeThemeColor)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let subtitle = item.address?.shortAddress ?? item.addressRepresentations?.cityWithContext {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if item != locationSearchResults.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Map view
            Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom]) {
                if let lat = viewModel.locationLatitude, let lon = viewModel.locationLongitude {
                    Annotation(viewModel.locationName.isEmpty ? "Selected" : viewModel.locationName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                        ZStack {
                            Circle()
                                .fill(activeThemeColor)
                                .frame(width: 32, height: 32)
                            Image(systemName: "mappin")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                    
                    MapCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: viewModel.locationRadius)
                        .foregroundStyle(activeThemeColor.opacity(0.15))
                        .stroke(activeThemeColor.opacity(0.4), lineWidth: 1)
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { location in
                // Allow tapping on map to set pin
            }
            
            // Selected location name
            if let _ = viewModel.locationLatitude {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(activeThemeColor)
                    Text(viewModel.locationName.isEmpty ? "Pinned location" : viewModel.locationName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .foregroundStyle(.secondary)
                    Text("Search for a place to pin a location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Radius slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Radius")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("\(Int(viewModel.locationRadius))m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .leading)
                    Slider(value: $viewModel.locationRadius, in: 50...2000, step: 50)
                        .tint(activeThemeColor)
                        .onChange(of: viewModel.locationRadius) {
                            updateMapCamera()
                        }
                }
            }
        }
    }
    
    // MARK: - Location Helpers
    
    private func searchLocation() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationSearchText
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let items = response?.mapItems {
                locationSearchResults = Array(items.prefix(5))
            }
        }
    }
    
    private func selectMapItem(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        viewModel.locationLatitude = coordinate.latitude
        viewModel.locationLongitude = coordinate.longitude
        viewModel.locationName = item.name ?? ""
        
        locationSearchText = ""
        locationSearchResults = []
        
        updateMapCamera()
        
        withAnimation(.snappy(duration: 0.2)) {
            expandedCondition = nil
        }
    }
    
    private func useCurrentLocation() {
        isFetchingCurrentLocation = true
        locationManager.requestLocation { result in
            isFetchingCurrentLocation = false
            switch result {
            case .success(let location):
                viewModel.locationLatitude = location.coordinate.latitude
                viewModel.locationLongitude = location.coordinate.longitude
                
                // Reverse geocode to get a place name
                if let request = MKReverseGeocodingRequest(location: location) {
                    request.getMapItems { items, _ in
                        if let item = items?.first, let name = item.name {
                            viewModel.locationName = name
                        } else {
                            viewModel.locationName = "Current Location"
                        }
                    }
                } else {
                    viewModel.locationName = "Current Location"
                }
                
                locationSearchText = ""
                locationSearchResults = []
                updateMapCamera()
            case .failure:
                break
            }
        }
    }
    
    private func updateMapCamera() {
        if let lat = viewModel.locationLatitude, let lon = viewModel.locationLongitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // Show a region that encompasses the radius with some padding
            let regionRadius = max(viewModel.locationRadius * 2.5, 500)
            mapCameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: regionRadius,
                longitudinalMeters: regionRadius
            ))
        }
    }
    
    // MARK: - Remove Condition
    
    private func removeCondition(_ type: ConditionType) {
        switch type {
        case .dayTime:
            // Reset all days to open, all times to all
            for weekday in 1...7 {
                viewModel.dayAvailabilities[weekday] = .open
                viewModel.dayTimePreferences[weekday] = Set(TimeOfDay.allCases)
            }
            viewModel.syncActiveDaysFromAvailabilities()
            viewModel.signalStrengths.removeValue(forKey: .timeOfDay)
        case .weather:
            viewModel.removeSignal(.weather)
        case .location:
            viewModel.removeSignal(.location)
        case .goalSequence:
            viewModel.removeSignal(.goalSequence)
        }
    }
    
    // MARK: - Helpers
    
    private func dayPillForeground(_ availability: DayAvailability) -> Color {
        switch availability {
        case .preferred:
            return viewModel.activeThemePreset?.foregroundColor(for: colorScheme) ?? .white
        case .open: return .secondary
        case .never: return .red
        }
    }
    
    private func dayPillBackground(_ availability: DayAvailability) -> Color {
        switch availability {
        case .preferred: return activeThemeColor
        case .open: return Color(.systemGray5)
        case .never: return .red.opacity(0.15)
        }
    }
    
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("Momentum will suggest this")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(activeThemeColor)
            }
            
            Text(buildRichSummary())
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func buildRichSummary() -> AttributedString {
        let weekdayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let joiner = viewModel.conditionMatchMode == .all ? " and " : " or "
        var result = AttributedString()
        var isFirstSignal = true
        
        // Preferred days
        let preferred = (1...7).filter { viewModel.dayAvailabilities[$0] == .preferred }
        let never = (1...7).filter { viewModel.dayAvailabilities[$0] == .never }
        
        if !preferred.isEmpty {
            var days = AttributedString(preferred.map { weekdayNames[$0] }.joined(separator: ", "))
            days.font = .subheadline.bold()
            result += days
        } else {
            var any = AttributedString("Any day")
            any.font = .subheadline
            any.foregroundColor = .secondary
            result += any
        }
        
        // Time of day
        let allTimes = Set((1...7).flatMap { viewModel.dayTimePreferences[$0] ?? [] })
        if !allTimes.isEmpty && allTimes.count < TimeOfDay.allCases.count {
            var sep = AttributedString(isFirstSignal ? " · " : joiner)
            sep.font = .subheadline
            sep.foregroundColor = .secondary
            result += sep
            isFirstSignal = false
            
            var times = AttributedString(allTimes.sorted().map { $0.displayName.lowercased() }.joined(separator: ", "))
            times.font = .subheadline.bold()
            result += times
        }
        
        // Weather
        if viewModel.weatherEnabled && !viewModel.selectedWeatherConditions.isEmpty {
            var sep = AttributedString(isFirstSignal ? " · " : joiner)
            sep.font = .subheadline
            sep.foregroundColor = .secondary
            result += sep
            isFirstSignal = false
            
            var conditions = AttributedString(
                viewModel.selectedWeatherConditions
                    .sorted(by: { $0.displayName < $1.displayName })
                    .map { $0.displayName.lowercased() }
                    .joined(separator: ", ")
            )
            conditions.font = .subheadline.bold()
            result += conditions
        }
        
        // Wind speed
        if viewModel.weatherEnabled && viewModel.hasMaxWindSpeed {
            var sep = AttributedString(isFirstSignal ? " · " : joiner)
            sep.font = .subheadline
            sep.foregroundColor = .secondary
            result += sep
            isFirstSignal = false
            
            var w = AttributedString("wind ≤\(Int(viewModel.maxWindSpeed)) km/h")
            w.font = .subheadline.bold()
            result += w
        }
        
        // Goal sequence
        if viewModel.sequenceEnabled, let title = viewModel.sequenceGoalTitle {
            var sep = AttributedString(isFirstSignal ? " · " : joiner)
            sep.font = .subheadline
            sep.foregroundColor = .secondary
            result += sep
            isFirstSignal = false
            
            let dir = viewModel.sequenceDirection == "before" ? "before" : "after"
            var seq = AttributedString("\(dir) \(title)")
            seq.font = .subheadline.bold()
            result += seq
        }
        
        // Location
        if viewModel.locationEnabled, viewModel.locationLatitude != nil {
            var sep = AttributedString(isFirstSignal ? " · " : joiner)
            sep.font = .subheadline
            sep.foregroundColor = .secondary
            result += sep
            isFirstSignal = false
            
            let locText = viewModel.locationName.isEmpty ? "pinned location" : "near \(viewModel.locationName)"
            var loc = AttributedString(locText)
            loc.font = .subheadline.bold()
            result += loc
        }
        
        // Estimate
        let estimatedTimes = max(preferred.count, 1)
        var estimate = AttributedString(" · ≈ \(estimatedTimes)× this week")
        estimate.font = .subheadline
        estimate.foregroundColor = .secondary
        result += estimate
        
        let openCount = (1...7).filter { viewModel.dayAvailabilities[$0] == .open }.count
        if openCount > 0 {
            var stillOpen = AttributedString(" · still openable anytime")
            stillOpen.font = .subheadline
            stillOpen.foregroundColor = .secondary
            result += stillOpen
        }
        
        // Never days
        if !never.isEmpty {
            var nev = AttributedString(". Never ")
            nev.font = .subheadline
            nev.foregroundColor = .secondary
            result += nev
            
            var nevDays = AttributedString(never.map { weekdayNames[$0] }.joined(separator: ", "))
            nevDays.font = .subheadline.bold()
            nevDays.foregroundColor = UIColor.systemRed
            result += nevDays
        }
        
        return result
    }
}

// MARK: - Location Manager Helper

@Observable
private class LocationManagerHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Result<CLLocation, Error>) -> Void)?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        self.completion = completion
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            completion(.failure(LocationError.denied))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            completion?(.success(location))
            completion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            if completion != nil {
                manager.requestLocation()
            }
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            completion?(.failure(LocationError.denied))
            completion = nil
        }
    }
    
    enum LocationError: Error {
        case denied
    }
}
