//
//  DebugScoreView.swift
//  Momentum
//
//  Debug view showing the deterministic recommender's scoring breakdown for all goals.
//

import SwiftUI
import SwiftData
import MomentumKit

struct DebugScoreView: View {
    @Query private var allGoals: [Goal]
    @Query private var sessions: [GoalSession]
    
    private var goals: [Goal] {
        allGoals.filter { $0.status == .active }
    }
    
    @State private var scoredGoals: [ScoredGoal] = []
    @State private var context: DeterministicRecommender.Context?
    
    private let recommender = DeterministicRecommender()
    
    var body: some View {
        List {
            if let context {
                Section {
                    contextRow("Time of Day", value: context.timeOfDay?.rawValue.capitalized ?? "Unknown")
                    contextRow("Weather", value: context.weather?.rawValue.capitalized ?? "None")
                    contextRow("Temperature", value: context.temperature.map { "\(Int($0))°" } ?? "None")
                    contextRow("Wind", value: context.windSpeed.map { "\(Int($0)) km/h" } ?? "None")
                    contextRow("Weekday", value: weekdayName(for: context.currentDate))
                } header: {
                    Text("Current Context")
                }
            }
            
            Section {
                if scoredGoals.isEmpty {
                    Text("No active goals found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(scoredGoals.enumerated()), id: \.element.id) { index, scored in
                        GoalScoreRow(rank: index + 1, scored: scored)
                    }
                }
            } header: {
                Text("Goal Rankings (\(scoredGoals.count) goals)")
            } footer: {
                Text("Max possible: 135 pts (Weather 25 + Progress 30 + Time 20 + Deadline 15 + Flexibility 25 + Sequence 20)")
            }
        }
        .navigationTitle("Score Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recalculate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            recalculate()
        }
    }
    
    private func contextRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private func weekdayName(for date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return calendar.weekdaySymbols[weekday - 1]
    }
    
    private func recalculate() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let timeOfDay = TimeOfDay.from(hour: hour)
        
        let ctx = DeterministicRecommender.Context(
            currentDate: now,
            weather: nil,
            temperature: nil,
            timeOfDay: timeOfDay,
            location: nil,
            weekdayAvailability: nil
        )
        self.context = ctx
        
        // Get full recommendations (no limit) to see all goals
        let recommendations = recommender.recommend(
            goals: goals,
            sessions: sessions,
            context: ctx,
            limit: goals.count
        )
        
        // Also compute individual component scores for each goal
        scoredGoals = recommendations.map { rec in
            let goal = rec.goal
            let components = computeComponentScores(for: goal, sessions: sessions, context: ctx)
            
            // Determine configured signals
            var signals: [String] = []
            if goal.hasSignal(.weather) { signals.append("Weather") }
            if goal.hasSignal(.timeOfDay) { signals.append("Time") }
            if goal.sequenceEnabled { signals.append("Sequence") }
            
            // Determine match-ALL pass/fail
            var matchAllPassed: Bool? = nil
            if goal.conditionMatchMode == .all && !signals.isEmpty {
                // Check if each signal scored above 10% of its max
                var allPassed = true
                if goal.hasSignal(.weather) {
                    allPassed = allPassed && components.weather > recommender.weights.weatherContext * 0.1
                }
                if goal.hasSignal(.timeOfDay) {
                    allPassed = allPassed && components.timeOfDay > recommender.weights.timeOfDay * 0.1
                }
                if goal.sequenceEnabled {
                    allPassed = allPassed && components.goalSequence > recommender.weights.goalSequence * 0.1
                }
                matchAllPassed = allPassed
            }
            
            // Weather source
            let weatherSource: String
            if goal.weatherEnabled, let conditions = goal.weatherConditions, !conditions.isEmpty {
                weatherSource = "Goal config"
            } else if goal.primaryTag != nil {
                weatherSource = "Tag-based"
            } else {
                weatherSource = "None (neutral)"
            }
            
            return ScoredGoal(
                id: goal.id,
                title: goal.title,
                totalScore: rec.score,
                reasons: rec.reasons,
                components: components,
                tagName: goal.primaryTag?.title,
                matchMode: goal.conditionMatchMode,
                configuredSignals: signals,
                matchAllPassed: matchAllPassed,
                weatherSource: weatherSource
            )
        }
    }
    
    /// Recompute individual scoring components for display
    /// This mirrors DeterministicRecommender.scoreGoal but exposes each component
    private func computeComponentScores(
        for goal: Goal,
        sessions: [GoalSession],
        context: DeterministicRecommender.Context
    ) -> ScoreComponents {
        let weights = recommender.weights
        
        // Weather — use goal-level config when available, else fall back to tag-based
        let weatherScore: Double
        if goal.weatherEnabled, let conditions = goal.weatherConditions, !conditions.isEmpty {
            guard let currentWeather = context.weather else {
                weatherScore = weights.weatherContext * 0.5
                return buildComponents(weather: weatherScore, goal: goal, sessions: sessions, context: context, weights: weights)
            }
            let conditionMatches = conditions.contains(currentWeather.rawValue)
            var tempMatches = true
            if let minTemp = goal.minTemperature, let temp = context.temperature {
                tempMatches = tempMatches && temp >= minTemp
            }
            if let maxTemp = goal.maxTemperature, let temp = context.temperature {
                tempMatches = tempMatches && temp <= maxTemp
            }
            var windMatches = true
            if let maxWind = goal.maxWindSpeed, let wind = context.windSpeed {
                windMatches = wind <= maxWind
            }
            weatherScore = (conditionMatches && tempMatches && windMatches) ? weights.weatherContext : 0.0
        } else if let tag = goal.primaryTag {
            let contextScore = tag.contextMatchScore(
                weather: context.weather,
                temperature: context.temperature,
                windSpeed: context.windSpeed,
                timeOfDay: context.timeOfDay,
                location: context.location
            )
            weatherScore = contextScore * weights.weatherContext
        } else {
            weatherScore = weights.weatherContext * 0.5
        }
        
        return buildComponents(weather: weatherScore, goal: goal, sessions: sessions, context: context, weights: weights)
    }
    
    private func buildComponents(
        weather weatherScore: Double,
        goal: Goal,
        sessions: [GoalSession],
        context: DeterministicRecommender.Context,
        weights: DeterministicRecommender.ScoringWeights
    ) -> ScoreComponents {
        // Weekly Progress
        let progressScore: Double = {
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: context.currentDate)?.start ?? context.currentDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? context.currentDate
            let elapsedTime = context.currentDate.timeIntervalSince(weekStart)
            let weekDuration: TimeInterval = 7 * 24 * 60 * 60
            let weekProgress = elapsedTime / weekDuration
            let expectedProgress = goal.unifiedWeeklyTarget * weekProgress
            
            let actualProgress = sessions
                .filter { session in
                    session.goalID == goal.id.uuidString &&
                    session.day?.startDate ?? .distantPast >= weekStart &&
                    session.day?.startDate ?? .distantPast < weekEnd
                }
                .reduce(0.0) { $0 + $1.currentValue }
            
            let deficit = expectedProgress - actualProgress
            if deficit > 0 {
                let deficitPercentage = min(1.0, deficit / max(goal.unifiedWeeklyTarget, 1))
                return deficitPercentage * weights.weeklyProgress
            }
            return weights.weeklyProgress * 0.2
        }()
        
        // Time of Day
        let timeScore: Double = {
            guard let timeOfDay = context.timeOfDay else {
                return weights.timeOfDay * 0.5
            }
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: context.currentDate)
            let preferredTimes = goal.timesForWeekday(weekday)
            if preferredTimes.isEmpty {
                return weights.timeOfDay * 0.5
            }
            return preferredTimes.contains(timeOfDay) ? weights.timeOfDay : weights.timeOfDay * 0.1
        }()
        
        // Deadline
        let deadlineScore: Double = {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: context.currentDate)
            let preferredTimes = goal.timesForWeekday(weekday)
            if !preferredTimes.isEmpty, let timeOfDay = context.timeOfDay {
                if preferredTimes.contains(timeOfDay) {
                    let currentHour = calendar.component(.hour, from: context.currentDate)
                    let isLate: Bool = {
                        switch timeOfDay {
                        case .morning: return currentHour >= 9
                        case .midday: return currentHour >= 13
                        case .afternoon: return currentHour >= 16
                        case .evening: return currentHour >= 20
                        case .night: return currentHour >= 23
                        }
                    }()
                    if isLate { return weights.deadline }
                }
            }
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: context.currentDate)?.start ?? context.currentDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? context.currentDate
            let remainingTime = weekEnd.timeIntervalSince(context.currentDate)
            let weekDuration: TimeInterval = 7 * 24 * 60 * 60
            if remainingTime < weekDuration * 0.2 {
                return weights.deadline * 0.7
            }
            return 0.0
        }()
        
        // Schedule Flexibility
        let flexibilityScore: Double = {
            let calendar = Calendar.current
            let currentWeekday = calendar.component(.weekday, from: context.currentDate)
            
            if goal.hasRelevanceRule {
                let availability = goal.dayAvailability(for: currentWeekday)
                switch availability {
                case .preferred: break
                case .open: return weights.scheduleFlexibility * 0.4
                case .never: return 0.0
                }
            }
            
            guard let weekdayAvailability = context.weekdayAvailability,
                  goal.hasSchedule else {
                return 0.0
            }
            
            let scheduledWeekdays = goal.scheduledWeekdays
            let isTodayScheduled = scheduledWeekdays.contains(currentWeekday)
            
            if isTodayScheduled {
                let todayAvail = weekdayAvailability[currentWeekday] ?? 0
                if todayAvail < 1800 { return weights.scheduleFlexibility * 0.3 }
                return 0.0
            }
            
            let scheduledDaysAvail = scheduledWeekdays.compactMap { weekdayAvailability[$0] }
            guard !scheduledDaysAvail.isEmpty else { return 0.0 }
            
            let avgScheduledAvail = scheduledDaysAvail.reduce(0.0, +) / Double(scheduledDaysAvail.count)
            let todayAvail = weekdayAvailability[currentWeekday] ?? 0
            
            if avgScheduledAvail < 1800 && todayAvail > 3600 { return weights.scheduleFlexibility }
            if avgScheduledAvail < 7200 && todayAvail > 1800 { return weights.scheduleFlexibility * 0.6 }
            if todayAvail < 1800 { return weights.scheduleFlexibility * 0.1 }
            return 0.0
        }()
        
        // Goal Sequence
        let sequenceScore: Double = {
            guard goal.sequenceEnabled,
                  let linkedGoalID = goal.sequenceGoalID,
                  let direction = goal.sequenceDirection else {
                return 0.0
            }
            let linkedSession = sessions.first { $0.goalID == linkedGoalID }
            switch direction {
            case "after":
                if let session = linkedSession, session.hasMetDailyTarget {
                    return weights.goalSequence
                }
                if let session = linkedSession, session.currentValue > 0 {
                    return weights.goalSequence * 0.3
                }
                return 0.0
            case "before":
                if let session = linkedSession, session.currentValue == 0 && !session.hasMetDailyTarget {
                    return weights.goalSequence
                }
                if linkedSession == nil {
                    return weights.goalSequence * 0.8
                }
                return 0.0
            default:
                return 0.0
            }
        }()
        
        return ScoreComponents(
            weather: weatherScore,
            weeklyProgress: progressScore,
            timeOfDay: timeScore,
            deadline: deadlineScore,
            scheduleFlexibility: flexibilityScore,
            goalSequence: sequenceScore
        )
    }
}

// MARK: - Models

struct ScoredGoal: Identifiable {
    let id: UUID
    let title: String
    let totalScore: Double
    let reasons: [RecommendationReason]
    let components: ScoreComponents
    let tagName: String?
    let matchMode: ConditionMatchMode
    let configuredSignals: [String]
    let matchAllPassed: Bool?
    let weatherSource: String
}

struct ScoreComponents {
    let weather: Double
    let weeklyProgress: Double
    let timeOfDay: Double
    let deadline: Double
    let scheduleFlexibility: Double
    let goalSequence: Double
    
    static let maxValues = ScoreComponents(
        weather: 25.0,
        weeklyProgress: 30.0,
        timeOfDay: 20.0,
        deadline: 15.0,
        scheduleFlexibility: 25.0,
        goalSequence: 20.0
    )
}

// MARK: - Goal Score Row

struct GoalScoreRow: View {
    let rank: Int
    let scored: ScoredGoal
    
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                // Match mode & signals info
                HStack(spacing: 6) {
                    Text(scored.matchMode == .all ? "Match ALL" : "Match ANY")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(scored.matchMode == .all ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2), in: Capsule())
                    
                    if let passed = scored.matchAllPassed {
                        Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(passed ? .green : .red)
                        Text(passed ? "All matched" : "Not all matched")
                            .font(.caption2)
                            .foregroundStyle(passed ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Text("Weather: \(scored.weatherSource)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if !scored.configuredSignals.isEmpty {
                    HStack(spacing: 4) {
                        Text("Signals:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(scored.configuredSignals, id: \.self) { signal in
                            Text(signal)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.fill.quaternary, in: Capsule())
                        }
                        Spacer()
                    }
                }
                
                Divider()
                
                // Score bars
                ScoreBar(label: "Weather", score: scored.components.weather, max: ScoreComponents.maxValues.weather, color: .blue)
                ScoreBar(label: "Weekly Progress", score: scored.components.weeklyProgress, max: ScoreComponents.maxValues.weeklyProgress, color: .orange)
                ScoreBar(label: "Time of Day", score: scored.components.timeOfDay, max: ScoreComponents.maxValues.timeOfDay, color: .purple)
                ScoreBar(label: "Deadline", score: scored.components.deadline, max: ScoreComponents.maxValues.deadline, color: .red)
                ScoreBar(label: "Flexibility", score: scored.components.scheduleFlexibility, max: ScoreComponents.maxValues.scheduleFlexibility, color: .green)
                ScoreBar(label: "Sequence", score: scored.components.goalSequence, max: ScoreComponents.maxValues.goalSequence, color: .teal)
                
                if !scored.reasons.isEmpty {
                    Divider()
                    HStack {
                        Text("Reasons:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    FlowLayout(spacing: 4) {
                        ForEach(scored.reasons, id: \.self) { reason in
                            HStack(spacing: 3) {
                                Image(systemName: reason.icon)
                                    .font(.caption2)
                                Text(reason.displayName)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.fill.tertiary, in: Capsule())
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 10) {
                Text("#\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(rank <= 3 ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(rank <= 3 ? rankColor(rank) : Color.clear)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(scored.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let tagName = scored.tagName {
                        Text(tagName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(String(format: "%.1f", scored.totalScore))
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(scoreColor(scored.totalScore))
            }
        }
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow.opacity(0.8)
        case 2: return .gray
        case 3: return .orange.opacity(0.7)
        default: return .clear
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Score Bar

struct ScoreBar: View {
    let label: String
    let score: Double
    let max: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.fill.tertiary)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.7))
                        .frame(width: max > 0 ? geo.size.width * CGFloat(score / max) : 0)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f", score))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

#Preview {
    NavigationStack {
        DebugScoreView()
    }
}
