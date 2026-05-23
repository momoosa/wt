//
//  ThemePreviewView.swift
//  Momentum
//
//  Created by Assistant on 26/03/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct ThemePreviewView: View {
    @State private var selectedThemeIndex: Int = 0
    @State private var groupByComponent: Bool = false
    
    private var selectedTheme: ThemePreset {
        ThemeStore.presets[selectedThemeIndex]
    }
    
    // Create a transient day for preview purposes only
    private var previewDay: Day {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return Day(start: start, end: end)
    }
    
    var body: some View {
        NavigationSplitView {
            // Theme list
            List(Array(ThemeStore.presets.enumerated()), id: \.offset) { index, theme in
                Button {
                    selectedThemeIndex = index
                } label: {
                    HStack {
                        // Gradient preview
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.gradient(for: .dark))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(theme.title)
                                .font(.headline)
                            HStack(spacing: 3) {
                                ForEach(Array(theme.darkColors.enumerated()), id: \.offset) { _, color in
                                    Circle().fill(color).frame(width: 10, height: 10)
                                }
                                Rectangle()
                                    .fill(.secondary.opacity(0.3))
                                    .frame(width: 1, height: 10)
                                ForEach(Array(theme.lightColors.enumerated()), id: \.offset) { _, color in
                                    Circle().fill(color).frame(width: 10, height: 10)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if index == selectedThemeIndex {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Themes")
        } detail: {
            if groupByComponent {
                ComponentGroupedView(day: previewDay)
                    .navigationTitle("By Component")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                groupByComponent.toggle()
                            } label: {
                                Label("Group by Theme", systemImage: "square.grid.2x2")
                            }
                        }
                    }
            } else {
                ThemeDetailView(
                    theme: selectedTheme,
                    day: previewDay
                )
                .navigationTitle(selectedTheme.title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            groupByComponent.toggle()
                        } label: {
                            Label("Group by Component", systemImage: "rectangle.3.group")
                        }
                    }
                }
            }
        }
    }
}

struct ThemeDetailView: View {
    let theme: ThemePreset
    let day: Day
    
    @Namespace private var animation
    @State private var previewModelContext: ModelContext?
    @State private var goalStore: GoalStore?
    @State private var timerManager: SessionTimerManager?
    @State private var mockSession: GoalSession?
    @State private var selectedSession: GoalSession?
    @State private var sessionToLogManually: GoalSession?
    @State private var shimmerOffset: CGFloat = -200
    @State private var cardRotationY: Double = 0
    
    private func setupPreviewContext() {
        guard previewModelContext == nil else { return }
        
        // Create an isolated in-memory ModelContext for preview
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(
            for: Goal.self, GoalSession.self, GoalTag.self, Day.self,
            configurations: config
        ) {
            previewModelContext = ModelContext(container)
        }
    }
    
    private func createMockSession() -> GoalSession {
        guard previewModelContext != nil else {
            // Fallback to creating transient objects if context setup failed
            return createTransientMockSession()
        }
        
        // Create a mock tag with the theme
        let themeObj = theme
        let tag = GoalTag(
            title: theme.title,
            themeID: themeObj.id
        )
        
        // Create a mock goal
        let goal = Goal(
            title: "Sample Goal - \(theme.title)",
            primaryTag: tag
        )
        
        // Don't insert into context - keep as transient objects
        // This prevents them from interfering with ContentView's queries
        
        // Create a session for today
        let session = GoalSession(
            title: goal.title,
            goal: goal,
            day: day
        )
        
        // Add some mock recommendation reasons
        session.recommendationReasons = [RecommendationReason.userPriority, RecommendationReason.weather]
        
        return session
    }
    
    private func createTransientMockSession() -> GoalSession {
        // Fallback method that creates completely transient objects
        let themeObj = theme
        let tag = GoalTag(
            title: theme.title,
            themeID: themeObj.id
        )
        
        let goal = Goal(
            title: "Sample Goal - \(theme.title)",
            primaryTag: tag
        )
        
        let session = GoalSession(
            title: goal.title,
            goal: goal,
            day: day
        )
        
        session.recommendationReasons = [RecommendationReason.userPriority, RecommendationReason.weather]
        
        return session
    }
    
    var body: some View {
        Group {
            if let store = goalStore {
                content
                    .environment(store)
            } else {
                content
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text(theme.title)
                        .font(.largeTitle)
                        .bold()
                    
                    // Dark palette gradient
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dark Colors (\(theme.darkColors.count))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.gradient(for: .dark))
                            .frame(height: 50)
                            .overlay {
                                HStack(spacing: 0) {
                                    ForEach(Array(theme.darkColors.enumerated()), id: \.offset) { _, color in
                                        color
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .opacity(0.5)
                            }
                            .overlay(alignment: .bottom) {
                                HStack(spacing: 0) {
                                    ForEach(Array(theme.darkColors.enumerated()), id: \.offset) { i, _ in
                                        Text("\(i)")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        
                        // Individual dark color swatches
                        HStack(spacing: 6) {
                            ForEach(Array(theme.darkColors.enumerated()), id: \.offset) { i, color in
                                ColorSwatch(color: color, label: i == 0 ? "Neon" : (i == theme.darkColors.count - 1 ? "Dark" : "\(i)"))
                            }
                        }
                    }
                    
                    // Light palette gradient
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Light Colors (\(theme.lightColors.count))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.gradient(for: .light))
                            .frame(height: 50)
                            .overlay {
                                HStack(spacing: 0) {
                                    ForEach(Array(theme.lightColors.enumerated()), id: \.offset) { _, color in
                                        color
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .opacity(0.5)
                            }
                            .overlay(alignment: .bottom) {
                                HStack(spacing: 0) {
                                    ForEach(Array(theme.lightColors.enumerated()), id: \.offset) { i, _ in
                                        Text("\(i)")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        
                        // Individual light color swatches
                        HStack(spacing: 6) {
                            ForEach(Array(theme.lightColors.enumerated()), id: \.offset) { i, color in
                                ColorSwatch(color: color, label: i == 0 ? "Light" : "\(i)")
                            }
                        }
                    }
                    
                    // Foreground colors
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Foreground Colors")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            // Light foreground on dark gradient
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.gradient(for: .dark))
                                    .frame(width: 100, height: 36)
                                    .overlay {
                                        Text("Abc")
                                            .font(.headline)
                                            .foregroundStyle(theme.foregroundColor(for: .dark))
                                    }
                                Text("FG Dark")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Light foreground on light gradient
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.gradient(for: .light))
                                    .frame(width: 100, height: 36)
                                    .overlay {
                                        Text("Abc")
                                            .font(.headline)
                                            .foregroundStyle(theme.foregroundColor(for: .light))
                                    }
                                Text("FG Light")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .task {
                    // Setup isolated preview context
                    setupPreviewContext()
                    
                    // Initialize GoalStore once
                    if goalStore == nil {
                        goalStore = GoalStore()
                    }
                    
                    guard let store = goalStore, let context = previewModelContext else { return }
                    
                    if timerManager == nil {
                        timerManager = SessionTimerManager(goalStore: store, modelContext: context)
                    }
                }
                .onChange(of: theme.id) { _, _ in
                    // Recreate mock session when theme changes (transient objects)
                    mockSession = createMockSession()
                }
                .onAppear {
                    // Create initial mock session (transient objects)
                    if mockSession == nil {
                        mockSession = createMockSession()
                    }
                }
                
                Divider()
                
                // Recommended Session Card - All variants
                if let session = mockSession, let timer = timerManager {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recommended Session")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 24) {
                            // Light mode
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Light")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                RecommendedSessionRowView(
                                    session: session,
                                    day: day,
                                    timerManager: timer,
                                    animation: animation,
                                    selectedSession: $selectedSession,
                                    sessionToLogManually: $sessionToLogManually,
                                )
                                .background(
                                    session.theme.gradient(for: .light)
                                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                )
                                .environment(\.colorScheme, .light)
                            }
                            
                            // Light mode with outline
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Light + Outline")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                RecommendedSessionRowView(
                                    session: session,
                                    day: day,
                                    timerManager: timer,
                                    animation: animation,
                                    selectedSession: $selectedSession,
                                    sessionToLogManually: $sessionToLogManually,
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                        .stroke(session.theme.gradient(for: .light), lineWidth: 5)
                                        .background(
                                            Color(.systemBackground)
                                                .opacity(0.5)
                                                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                        )
                                )
                                .environment(\.colorScheme, .light)
                            }
                            
                            // Dark mode
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dark")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                RecommendedSessionRowView(
                                    session: session,
                                    day: day,
                                    timerManager: timer,
                                    animation: animation,
                                    selectedSession: $selectedSession,
                                    sessionToLogManually: $sessionToLogManually,

                                )
                                .background(
                                    session.theme.gradient(for: .dark)
                                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                )
                                .environment(\.colorScheme, .dark)
                            }
                            
                            // Dark mode with outline
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dark + Outline")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                RecommendedSessionRowView(
                                    session: session,
                                    day: day,
                                    timerManager: timer,
                                    animation: animation,
                                    selectedSession: $selectedSession,
                                    sessionToLogManually: $sessionToLogManually,

                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                        .stroke(session.theme.gradient(for: .dark), lineWidth: 5)
                                        .background(
                                            Color(.systemBackground)
                                                .opacity(0.5)
                                                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                        )
                                )
                                .environment(\.colorScheme, .dark)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Normal Session Card - Both color schemes
                if let session = mockSession, let timer = timerManager {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Normal Session")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Light")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                SessionRowView(
                                    session: session,
                                    day: day,
                                    timerManager: timer,
                                    animation: animation,
                                    selectedSession: $selectedSession,
                                    sessionToLogManually: $sessionToLogManually,
                                    isRecommended: false,
                                    useGradientAccents: false
                                )
                                .environment(\.colorScheme, .light)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dark")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                SessionRowView(
                                    session: session,
                                    day: day,
                                    timerManager: timer,
                                    animation: animation,
                                    selectedSession: $selectedSession,
                                    sessionToLogManually: $sessionToLogManually,
                                    isRecommended: false,
                                    useGradientAccents: false
                                )
                                .environment(\.colorScheme, .dark)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Progress Summary Card - Both color schemes
                if let session = mockSession, let timer = timerManager {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Light")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                ProgressSummaryCardWrapper(
                                    session: session,
                                    weeklyProgress: 0.4,
                                    weeklyElapsedTime: 1.5 * 3600,
                                    cardRotationY: $cardRotationY,
                                    shimmerOffset: $shimmerOffset,
                                    timerManager: timer,
                                    onDone: {},
                                    onSkip: {},
                                    onManualLog: {}
                                )
                                .environment(\.colorScheme, .light)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dark")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                ProgressSummaryCardWrapper(
                                    session: session,
                                    weeklyProgress: 0.4,
                                    weeklyElapsedTime: 1.5 * 3600,
                                    cardRotationY: $cardRotationY,
                                    shimmerOffset: $shimmerOffset,
                                    timerManager: timer,
                                    onDone: {},
                                    onSkip: {},
                                    onManualLog: {}
                                )
                                .environment(\.colorScheme, .dark)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Goal Detail Card - Both color schemes
                VStack(alignment: .leading, spacing: 16) {
                    Text("Goal Detail")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Light")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            GoalDetailPreview(
                                theme: theme,
                                colorScheme: .light
                            )
                            .environment(\.colorScheme, .light)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dark")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            GoalDetailPreview(
                                theme: theme,
                                colorScheme: .dark
                            )
                            .environment(\.colorScheme, .dark)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct ColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct GoalDetailPreview: View {
    let theme: ThemePreset
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Hero header
            VStack(spacing: 12) {
                Circle()
                    .fill(theme.gradient(for: colorScheme))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "book.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
                
                Text(theme.title)
                    .font(.title2)
                    .bold()
                
                Text("Reading • 5 times/week • 30 min each")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(theme.gradient(for: colorScheme).opacity(0.1))
            
            // Stats grid
            HStack(spacing: 12) {
                StatCard(theme: theme, value: "2/5", label: "This Week")
                StatCard(theme: theme, value: "1h 30m", label: "Time")
                StatCard(theme: theme, value: "60%", label: "Progress")
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let theme: ThemePreset
    let value: String
    let label: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(theme.gradient(for: colorScheme))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ComponentGroupedView: View {
    let day: Day
    
    @Namespace private var animation
    @State private var previewModelContext: ModelContext?
    @State private var goalStore: GoalStore?
    @State private var timerManager: SessionTimerManager?
    @State private var mockSessions: [(theme: ThemePreset, session: GoalSession)] = []
    @State private var selectedSession: GoalSession?
    @State private var sessionToLogManually: GoalSession?
    @State private var shimmerOffset: CGFloat = -200
    @State private var cardRotationY: Double = 0
    
    private func setupPreviewContext() {
        guard previewModelContext == nil else { return }
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(
            for: Goal.self, GoalSession.self, GoalTag.self, Day.self,
            configurations: config
        ) {
            previewModelContext = ModelContext(container)
        }
    }
    
    private func createMockSession(for theme: ThemePreset) -> GoalSession {
        let themeObj = theme
        let tag = GoalTag(title: theme.title, themeID: themeObj.id)
        let goal = Goal(title: "Sample Goal - \(theme.title)", primaryTag: tag)
        let session = GoalSession(title: goal.title, goal: goal, day: day)
        session.recommendationReasons = [RecommendationReason.userPriority, RecommendationReason.weather]
        return session
    }
    
    var body: some View {
        Group {
            if let store = goalStore {
                content.environment(store)
            } else {
                content
            }
        }
        .task {
            setupPreviewContext()
            
            if goalStore == nil {
                goalStore = GoalStore()
            }
            
            guard let store = goalStore, let context = previewModelContext else { return }
            
            if timerManager == nil {
                timerManager = SessionTimerManager(goalStore: store, modelContext: context)
            }
            
            // Create mock sessions for all themes
            mockSessions = ThemeStore.presets.map { theme in
                (theme: theme, session: createMockSession(for: theme))
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Recommended Session Row - Light
                componentSection(
                    title: "Recommended Session - Light",
                    colorScheme: .light
                ) { theme, session, timer in
                    RecommendedSessionRowView(
                        session: session,
                        day: day,
                        timerManager: timer,
                        animation: animation,
                        selectedSession: $selectedSession,
                        sessionToLogManually: $sessionToLogManually
                    )
                    .background(
                        session.theme.gradient(for: .light)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                    )
                }
                
                Divider()
                
                // Recommended Session Row - Dark
                componentSection(
                    title: "Recommended Session - Dark",
                    colorScheme: .dark
                ) { theme, session, timer in
                    RecommendedSessionRowView(
                        session: session,
                        day: day,
                        timerManager: timer,
                        animation: animation,
                        selectedSession: $selectedSession,
                        sessionToLogManually: $sessionToLogManually
                    )
                    .background(
                        session.theme.gradient(for: .dark)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                    )
                }
                
                Divider()
                
                // Normal Session Row - Light
                componentSection(
                    title: "Normal Session - Light",
                    colorScheme: .light
                ) { theme, session, timer in
                    List {
                        SessionRowView(
                            session: session,
                            day: day,
                            timerManager: timer,
                            animation: animation,
                            selectedSession: $selectedSession,
                            sessionToLogManually: $sessionToLogManually,
                            isRecommended: false,
                            useGradientAccents: false
                        )
                    }
                    .frame(height: 80)
                    .scrollDisabled(true)
                }
                
                Divider()
                
                // Normal Session Row - Dark
                componentSection(
                    title: "Normal Session - Dark",
                    colorScheme: .dark
                ) { theme, session, timer in
                    List {
                        SessionRowView(
                            session: session,
                            day: day,
                            timerManager: timer,
                            animation: animation,
                            selectedSession: $selectedSession,
                            sessionToLogManually: $sessionToLogManually,
                            isRecommended: false,
                            useGradientAccents: false
                        )
                    }
                    .frame(height: 80)
                    .scrollDisabled(true)
                }
                
                Divider()
                
                // Progress Summary - Light
                componentSection(
                    title: "Progress Summary - Light",
                    colorScheme: .light
                ) { theme, session, timer in
                    ProgressSummaryCardWrapper(
                        session: session,
                        weeklyProgress: 0.4,
                        weeklyElapsedTime: 1.5 * 3600,
                        cardRotationY: $cardRotationY,
                        shimmerOffset: $shimmerOffset,
                        timerManager: timer,
                        onDone: {},
                        onSkip: {},
                        onManualLog: {}
                    )
                }
                
                Divider()
                
                // Progress Summary - Dark
                componentSection(
                    title: "Progress Summary - Dark",
                    colorScheme: .dark
                ) { theme, session, timer in
                    ProgressSummaryCardWrapper(
                        session: session,
                        weeklyProgress: 0.4,
                        weeklyElapsedTime: 1.5 * 3600,
                        cardRotationY: $cardRotationY,
                        shimmerOffset: $shimmerOffset,
                        timerManager: timer,
                        onDone: {},
                        onSkip: {},
                        onManualLog: {}
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func componentSection<Content: View>(
        title: String,
        colorScheme: ColorScheme,
        @ViewBuilder content: @escaping (ThemePreset, GoalSession, SessionTimerManager) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(mockSessions, id: \.theme.id) { item in
                        if let timer = timerManager {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.theme.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                content(item.theme, item.session, timer)
                                    .frame(width: 350)
                                    .environment(\.colorScheme, colorScheme)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let goalStore = GoalStore()
    
    // Create container with error handling
    let container: ModelContainer
    do {
        container = try ModelContainer(for: Day.self, Goal.self, GoalSession.self, GoalTag.self, configurations: config)
    } catch {
        fatalError("Failed to create preview ModelContainer: \(error.localizedDescription)")
    }
    
    return ThemePreviewView()
        .modelContainer(container)
        .environment(goalStore)
}
