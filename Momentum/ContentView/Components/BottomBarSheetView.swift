//
//  BottomBarSheetView.swift
//  Momentum
//
//  Persistent bottom sheet — collapsed shows the bar, expanded shows tab content.
//

import SwiftUI
import SwiftData
import EventKit
import WeatherKit
import MomentumKit

struct BottomBarSheetView: View {
    let navigation: NavigationState
    let day: Day
    let sessions: [GoalSession]
    let timerManager: SessionTimerManager?
    let planningViewModel: PlanningViewModel
    let animation: Namespace.ID
    @Binding var goalEditorViewModel: GoalEditorViewModel?
    let availableGoalThemes: [GoalTag]
    let weatherManager: WeatherManager
    let calendarEventStore: EKEventStore
    let onToggleTimer: (GoalSession) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(GoalStore.self) private var goalStore
    @Query private var goals: [Goal]
    
    @State private var calendarEvents: [EKEvent] = []
    
    private var isExpanded: Bool {
        navigation.bottomSheetDetent == .large
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Now playing bar (if active)
            if let timerManager,
               let activeSession = timerManager.activeSession,
               let session = sessions.first(where: { $0.id == activeSession.id }) {
                nowPlayingBar(session: session, details: activeSession)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                // Context info row (idle)
                contextInfoRow
                    .padding(.top, 4)
            }
            
            // Tab bar — always visible
            tabBar
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, isExpanded ? 8 : 0)
            
            // Expanded content — only when sheet is pulled up
            if isExpanded {
                Divider()
                    .padding(.horizontal, 20)
                
                TabView(selection: Binding(
                    get: { navigation.selectedBottomTab },
                    set: { navigation.selectedBottomTab = $0 }
                )) {
                    
                    nowPlayingContent
                        .tag(BottomBarTab.nowPlaying)
                    planTabContent
                        .tag(BottomBarTab.plan)
                    
                    goalsTabContent
                        .tag(BottomBarTab.goals)
                    
                    analyticsTabContent
                        .tag(BottomBarTab.analytics)
                    
                    searchTabContent
                        .tag(BottomBarTab.search)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
    
    // MARK: - Context Info (Idle state)
    
    private var contextInfoRow: some View {
        HStack(spacing: 10) {
            if !availableGoalThemes.isEmpty {
                Text("\(availableGoalThemes.count) themes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("·")
                    .foregroundStyle(.quaternary)
                    .font(.caption)
            }
            
            Text("\(sessions.filter { $0.progress < 1.0 }.count) remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(BottomBarTab.allCases, id: \.self) { tab in
                let isSelected = isExpanded && navigation.selectedBottomTab == tab
                
                Button {
                    if isExpanded {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            navigation.selectedBottomTab = tab
                        }
                    } else {
                        navigation.selectedBottomTab = tab
                        withAnimation {
                            navigation.bottomSheetDetent = .large
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Now Playing Bar
    
    private func nowPlayingBar(session: GoalSession, details: ActiveSessionDetails) -> some View {
        Button {
            navigation.bottomSheetDetent = .height(120)
            navigation.showNowPlaying = true
        } label: {
            HStack(spacing: 10) {
                CircularProgressView(
                    progress: details.progress,
                    lineWidth: 3,
                    size: 34,
                    foregroundColor: session.theme.color(for: colorScheme),
                    backgroundColor: session.theme.color(for: colorScheme).opacity(0.2),
                    animateOnAppear: false
                )
                .overlay {
                    Image(systemName: session.goal?.iconName ?? "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(session.theme.color(for: colorScheme))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    
                    Text("\(details.currentValue.formatted(style: .hmmss)) · \(Int(details.progress * 100))% of \(details.dailyTarget.formatted(style: .hourMinute))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                
                Spacer(minLength: 0)
                
                // Pause / Stop
                HStack(spacing: 6) {
                    Button {
                        navigation.bottomSheetDetent = .height(120)
                        navigation.showNowPlaying = true
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(session.theme.foregroundColor(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(session.theme.color(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onToggleTimer(session)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(session.theme.color(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(session.theme.color(for: colorScheme).opacity(0.2), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(session.theme.gradient(for: colorScheme).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Plan Tab
    
    private var planTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                planHeader
                
                // Weather Window
                weatherWindowSection
                
                // Open Blocks Timeline
                openBlocksSection
                
                // Themes in Play
                themesInPlaySection
                
                // The Week Ahead
                weekAheadSection
            }
            .padding(.bottom, 40)
        }
        .task {
            fetchCalendarEvents()
        }
    }
    
    // MARK: - Plan Header
    
    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's plan")
                .font(.title.bold())
            
            HStack(spacing: 4) {
                Text(day.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(sessions.count) goals scheduled")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Weather Window
    
    private var weatherWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("WEATHER WINDOW")
            
            // Hourly forecast strip
            if !weatherManager.hourlyForecast.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(nextHours, id: \.date) { hour in
                            VStack(spacing: 6) {
                                Text(hourLabel(hour.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Image(systemName: weatherSymbol(for: hour.condition))
                                    .font(.system(size: 16))
                                    .foregroundStyle(weatherIconColor(for: hour.condition))
                                
                                Text("\(Int(hour.temperature.value))°")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundStyle(.orange)
                    Text("Weather data unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
            
            // Weather-triggered goal suggestion
            if let suggestion = weatherSuggestedSession {
                let theme = suggestion.theme
                HStack(spacing: 12) {
                    Image(systemName: suggestion.goal?.iconName ?? "figure.walk")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.foregroundColor(for: colorScheme))
                        .frame(width: 40, height: 40)
                        .background(theme.gradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                        
                        Text(weatherSuggestionReason(for: suggestion))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.color(for: colorScheme))
                }
                .padding(12)
                .background(theme.gradient(for: colorScheme).opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Open Blocks
    
    private var openBlocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("OPEN BLOCKS")
            
            VStack(spacing: 0) {
                ForEach(Array(timelineBlocks.enumerated()), id: \.offset) { _, block in
                    timelineRow(block)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Themes in Play
    
    private var themesInPlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("THEMES IN PLAY")
            
            VStack(spacing: 8) {
                ForEach(activeThemes, id: \.tag.title) { themeInfo in
                    let theme = themeInfo.tag.theme
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.gradient(for: colorScheme))
                            .frame(width: 10, height: 10)
                        
                        Text(themeInfo.tag.title)
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Text(themeInfo.totalTime.formatted(style: .hourMinute))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Week Ahead
    
    private var weekAheadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("THE WEEK AHEAD")
            
            HStack(spacing: 6) {
                ForEach(weekDays, id: \.date) { weekDay in
                    VStack(spacing: 6) {
                        Text(weekDay.initial)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(weekDay.isToday ? .primary : .secondary)
                        
                        // Session icons stacked
                        VStack(spacing: 3) {
                            ForEach(weekDay.sessionThemes.prefix(4), id: \.id) { theme in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(theme.gradient(for: colorScheme))
                                    .frame(height: 6)
                            }
                            
                            if weekDay.sessionThemes.count > 4 {
                                Text("+\(weekDay.sessionThemes.count - 4)")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 40, alignment: .top)
                        
                        Text(weekDay.plannedLabel)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        weekDay.isToday
                            ? Color.primary.opacity(0.06)
                            : .clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Helpers
    
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }
    
    // MARK: - Weather Helpers
    
    private var nextHours: [HourWeather] {
        let now = Date()
        return weatherManager.hourlyForecast
            .filter { $0.date >= now }
            .prefix(8)
            .map { $0 }
    }
    
    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }
    
    private func weatherSymbol(for condition: WeatherKit.WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy:
            return "cloud.fill"
        case .rain, .drizzle, .heavyRain:
            return "cloud.rain.fill"
        case .snow, .blizzard, .flurries, .heavySnow:
            return "cloud.snow.fill"
        case .sleet, .freezingDrizzle, .freezingRain:
            return "cloud.sleet.fill"
        case .strongStorms, .tropicalStorm, .hurricane:
            return "cloud.bolt.rain.fill"
        case .windy, .breezy:
            return "wind"
        case .haze, .smoky, .foggy:
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
    
    private func weatherIconColor(for condition: WeatherKit.WeatherCondition) -> Color {
        switch condition {
        case .clear, .mostlyClear:
            return .orange
        case .partlyCloudy:
            return .orange
        case .rain, .drizzle, .heavyRain, .sleet, .freezingDrizzle, .freezingRain:
            return .blue
        case .snow, .blizzard, .flurries, .heavySnow:
            return .cyan
        case .strongStorms, .tropicalStorm, .hurricane:
            return .purple
        default:
            return .gray
        }
    }
    
    private var weatherSuggestedSession: GoalSession? {
        // Find a session whose goal has weather triggers that match current conditions
        sessions.first { session in
            guard let goal = session.goal,
                  session.progress < 1.0,
                  goal.weatherEnabled else { return false }
            return weatherManager.meetsGoalWeatherRequirements(goal)
        }
    }
    
    private func weatherSuggestionReason(for session: GoalSession) -> String {
        guard let weather = weatherManager.currentWeather else {
            return "Good conditions right now"
        }
        let temp = Int(weather.temperature.value)
        return "Best done now · \(temp)° and \(weatherManager.weatherDisplayString.lowercased())"
    }
    
    // MARK: - Calendar / Timeline Helpers
    
    private func fetchCalendarEvents() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        
        Task.detached(priority: .utility) { [calendarEventStore] in
            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            let predicate = calendarEventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
            let events = calendarEventStore.events(matching: predicate)
                .filter { !$0.isAllDay }
                .sorted { $0.startDate < $1.startDate }
            
            await MainActor.run {
                calendarEvents = events
            }
        }
    }
    
    private struct TimelineBlock: Identifiable {
        let id = UUID()
        let startTime: Date
        let endTime: Date
        let kind: Kind
        
        enum Kind {
            case free(sessions: [GoalSession])
            case busy(title: String)
        }
        
        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
        
        var isFree: Bool {
            switch kind {
            case .free: return true
            case .busy: return false
            }
        }
    }
    
    private var timelineBlocks: [TimelineBlock] {
        let calendar = Calendar.current
        let now = Date()
        let endOfDay = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
        
        guard now < endOfDay else { return [] }
        
        // Build busy blocks from calendar events
        var busyRanges: [(start: Date, end: Date, title: String)] = calendarEvents.compactMap { event -> (start: Date, end: Date, title: String)? in
            guard let eventStart = event.startDate, let eventEnd = event.endDate else { return nil }
            let start = max(eventStart, now)
            let end = min(eventEnd, endOfDay)
            guard start < end else { return nil }
            return (start, end, event.title ?? "Busy")
        }
        busyRanges.sort { $0.start < $1.start }
        
        // Build timeline from now to end of day
        var blocks: [TimelineBlock] = []
        var cursor = now
        
        // Sessions to distribute into free blocks
        let incompleteSessions = sessions.filter { $0.progress < 1.0 }
        var sessionQueue = incompleteSessions.sorted {
            ($0.plannedStartTime ?? .distantFuture) < ($1.plannedStartTime ?? .distantFuture)
        }
        
        for busy in busyRanges {
            if cursor < busy.start {
                // Free block before this event
                let freeEnd = busy.start
                let freeDuration = freeEnd.timeIntervalSince(cursor)
                let fittingSessions = extractSessions(from: &sessionQueue, maxDuration: freeDuration)
                blocks.append(TimelineBlock(startTime: cursor, endTime: freeEnd, kind: .free(sessions: fittingSessions)))
            }
            blocks.append(TimelineBlock(startTime: busy.start, endTime: busy.end, kind: .busy(title: busy.title)))
            cursor = max(cursor, busy.end)
        }
        
        // Remaining free time after last event
        if cursor < endOfDay {
            let fittingSessions = extractSessions(from: &sessionQueue, maxDuration: endOfDay.timeIntervalSince(cursor))
            blocks.append(TimelineBlock(startTime: cursor, endTime: endOfDay, kind: .free(sessions: fittingSessions)))
        }
        
        return blocks
    }
    
    private func extractSessions(from queue: inout [GoalSession], maxDuration: TimeInterval) -> [GoalSession] {
        var result: [GoalSession] = []
        var remaining = maxDuration
        
        while !queue.isEmpty {
            let session = queue[0]
            let needed = max((session.unifiedTargetValue - session.currentValue), 0)
            let duration = session.goal?.targetUnit.isTimeBased == true ? needed : 30 * 60 // 30 min default for non-time
            
            if duration <= remaining + 60 { // +60s tolerance
                result.append(queue.removeFirst())
                remaining -= duration
            } else {
                break
            }
        }
        
        return result
    }
    
    private func timelineRow(_ block: TimelineBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            Text(block.startTime.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
            
            // Dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(block.isFree ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                
                if block.duration > 0 {
                    Rectangle()
                        .fill(block.isFree ? Color.green.opacity(0.3) : Color.secondary.opacity(0.15))
                        .frame(width: 2)
                        .frame(height: max(blockHeight(block) - 8, 4))
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                switch block.kind {
                case .free(let blockSessions):
                    if blockSessions.isEmpty {
                        Text(formatDuration(block.duration) + " free")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        ForEach(blockSessions) { session in
                            let theme = session.theme
                            HStack(spacing: 8) {
                                Image(systemName: session.goal?.iconName ?? "target")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(theme.foregroundColor(for: colorScheme))
                                    .frame(width: 24, height: 24)
                                    .background(theme.gradient(for: colorScheme), in: RoundedRectangle(cornerRadius: 6))
                                
                                Text(session.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if session.progress >= 1.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    
                case .busy(let title):
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Text("busy")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
    }
    
    private func blockHeight(_ block: TimelineBlock) -> CGFloat {
        switch block.kind {
        case .free(let sessions):
            return max(CGFloat(max(sessions.count, 1)) * 32, 28)
        case .busy:
            return 28
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Theme Helpers
    
    private struct ThemeInfo {
        let tag: GoalTag
        let totalTime: TimeInterval
    }
    
    private var activeThemes: [ThemeInfo] {
        var result: [String: (tag: GoalTag, time: TimeInterval)] = [:]
        
        for tag in availableGoalThemes {
            let tagGoals = tag.goalsAsPrimary ?? []
            var totalTime: TimeInterval = 0
            
            for goal in tagGoals {
                // Sum today's target for this goal
                let weekday = Calendar.current.component(.weekday, from: day.startDate)
                totalTime += goal.unifiedTarget(for: weekday)
            }
            
            if totalTime > 0 {
                result[tag.title] = (tag, totalTime)
            }
        }
        
        return result
            .sorted { $0.value.time > $1.value.time }
            .map { ThemeInfo(tag: $0.value.tag, totalTime: $0.value.time) }
    }
    
    // MARK: - Week Ahead Helpers
    
    private struct WeekDayInfo {
        let date: Date
        let initial: String
        let isToday: Bool
        let sessionThemes: [ThemePreset]
        let plannedLabel: String
    }
    
    private var weekDays: [WeekDayInfo] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Start from today, show 7 days
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let weekday = calendar.component(.weekday, from: date)
            let symbols = calendar.veryShortStandaloneWeekdaySymbols
            let initial = symbols[weekday - 1]
            let isToday = offset == 0
            
            // Get scheduled goals for this weekday
            let scheduledGoals = goals.filter { goal in
                guard goal.status == .active else { return false }
                let target = goal.unifiedTarget(for: weekday)
                return target > 0
            }
            
            let themes = scheduledGoals.map { $0.resolvedTheme }
            let totalPlanned = scheduledGoals.reduce(0.0) { $0 + $1.unifiedTarget(for: weekday) }
            
            let label: String
            if totalPlanned > 0 {
                label = totalPlanned.formatted(style: .hourMinute)
            } else {
                label = "Rest"
            }
            
            return WeekDayInfo(
                date: date,
                initial: initial,
                isToday: isToday,
                sessionThemes: themes,
                plannedLabel: label
            )
        }
    }
    
    // MARK: - Now playing
    @ViewBuilder
    private var nowPlayingContent: some View {
        
        if let timerManager, let activeSession = timerManager.activeSession, let session = sessions.first(where: { $0.id == activeSession.id }) {
            NowPlayingView(session: session, activeSessionDetails: activeSession) {
                onToggleTimer(session)
            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Goals Tab
    
    private var goalsTabContent: some View {
        AllGoalsView(goals: goals, timerManager: timerManager)
    }
    
    // MARK: - Analytics Tab
    
    private var analyticsTabContent: some View {
        DayOverviewView(
            day: day,
            sessions: sessions,
            goals: goals,
            animation: animation,
            timerManager: timerManager,
            healthKitManager: nil,
            selectedSession: .constant(nil),
            sessionToLogManually: .constant(nil)
        )
    }
    
    // MARK: - Search Tab
    
    private var searchTabContent: some View {
        SearchSheet(
            sessions: sessions,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: .constant(nil),
            sessionToLogManually: .constant(nil),
            searchText: .constant(""),
            isGoalValid: { _ in true }
        )
    }
}
