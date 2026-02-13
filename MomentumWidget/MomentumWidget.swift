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
        SimpleEntry(date: Date(), recommendations: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let recommendations = await fetchRecommendations()
        return SimpleEntry(date: Date(), recommendations: recommendations)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let recommendations = await fetchRecommendations()
        
        // Update every 15 minutes to keep recommendations fresh
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        let entry = SimpleEntry(date: currentDate, recommendations: recommendations)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    @MainActor
    private func fetchRecommendations() async -> [RecommendedSession] {
        // Set up model container with App Group for widget access
        let schema = Schema([
            Goal.self,
            GoalTag.self,
            GoalSession.self,
            Day.self,
            HistoricalSession.self,
            ChecklistItemSession.self,
            IntervalListSession.self,
        ])
        
        // Use App Group container for shared data access
        // You need to configure this App Group in your target settings
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Widget: Failed to get App Group container URL")
            print("   Make sure App Group '\(appGroupIdentifier)' is configured in both app and widget targets")
            return []
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        print("📁 Widget: Using store at: \(storeURL.path)")
        
        let modelConfiguration = ModelConfiguration(url: storeURL)
        
        guard let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) else {
            print("❌ Widget: Failed to create model container")
            return []
        }
        
        print("✅ Widget: Model container created successfully")
        
        let context = container.mainContext
        
        // Fetch today's day
        let now = Date()
        let calendar = Calendar.current
        
        // Construct today's day ID using the same format as Day.init
        let todayID = now.yearMonthDayID(with: calendar)
        print("🔍 Widget: Looking for day with ID: \(todayID)")
        
        // Fetch day by ID
        let dayPredicate = #Predicate<Day> { day in
            day.id == todayID
        }
        let dayDescriptor = FetchDescriptor<Day>(predicate: dayPredicate)
        
        guard let day = try? context.fetch(dayDescriptor).first else {
            print("❌ Widget: No day found with ID \(todayID)")
            // Try fetching all days to see what's available
            if let allDays = try? context.fetch(FetchDescriptor<Day>()) {
                print("   Available days: \(allDays.map { $0.id }.joined(separator: ", "))")
            }
            return []
        }
        
        print("✅ Widget: Found today's day: \(day.id)")
        
        // Fetch sessions for today
        let dayID = day.id
        let sessionPredicate = #Predicate<GoalSession> { session in
            session.day.id == dayID
        }
        let sessionDescriptor = FetchDescriptor<GoalSession>(predicate: sessionPredicate)
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        
        print("📊 Widget: Found \(sessions.count) sessions")
        
        // Filter active, non-skipped sessions
        let activeSessions = sessions.filter { session in
            session.goal.status != .archived && session.status != .skipped
        }
        
        print("✅ Widget: \(activeSessions.count) active sessions")
        
        // Check for active timer from UserDefaults
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let activeTimerSessionID = defaults?.string(forKey: "ActiveSessionIDV1")
        
        // Use same ordering logic as ContentView
        let planner = GoalSessionPlanner()
        let preferences = PlannerPreferences.default
        
        // First: Show planned sessions with recommendation reasons (top 3)
        let plannedSessions = activeSessions
            .filter { $0.plannedStartTime != nil && !$0.recommendationReasons.isEmpty }
            .sorted { ($0.plannedStartTime ?? Date.distantFuture) < ($1.plannedStartTime ?? Date.distantFuture) }
            .prefix(3)
        
        var orderedSessions: [GoalSession] = Array(plannedSessions)
        
        // Fill remaining slots up to 10 sessions
        if orderedSessions.count < 10 {
            let plannedIDs = Set(plannedSessions.map { $0.id })
            let remainingSessions = activeSessions.filter { !plannedIDs.contains($0.id) }
            
            // Sort remaining by planned time if available, otherwise by score
            let sorted = remainingSessions.sorted { session1, session2 in
                let has1 = session1.plannedStartTime != nil
                let has2 = session2.plannedStartTime != nil
                
                if has1 && has2 {
                    return session1.plannedStartTime! < session2.plannedStartTime!
                } else if has1 {
                    return true
                } else if has2 {
                    return false
                } else {
                    // Use scoring for unplanned sessions
                    let score1 = planner.scoreSession(for: session1.goal, session: session1, at: now, preferences: preferences)
                    let score2 = planner.scoreSession(for: session2.goal, session: session2, at: now, preferences: preferences)
                    return score1 > score2
                }
            }
            
            orderedSessions.append(contentsOf: sorted.prefix(10 - orderedSessions.count))
        }
        
        // Convert to widget format - get top 10 and let widget views decide how many to show
        let topSessions = orderedSessions
            .prefix(10)
            .map { session in
                let isActive = activeTimerSessionID == session.id.uuidString
                let isHealthKitSynced = session.goal.healthKitSyncEnabled && session.goal.healthKitMetric != nil
                let supportsWrite = session.goal.healthKitMetric?.supportsWrite ?? true
                
                return RecommendedSession(
                    id: session.id,
                    title: session.title,
                    theme: session.goal.primaryTag.theme,
                    progress: session.progress,
                    formattedTime: session.formattedTime,
                    hasMetTarget: session.hasMetDailyTarget,
                    dayID: day.id,
                    isTimerActive: isActive,
                    isHealthKitSynced: isHealthKitSynced,
                    supportsWrite: supportsWrite
                )
            }
        
        return Array(topSessions)
    }
}

struct RecommendedSession: Identifiable {
    let id: UUID
    let title: String
    let theme: Theme
    let progress: Double
    let formattedTime: String
    let hasMetTarget: Bool
    let dayID: String
    let isTimerActive: Bool
    let isHealthKitSynced: Bool
    let supportsWrite: Bool
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let recommendations: [RecommendedSession]
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
            VStack(spacing: 4) {
                ForEach(entry.recommendations.prefix(3)) { session in
                    MediumWidgetCell(session: session)
                }
            }
            .padding(Constants.padding)
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
            let maxItems = min(entry.recommendations.count, 6) // Cap at 6 for medium widget
            let rows = (maxItems + 1) / 2 // Calculate rows needed (ceiling division)
            
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            if index < maxItems {
                                let session = entry.recommendations[index]
                                MediumWidgetCell(session: session)
                            } else {
                                Color.clear
                                    .gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
            }
            .padding(Constants.padding)
        }
    }
}

// MARK: - Medium Widget Cell

struct MediumWidgetCell: View {
    let session: RecommendedSession
    
    var body: some View {
        HStack(spacing: 6) {
            // Background tap area - opens app
            Link(destination: URL(string: "momentum://goal/\(session.id.uuidString)")!) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle(session.theme.textColor)
                    
                    HStack(spacing: 4) {
                        if session.isTimerActive {
                            Circle()
                                .fill(.red)
                                .frame(width: 4, height: 4)
                        }
                        
                        Text(session.formattedTime)
                            .font(.caption2)
                            .foregroundStyle(session.theme.textColor.opacity(0.7))
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Action button - play/stop for trackable sessions, pencil for manual-only
            if session.isHealthKitSynced && !session.supportsWrite {
                // Read-only HealthKit: Show pencil icon (opens app for manual entry)
                Link(destination: URL(string: "momentum://goal/\(session.id.uuidString)")!) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(session.theme.textColor)
                }
                .opacity(0.6)
            } else {
                // Regular or writable HealthKit: Show play/stop button
                Button(intent: ToggleTimerIntent(sessionID: session.id.uuidString, dayID: session.dayID)) {
                    Image(systemName: session.isTimerActive ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundStyle(session.theme.textColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            LinearGradient(
                colors: [
                    session.theme.neon,
                    session.theme.dark
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))

    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: Provider.Entry
    
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
                            Button(intent: ToggleTimerIntent(sessionID: session.id.uuidString, dayID: session.dayID)) {
                                ZStack {
                                    Circle()
                                        .fill(session.isTimerActive ? session.theme.dark : session.theme.light)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: session.isTimerActive ? "stop.fill" : "play.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            
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
                                        Text("Recording")
                                            .font(.subheadline)
                                            .foregroundStyle(.red)
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
                                            .fill(session.theme.light.opacity(0.2))
                                        
                                        Rectangle()
                                            .fill(session.theme.light)
                                            .frame(width: geometry.size.width * session.progress)
                                    }
                                }
                                .frame(height: 4)
                                .cornerRadius(2)
                            }
                        }
                        }
                        .padding()
                        .background(session.theme.light.opacity(0.1))
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
            theme: themePresets.first(where: { $0.id == "blue" })!.toTheme(),
            progress: 0.5,
            formattedTime: "15m / 30m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: themePresets.first(where: { $0.id == "red" })!.toTheme(),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: themePresets.first(where: { $0.id == "purple" })!.toTheme(),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        )
    ])
}

#Preview(as: .systemMedium) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, recommendations: [
        RecommendedSession(
            id: UUID(),
            title: "Reading",
            theme: themePresets.first(where: { $0.id == "blue" })!.toTheme(),
            progress: 0.5,
            formattedTime: "15m / 30m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: true,
            isHealthKitSynced: false,
            supportsWrite: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: themePresets.first(where: { $0.id == "red" })!.toTheme(),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: themePresets.first(where: { $0.id == "purple" })!.toTheme(),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        )
    ])
}
#Preview(as: .systemMedium) {
    MomentumWidget()
} timeline: {
    SimpleEntry(date: .now, recommendations: [
        RecommendedSession(
            id: UUID(),
            title: "Reading",
            theme: themePresets.first(where: { $0.id == "blue" })!.toTheme(),
            progress: 0.5,
            formattedTime: "15m / 30m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: themePresets.first(where: { $0.id == "red" })!.toTheme(),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: true,
            isHealthKitSynced: false,
            supportsWrite: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: themePresets.first(where: { $0.id == "purple" })!.toTheme(),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false,
            isHealthKitSynced: false,
            supportsWrite: true
        )
    ])
}

