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
        
        // Score and rank sessions
        let planner = GoalSessionPlanner()
        let preferences = PlannerPreferences.default
        
        let scored = activeSessions.compactMap { session -> (GoalSession, Double, Bool)? in
            let score = planner.scoreSession(
                for: session.goal,
                session: session,
                at: now,
                preferences: preferences
            )
            return (session, score, session.hasMetDailyTarget)
        }
        
        // Separate incomplete and complete sessions
        let incomplete = scored.filter { !$0.2 }.sorted { $0.1 > $1.1 }
        let complete = scored.filter { $0.2 }.sorted { $0.1 > $1.1 }
        
        // Prioritize incomplete sessions, then complete ones
        let prioritized = incomplete + complete
        
        // Get top 6 for widgets
        let topSessions = prioritized
            .prefix(6)
            .map { session, _, _ in
                let isActive = activeTimerSessionID == session.id.uuidString
                return RecommendedSession(
                    id: session.id,
                    title: session.goal.title,
                    theme: session.goal.primaryTag.theme,
                    progress: session.progress,
                    formattedTime: session.formattedTime,
                    hasMetTarget: session.hasMetDailyTarget,
                    dayID: day.id,
                    isTimerActive: isActive
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

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
         
            if entry.recommendations.isEmpty {
                Text("No goals today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.recommendations.prefix(3)) { session in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(session.theme.light)
                                .frame(width: 6, height: 6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .strikethrough(session.hasMetTarget, color: .secondary)
                                
                                HStack(spacing: 4) {
                                    if session.isTimerActive {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 4, height: 4)
                                    }
                                    
                                    Text(session.formattedTime)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    if session.hasMetTarget {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            if entry.recommendations.isEmpty {
                Text("No active goals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(entry.recommendations.prefix(6)) { session in
                        HStack(spacing: 10) {
                            // Play/Stop Button
                            Button(intent: ToggleTimerIntent(sessionID: session.id.uuidString, dayID: session.dayID)) {
                                ZStack {
                                    Circle()
                                        .fill(session.isTimerActive ? session.theme.dark : session.theme.light)
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: session.isTimerActive ? "stop.fill" : "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .strikethrough(session.hasMetTarget, color: .secondary)
                                
                                HStack(spacing: 4) {
                                    if session.isTimerActive {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 5, height: 5)
                                    }
                                    
                                    Text(session.formattedTime)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    if session.hasMetTarget {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                         
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
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
            
            Spacer()
        }
        .padding()
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
            isTimerActive: false
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
            isTimerActive: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: themePresets.first(where: { $0.id == "red" })!.toTheme(),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: false
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: themePresets.first(where: { $0.id == "purple" })!.toTheme(),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false
        )
    ])
}
#Preview(as: .systemLarge) {
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
            isTimerActive: false
        ),
        RecommendedSession(
            id: UUID(),
            title: "Exercise",
            theme: themePresets.first(where: { $0.id == "red" })!.toTheme(),
            progress: 0.75,
            formattedTime: "20m / 25m",
            hasMetTarget: false,
            dayID: "2026-02-02",
            isTimerActive: true
        ),
        RecommendedSession(
            id: UUID(),
            title: "Meditation",
            theme: themePresets.first(where: { $0.id == "purple" })!.toTheme(),
            progress: 1.0,
            formattedTime: "10m / 10m",
            hasMetTarget: true,
            dayID: "2026-02-02",
            isTimerActive: false
        )
    ])
}

