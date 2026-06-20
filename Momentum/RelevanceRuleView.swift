import SwiftUI
import MomentumKit

struct RelevanceRuleView: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var expandedSignal: SignalType?
    @State private var showingPremiumPaywall = false
    
    private let timeSlots: [TimeOfDay] = [.morning, .midday, .afternoon, .evening, .night]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    dayAvailabilitySection
                    signalsSection
                }
                .padding()
                .padding(.bottom, 160)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    summaryCard
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Save Rule")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(viewModel.activeThemePreset?.foregroundColor(for: colorScheme) ?? .white)
                            .background(activeThemeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Relevance Rule")
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
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Recommend by Relevance")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(activeThemeColor)
            }
            
            Text(viewModel.userInput.isEmpty ? "New Goal" : viewModel.userInput)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Momentum **scores** this goal against the moment. More signals — and stronger ones — promote it higher. No single thing is required unless you say so.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Day Availability
    
    private var dayAvailabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Your week")
                    .font(.headline)
            } icon: {
                Text("1")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.primary))
            }
            
            // Time-of-day labels on left + day bar columns
            HStack(alignment: .top, spacing: 0) {
                // Time labels column
                VStack(alignment: .trailing, spacing: 0) {
                    // Spacer for the day-name header
                    Text("M")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .hidden()
                        .padding(.bottom, 6)
                    
                    ForEach(timeSlots, id: \.self) { time in
                        Image(systemName: time.icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(height: 28)
                    }
                }
                .padding(.trailing, 8)
                
                // Day columns
                HStack(spacing: 6) {
                    ForEach(WeekdayConstants.weekdays, id: \.0) { weekday, name in
                        dayBarColumn(weekday: weekday, name: String(name.prefix(1)))
                    }
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                legendDot(color: activeThemeColor, label: "Preferred")
                legendDot(color: Color(.systemGray4), label: "Open")
                legendDot(color: .red.opacity(0.7), label: "Never")
            }
            .font(.caption2)
            
            // Explanation
            Text("Tap the **day label** to cycle availability. Tap **segments** to pick preferred times of day.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
    
    private func dayBarColumn(weekday: Int, name: String) -> some View {
        let availability = viewModel.dayAvailabilities[weekday] ?? .open
        let selectedTimes = viewModel.dayTimePreferences[weekday] ?? []
        let isNever = availability == .never
        
        return VStack(spacing: 0) {
            // Day label — tap to cycle availability
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    viewModel.cycleDayAvailability(weekday)
                }
            } label: {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(dayLabelColor(availability))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
            
            // Segmented bar
            VStack(spacing: 1.5) {
                ForEach(timeSlots, id: \.self) { time in
                    let isSelected = selectedTimes.contains(time) && !isNever
                    
                    Button {
                        guard !isNever else { return }
                        withAnimation(.snappy(duration: 0.15)) {
                            toggleTime(time, forWeekday: weekday)
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(segmentFill(availability: availability, isSelected: isSelected))
                            .frame(height: 28)
                            .overlay {
                                if isNever && time == .afternoon {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isNever)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity)
        }
    }
    
    private func segmentFill(availability: DayAvailability, isSelected: Bool) -> Color {
        switch availability {
        case .never:
            return .red.opacity(0.25)
        case .preferred:
            return isSelected ? activeThemeColor : activeThemeColor.opacity(0.12)
        case .open:
            return isSelected ? activeThemeColor : Color(.systemGray5)
        }
    }
    
    private func toggleTime(_ time: TimeOfDay, forWeekday weekday: Int) {
        var times = viewModel.dayTimePreferences[weekday] ?? []
        if times.contains(time) {
            times.remove(time)
        } else {
            times.insert(time)
            // If they're selecting times on an open day, auto-promote to preferred
            if viewModel.dayAvailabilities[weekday] == .open {
                viewModel.dayAvailabilities[weekday] = .preferred
                viewModel.syncActiveDaysFromAvailabilities()
            }
        }
        viewModel.dayTimePreferences[weekday] = times
        
        // Enable time-of-day signal if not already
        if viewModel.signalStrengths[.timeOfDay] == nil && !times.isEmpty {
            viewModel.signalStrengths[.timeOfDay] = .boost
        }
    }
    
    private func dayLabelColor(_ availability: DayAvailability) -> Color {
        switch availability {
        case .preferred: return activeThemeColor
        case .open: return .secondary
        case .never: return .red
        }
    }
    
    // MARK: - Signals
    
    /// Signal types shown as cards (time-of-day is handled by the day bars above)
    private var cardSignalTypes: [SignalType] {
        [.weather, .location]
    }
    
    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("What makes it a good time")
                    .font(.headline)
            } icon: {
                Text("2")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.primary))
            }
            
            VStack(spacing: 8) {
                // Active signals
                ForEach(cardSignalTypes) { signalType in
                    if viewModel.hasSignalConfigured(signalType) {
                        signalRow(signalType)
                    }
                }
                
                // Add buttons for unconfigured signals
                let unconfigured = cardSignalTypes.filter { !viewModel.hasSignalConfigured($0) }
                if !unconfigured.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(unconfigured) { signalType in
                            addSignalButton(signalType)
                        }
                    }
                }
            }
        }
    }
    
    private func signalRow(_ signalType: SignalType) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: signalType.icon)
                    .font(.title3)
                    .foregroundStyle(activeThemeColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(signalType.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                        Text(viewModel.signalValueSummary(signalType))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Strength badge
                strengthBadge(for: signalType)
                
                // Remove button
                Button {
                    withAnimation { viewModel.removeSignal(signalType) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                
                // Expand chevron
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        expandedSignal = expandedSignal == signalType ? nil : signalType
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expandedSignal == signalType ? 90 : 0))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            
            // Expanded detail
            if expandedSignal == signalType {
                Divider()
                    .padding(.horizontal, 12)
                signalDetailView(signalType)
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func strengthBadge(for signalType: SignalType) -> some View {
        let strength = viewModel.signalStrengths[signalType] ?? .boost
        let color = strengthColor(strength)
        
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                viewModel.toggleSignalStrength(signalType)
            }
        } label: {
            HStack(spacing: 4) {
                Text(strength.displayName.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func strengthColor(_ strength: SignalStrength) -> Color {
        switch strength {
        case .boost: return .green
        case .require: return activeThemeColor
        case .avoid: return .red
        }
    }
    
    private func addSignalButton(_ signalType: SignalType) -> some View {
        Button {
            if signalType == .weather && !SubscriptionManager.shared.isSubscribed {
                showingPremiumPaywall = true
            } else {
                withAnimation {
                    enableSignal(signalType)
                    expandedSignal = signalType
                }
            }
        } label: {
            Label(signalType.displayName, systemImage: signalType.icon)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func enableSignal(_ signalType: SignalType) {
        viewModel.signalStrengths[signalType] = .boost
        switch signalType {
        case .weather:
            viewModel.weatherEnabled = true
            if viewModel.selectedWeatherConditions.isEmpty {
                viewModel.selectedWeatherConditions = [.clear]
            }
        case .timeOfDay, .location:
            break
        }
    }
    
    // MARK: - Signal Detail Views
    
    @ViewBuilder
    private func signalDetailView(_ signalType: SignalType) -> some View {
        switch signalType {
        case .weather:
            weatherDetail
        case .location:
            Text("Location-based signals coming soon.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .timeOfDay:
            EmptyView()
        }
    }
    
    private var weatherDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather conditions")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
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
                                .fill(isSelected ? activeThemeColor.opacity(0.2) : Color(.systemGray5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? activeThemeColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Temperature toggles
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
    
    // MARK: - Summary Card (pinned above Save)
    
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
        var result = AttributedString()
        
        // Preferred days
        let preferred = (1...7).filter { viewModel.dayAvailabilities[$0] == .preferred }
        let never = (1...7).filter { viewModel.dayAvailabilities[$0] == .never }
        
        if !preferred.isEmpty {
            var prefix = AttributedString("Usually ")
            prefix.font = .subheadline
            prefix.foregroundColor = .secondary
            result += prefix
            
            var days = AttributedString(preferred.map { weekdayNames[$0] }.joined(separator: ", "))
            days.font = .subheadline.bold()
            result += days
        } else {
            var any = AttributedString("Any day")
            any.font = .subheadline
            any.foregroundColor = .secondary
            result += any
        }
        
        // Signals
        var signalParts: [AttributedString] = []
        
        // Time of day
        let allTimes = (1...7).flatMap { viewModel.dayTimePreferences[$0] ?? [] }
        let uniqueTimes = Set(allTimes)
        if !uniqueTimes.isEmpty && uniqueTimes.count < TimeOfDay.allCases.count {
            for (i, time) in uniqueTimes.sorted().enumerated() {
                if i > 0 {
                    var sep = AttributedString(", ")
                    sep.font = .subheadline
                    sep.foregroundColor = .secondary
                    signalParts.append(sep)
                }
                var t = AttributedString(time.displayName)
                t.font = .subheadline.bold()
                t.foregroundColor = UIColor(activeThemeColor)
                signalParts.append(t)
            }
        }
        
        // Weather
        if viewModel.weatherEnabled && !viewModel.selectedWeatherConditions.isEmpty {
            for (i, condition) in viewModel.selectedWeatherConditions.sorted(by: { $0.displayName < $1.displayName }).enumerated() {
                if i > 0 || !signalParts.isEmpty {
                    var sep = AttributedString(signalParts.isEmpty ? "" : ", ")
                    sep.font = .subheadline
                    sep.foregroundColor = .secondary
                    signalParts.append(sep)
                }
                var c = AttributedString(condition.displayName)
                c.font = .subheadline.bold()
                c.foregroundColor = UIColor(activeThemeColor)
                signalParts.append(c)
            }
        }
        
        // Wind speed
        if viewModel.weatherEnabled && viewModel.hasMaxWindSpeed {
            if !signalParts.isEmpty {
                var sep = AttributedString(", ")
                sep.font = .subheadline
                sep.foregroundColor = .secondary
                signalParts.append(sep)
            }
            var w = AttributedString("wind ≤\(Int(viewModel.maxWindSpeed)) km/h")
            w.font = .subheadline.bold()
            w.foregroundColor = UIColor(activeThemeColor)
            signalParts.append(w)
        }
        
        if !signalParts.isEmpty {
            var dot = AttributedString(". Promoted when ")
            dot.font = .subheadline
            dot.foregroundColor = .secondary
            result += dot
            for part in signalParts {
                result += part
            }
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
        
        var period = AttributedString(".")
        period.font = .subheadline
        period.foregroundColor = .secondary
        result += period
        
        return result
    }
    

}
