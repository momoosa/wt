//
//  MomentumWidget.swift
//  MomentumWidget
//
//  Created by Mo Moosa on 01/02/2026.
//

import WidgetKit
import SwiftUI
import SwiftData
import MomentumKit
import AppIntents

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), recommendations: [], configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let recs = await snapshotRecommendations()
        return SimpleEntry(date: Date(), recommendations: recs, configuration: configuration)
    }

    @MainActor
    private func snapshotRecommendations() -> [RecommendedSession] {
        guard let context = makeContext() else { return [] }
        return recommendations(for: Date(), context: context, timer: readActiveTimer())
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        await buildTimeline(configuration: configuration)
    }

    // MARK: - Timeline construction

    /// A day-spanning, midnight-crossing timeline. Recommendations are derived from
    /// the durable goal definitions for each entry's date, so the widget stays
    /// accurate as the day progresses and rolls over — even on days the app itself
    /// never ran — without needing a server push.
    @MainActor
    private func buildTimeline(configuration: ConfigurationAppIntent) -> Timeline<SimpleEntry> {
        let calendar = Calendar.current
        let now = Date()
        let startOfTomorrow = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        )

        guard let context = makeContext() else {
            return Timeline(entries: [SimpleEntry(date: now, recommendations: [], configuration: configuration)],
                            policy: .after(startOfTomorrow))
        }

        let timer = readActiveTimer()

        // Timer active: refresh quickly so the live count stays fresh.
        if timer != nil {
            let recs = recommendations(for: now, context: context, timer: timer)
            let entries: [SimpleEntry] = stride(from: 0, through: 3, by: 1).compactMap { minute in
                calendar.date(byAdding: .minute, value: minute, to: now).map {
                    SimpleEntry(date: $0, recommendations: recs, configuration: configuration)
                }
            }
            return Timeline(entries: entries, policy: .atEnd)
        }

        // Idle: an entry now, one at each remaining time-of-day boundary today, and
        // one just after midnight showing tomorrow's plan. Each entry recomputes for
        // its own date, so the day rolls over correctly without a live reload.
        var dates: [Date] = [now]
        for hour in [10, 14, 17, 21] {
            if let boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now),
               boundary > now, boundary < startOfTomorrow {
                dates.append(boundary)
            }
        }
        dates.append(startOfTomorrow.addingTimeInterval(30))
        dates.sort()

        let entries = dates.map { date in
            SimpleEntry(date: date,
                        recommendations: recommendations(for: date, context: context, timer: nil),
                        configuration: configuration)
        }
        // Also ask WidgetKit to refresh at the new day to extend the horizon.
        return Timeline(entries: entries, policy: .after(startOfTomorrow))
    }

    // MARK: - Shared store

    private var appGroupIdentifier: String { "group.com.moosa.momentum.ios" }

    @MainActor
    private func makeContext() -> ModelContext? {
        let schema = Schema([
            Goal.self, GoalTag.self, GoalSession.self, Day.self,
            HistoricalSession.self, ChecklistItemSession.self, IntervalListSession.self,
        ])
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Widget: Failed to get App Group container URL for \(appGroupIdentifier)")
            return nil
        }
        let storeURL = containerURL.appendingPathComponent("default.store")
        let modelConfiguration = ModelConfiguration(url: storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) else {
            print("❌ Widget: Failed to create model container")
            return nil
        }
        let context = container.mainContext
        context.autosaveEnabled = false  // The widget is read-only; never persist changes.
        return context
    }

    private struct ActiveTimerInfo {
        let sessionID: String
        let startDate: Double
        let elapsed: Double
    }

    private func readActiveTimer() -> ActiveTimerInfo? {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        guard let id = defaults?.string(forKey: "ActiveSessionIDV1"), !id.isEmpty else { return nil }
        return ActiveTimerInfo(
            sessionID: id,
            startDate: defaults?.double(forKey: "ActiveSessionStartDateV1") ?? 0,
            elapsed: defaults?.double(forKey: "ActiveSessionElapsedTimeV1") ?? 0
        )
    }

    // MARK: - Recommendations (derived from durable goals)

    /// Ranks what to do on `date` straight from the durable `Goal` definitions,
    /// enriching each with its materialised `GoalSession` (progress, live timer) when
    /// one exists. Goals scheduled for the date but not yet materialised are surfaced
    /// as zero-progress placeholders, so the widget never shows an empty day just
    /// because the app hasn't created today's sessions yet.
    @MainActor
    private func recommendations(for date: Date, context: ModelContext, timer: ActiveTimerInfo?) -> [RecommendedSession] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let dayID = date.yearMonthDayID(with: calendar)

        let activeGoals = ((try? context.fetch(FetchDescriptor<Goal>())) ?? []).filter { $0.status == .active }

        // Materialised session rows for this date, if the app has created them.
        var sessionsForDay: [GoalSession] = []
        if let day = try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID })).first {
            let did = day.id
            sessionsForDay = (try? context.fetch(FetchDescriptor<GoalSession>(predicate: #Predicate { $0.day?.id == did }))) ?? []
        }
        var sessionByGoal: [UUID: GoalSession] = [:]
        for session in sessionsForDay {
            if let gid = session.goal?.id { sessionByGoal[gid] = session }
        }

        // Candidate goals: active, scheduled/relevant for the date, not skipped or met.
        let candidates: [(goal: Goal, session: GoalSession?)] = activeGoals.compactMap { goal in
            guard goal.isScheduledDay(weekday) else { return nil }
            if goal.hasRelevanceRule, goal.dayAvailability(for: weekday) == .never { return nil }
            let session = sessionByGoal[goal.id]
            if let session, session.status == .skipped || session.hasMetDailyTarget { return nil }
            return (goal, session)
        }

        let planner = GoalSessionPlanner()
        let preferences = PlannerPreferences.default

        let ranked = candidates.sorted { lhs, rhs in
            let lPinned = lhs.session?.pinnedInWidget ?? false
            let rPinned = rhs.session?.pinnedInWidget ?? false
            if lPinned != rPinned { return lPinned }
            let lScore = planner.scoreSession(for: lhs.goal, session: lhs.session, sessions: sessionsForDay, at: date, preferences: preferences)
            let rScore = planner.scoreSession(for: rhs.goal, session: rhs.session, sessions: sessionsForDay, at: date, preferences: preferences)
            return lScore > rScore
        }

        return ranked.prefix(10).map {
            makeRecommendation(goal: $0.goal, session: $0.session, dayID: dayID, weekday: weekday, timer: timer)
        }
    }

    @MainActor
    private func makeRecommendation(goal: Goal, session: GoalSession?, dayID: String, weekday: Int, timer: ActiveTimerInfo?) -> RecommendedSession {
        let isHealthKitSynced = goal.healthKitSyncEnabled && goal.healthKitMetric != nil
        let supportsWrite = goal.healthKitMetric?.supportsWrite ?? true
        let theme = goal.resolvedTheme

        if let session {
            let isActive = timer?.sessionID == session.id.uuidString
            var timerStart: Date? = nil
            var elapsed = session.elapsedTime
            if isActive, let start = timer?.startDate, start > 0 {
                timerStart = Date(timeIntervalSince1970: start)
                if let base = timer?.elapsed { elapsed = base }
            }
            return RecommendedSession(
                id: session.id, title: session.title, theme: theme, progress: session.progress,
                formattedTime: session.formattedTime, hasMetTarget: session.hasMetDailyTarget, dayID: dayID,
                isTimerActive: isActive, isHealthKitSynced: isHealthKitSynced, supportsWrite: supportsWrite,
                isPinned: session.pinnedInWidget, timerStartDate: timerStart, elapsedTime: elapsed,
                dailyTarget: session.unifiedTargetValue, isPlaceholder: false
            )
        }

        // No session materialised yet — synthesise a zero-progress recommendation from
        // the goal. Tapping it opens the app, which creates the real session.
        let target = goal.unifiedTarget(for: weekday)
        return RecommendedSession(
            id: goal.id, title: goal.title, theme: theme, progress: 0,
            formattedTime: placeholderFormattedTime(goal: goal, target: target), hasMetTarget: false, dayID: dayID,
            isTimerActive: false, isHealthKitSynced: isHealthKitSynced, supportsWrite: supportsWrite,
            isPinned: false, timerStartDate: nil, elapsedTime: 0, dailyTarget: target, isPlaceholder: true
        )
    }

    @MainActor
    private func placeholderFormattedTime(goal: Goal, target: Double) -> String {
        switch goal.targetUnit {
        case .seconds, .screenTime:
            return TimeInterval(0).formattedProgress(target: target)
        case .steps:
            return "0/\(Int(target).formatted())"
        case .kilocalories:
            return "0/\(Int(target)) cal"
        }
    }
}

struct RecommendedSession: Identifiable {
    let id: UUID
    let title: String
    let theme: ThemePreset
    let progress: Double
    let formattedTime: String
    let hasMetTarget: Bool
    let dayID: String
    let isTimerActive: Bool
    let isHealthKitSynced: Bool
    let supportsWrite: Bool
    let isPinned: Bool
    
    // Timer data for live updates
    let timerStartDate: Date?
    let elapsedTime: TimeInterval
    let dailyTarget: TimeInterval

    /// True when this row is derived from a goal whose session hasn't been created
    /// yet (the app hasn't run today). It renders as a "not started" row and its
    /// controls open the app instead of driving a non-existent session.
    let isPlaceholder: Bool

    init(id: UUID, title: String, theme: ThemePreset, progress: Double, formattedTime: String,
         hasMetTarget: Bool, dayID: String, isTimerActive: Bool, isHealthKitSynced: Bool,
         supportsWrite: Bool, isPinned: Bool, timerStartDate: Date?, elapsedTime: TimeInterval,
         dailyTarget: TimeInterval, isPlaceholder: Bool = false) {
        self.id = id
        self.title = title
        self.theme = theme
        self.progress = progress
        self.formattedTime = formattedTime
        self.hasMetTarget = hasMetTarget
        self.dayID = dayID
        self.isTimerActive = isTimerActive
        self.isHealthKitSynced = isHealthKitSynced
        self.supportsWrite = supportsWrite
        self.isPinned = isPinned
        self.timerStartDate = timerStartDate
        self.elapsedTime = elapsedTime
        self.dailyTarget = dailyTarget
        self.isPlaceholder = isPlaceholder
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let recommendations: [RecommendedSession]
    let configuration: ConfigurationAppIntent
}

struct MomentumWidgetEntryView : View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Reusable Widget Container

/// A reusable container that handles vertical spacing for widget cells
/// - When items == maxItems: Cells expand to fill vertical space equally
/// - When items < maxItems: Cells use natural height and are pushed to the top
struct WidgetCellContainer<Content: View>: View {
    let items: Int
    let maxItems: Int
    let spacing: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: spacing) {
            content
            
            if items < maxItems {
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(padding)
    }
}

// MARK: - Small Widget
private struct Constants {
    static let padding = 10.0
}
struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        if entry.recommendations.isEmpty {
            VStack {
                Text("No goals today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let itemCount = min(entry.recommendations.count, 3)
            WidgetCellContainer(items: itemCount, maxItems: 3, spacing: 4, padding: Constants.padding) {
                ForEach(entry.recommendations.prefix(3)) { session in
                    MediumWidgetCell(session: session)
                        .frame(maxHeight: itemCount == 3 ? .infinity : nil)
                }
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        if entry.recommendations.isEmpty {
            VStack {
                Text("No active goals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Compact mode: Show max 3 sessions with action buttons
            // Extended mode: Show up to 6 sessions in grid
            let useCompactMode = entry.configuration.mediumLayout == .compact || entry.recommendations.count <= 3
            
            if useCompactMode {
                // Compact: 1-3 items in a single vertical column with action buttons on the right
                let itemCount = min(entry.recommendations.count, 3)
                WidgetCellContainer(items: itemCount, maxItems: 3, spacing: 4, padding: Constants.padding) {
                    HStack(spacing: 8) {
                        VStack(spacing: 4) {
                            ForEach(entry.recommendations.prefix(3)) { session in
                                MediumWidgetCell(session: session)
                                    .frame(maxHeight: itemCount == 3 ? .infinity : nil)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Action buttons
                        VStack(spacing: 8) {
                            Spacer()
                            HStack {
                                Spacer()
                                // Search button
                                Link(destination: URL(string: "momentum://search")!) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.gray.gradient)
                                }
                                
                                Spacer()
                                
                                // Add button
                                Link(destination: URL(string: "momentum://new")!) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.blue.gradient)
                                }
                                Spacer()
                            }
                            
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Extended: 4-6 items in a 2-column grid
                let maxItems = min(entry.recommendations.count, 6)
                let rows = (maxItems + 1) / 2
                
                WidgetCellContainer(items: rows, maxItems: 3, spacing: 4, padding: Constants.padding) {
                    Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                        ForEach(0..<rows, id: \.self) { row in
                            GridRow {
                                ForEach(0..<2, id: \.self) { column in
                                    let index = row * 2 + column
                                    if index < maxItems {
                                        let session = entry.recommendations[index]
                                        MediumWidgetCell(session: session)
                                            .frame(maxHeight: rows == 3 ? .infinity : nil)
                                    } else {
                                        Color.clear
                                            .gridCellUnsizedAxes([.horizontal, .vertical])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Medium Widget Cell

struct MediumWidgetCell: View {
    let session: RecommendedSession
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            // Background tap area - opens app
            Link(destination: URL(string: "momentum://goal/\(session.id.uuidString)")!) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle(session.theme.color(for: colorScheme))
                    
                    HStack(spacing: 4) {
                        if session.isTimerActive {
                            Circle()
                                .fill(.red)
                                .frame(width: 4, height: 4)
                        }
                        
                        if session.isTimerActive, let startDate = session.timerStartDate {
                            // Show live elapsed timer counting up (same as Live Activity)
                            let effectiveStart = startDate.addingTimeInterval(-session.elapsedTime)
                            Text(timerInterval: effectiveStart...Date.distantFuture, countsDown: false)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else {
                            Text(session.formattedTime)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Action button - play/stop for trackable sessions, pencil for manual-only
            if session.isPlaceholder {
                // No session materialised yet: the button opens the app, which creates it.
                Link(destination: URL(string: "momentum://goal/\(session.id.uuidString)")!) {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(session.theme.color(for: colorScheme))
                }
            } else if session.isHealthKitSynced && !session.supportsWrite {
                // Read-only HealthKit: Show pencil icon (opens app for manual entry)
                Link(destination: URL(string: "momentum://goal/\(session.id.uuidString)")!) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(session.theme.color(for: colorScheme))
                }
                .opacity(0.6)
            } else {
                // Regular or writable HealthKit: Show play/stop button
                Button(intent: ToggleTimerIntent(sessionID: session.id.uuidString, dayID: session.dayID)) {
                    Image(systemName: session.isTimerActive ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundStyle(session.theme.color(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }

    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: Provider.Entry
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if entry.recommendations.isEmpty {
                ContentUnavailableView {
                    Label("No Goals", systemImage: "target")
                } description: {
                    Text("Create goals to see recommendations")
                }
            } else {
                ForEach(entry.recommendations) { session in
                    Link(destination: URL(string: "momentum://goal/\(session.id.uuidString)")!) {
                        HStack(spacing: 12) {
                            // Play/Stop Button
                            let playStop = ZStack {
                                Circle()
                                    .fill(session.theme.color(for: colorScheme))
                                    .frame(width: 44, height: 44)

                                Image(systemName: session.isTimerActive ? "stop.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }

                            if session.isPlaceholder {
                                // No session yet: let the enclosing Link open the app.
                                playStop
                            } else {
                                Button(intent: ToggleTimerIntent(sessionID: session.id.uuidString, dayID: session.dayID)) {
                                    playStop
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if session.hasMetTarget {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            
                            HStack {
                                if session.isTimerActive {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                        
                                        if let startDate = session.timerStartDate {
                                            // Show live elapsed timer counting up (same as Live Activity)
                                            let effectiveStart = startDate.addingTimeInterval(-session.elapsedTime)
                                            Text(timerInterval: effectiveStart...Date.distantFuture, countsDown: false)
                                                .font(.subheadline)
                                                .foregroundStyle(.red)
                                                .monospacedDigit()
                                        } else {
                                            Text("Recording")
                                                .font(.subheadline)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                } else {
                                    Text(session.formattedTime)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(session.theme.color(for: colorScheme).opacity(0.2))
                                        
                                        Rectangle()
                                            .fill(session.theme.color(for: colorScheme))
                                            .frame(width: geometry.size.width * session.progress)
                                    }
                                }
                                .frame(height: 4)
                                .cornerRadius(2)
                            }
                        }
                        }
                        .padding()
                        .background(session.theme.color(for: colorScheme).opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
    }
}

struct MomentumWidget: Widget {
    let kind: String = "MomentumWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            MomentumWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Momentum")
        .description("See your top recommended goals right now")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, recommendations: [
        RecommendedSession(
            id: UUID(),
            title: "Reading",
            theme: ThemeStore.resolve(for: "palette_17"),
            progress: 0.5,
            formattedTime: "15m / 30m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: nil as Date?,
            elapsedTime: 900,
            dailyTarget: 1800
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: ThemeStore.resolve(for: "palette_01"),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: nil,
            elapsedTime: 1200,
            dailyTarget: 1500
        ),
//        RecommendedSession(
//            id: UUID(),
//            title: "Meditation",
//            theme: ThemeStore.resolve(for: "palette_16"),
//            progress: 1.0,
//            formattedTime: "10m / 10m",
//            hasMetTarget: true,
//            dayID: "2026-02-02",
//            isTimerActive: false,
//            isHealthKitSynced: false,
//            supportsWrite: true,
//            isPinned: false,
//            timerStartDate: nil,
//            elapsedTime: 600,
//            dailyTarget: 600
//        )
    ], configuration: ConfigurationAppIntent())
}

#Preview(as: .systemMedium) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, recommendations: [
        RecommendedSession(
            id: UUID(),
            title: "Reading",
            theme: ThemeStore.resolve(for: "palette_17"),
            progress: 0.5,
            formattedTime: "15m / 30m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: true,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: Date().addingTimeInterval(-900),
            elapsedTime: 900,
            dailyTarget: 1800
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: ThemeStore.resolve(for: "palette_01"),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: nil,
            elapsedTime: 1200,
            dailyTarget: 1500
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: ThemeStore.resolve(for: "palette_16"),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: nil,
            elapsedTime: 600,
            dailyTarget: 600
        )
    ], configuration: ConfigurationAppIntent())
}
#Preview(as: .systemMedium) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, recommendations: [
        RecommendedSession(
            id: UUID(),
            title: "Reading",
            theme: ThemeStore.resolve(for: "palette_17"),
            progress: 0.5,
            formattedTime: "15m / 30m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: nil,
            elapsedTime: 900,
            dailyTarget: 1800
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: ThemeStore.resolve(for: "palette_01"),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: true,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: Date().addingTimeInterval(-1200),
            elapsedTime: 1200,
            dailyTarget: 1500
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: ThemeStore.resolve(for: "palette_16"),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true,
            isPinned: false,
            timerStartDate: nil,
            elapsedTime: 600,
            dailyTarget: 600
        )
    ], configuration: ConfigurationAppIntent())
}

