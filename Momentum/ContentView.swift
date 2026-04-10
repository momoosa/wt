//
//  ContentView.swift
//  Momentum
//
//  Created by Mo Moosa on 22/07/2025.
//

import SwiftUI
import SwiftData
import EventKit
import MomentumKit
import HealthKit
import OSLog
import WeatherKit
#if canImport(WidgetKit)
import WidgetKit
#endif

struct ContentView: View {
    @Environment(GoalStore.self) var goalStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query(filter: #Predicate<GoalSession> { $0.dailyTarget > 0 }) private var sessions: [GoalSession]
    @Query private var allSessions: [GoalSession]
    let day: Day
    @Namespace var animation

    // View Model (business logic) - injected from WeektimeApp
    @State var viewModel: ContentViewModel

    // Navigation and UI state (from ViewModel when created)
    @State private var navigation = NavigationState()

    // Timer manager for session tracking
    @State private var timerManager: SessionTimerManager?

    // Planning
    @State private var planningViewModel = PlanningViewModel()

    // Focus filter
    @State private var focusFilterStore = FocusFilterStore.shared

    // HealthKit (delegated to ViewModel)
    @State private var healthKitManager = HealthKitManager()
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0

    // Weather
    @State private var weatherManager = WeatherManager.shared

    // Calendar
    @State private var nextCalendarEvent: EKEvent?
    @State private var calendarEventStore = EKEventStore()
    
    // Progress Card Tile Visibility Settings
    @AppStorage("showProgressTile") private var showProgressTile: Bool = true
    @AppStorage("showWeatherTile") private var showWeatherTile: Bool = true
    @AppStorage("showCalendarTile") private var showCalendarTile: Bool = true

    // MARK: - Initialization

    init(day: Day, viewModel: ContentViewModel) {
        self.day = day
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let recommendedSessionIDs = getRecommendedSessions().map { $0.id }
        
        mainListView
            .animation(.spring(), value: goals)
            .animation(AnimationPresets.smoothSpring, value: sessions.count)
            .animation(AnimationPresets.smoothSpring, value: recommendedSessionIDs)
            .overlay {
                VStack(spacing: 0) {
                    if focusFilterStore.isFocusFilterActive {
                        focusBanner
                    }
                    GoalFilterBar(
                        filters: availableFilters,
                        activeFilter: $navigation.activeFilter,
                        sessionCounts: sessionCountsForFilters,
                        onFilterTap: scrollToFilterSection
                    )
                    Spacer()
                }
            }
            .overlay(alignment: .bottom) {
                if let toastConfig = navigation.toastConfig {
                    VStack {
                        Spacer()
                        ToastView(
                            config: toastConfig,
                            onDismiss: {
                                self.navigation.toastConfig = nil
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $navigation.isSearching) {
                searchSheet
            }
            .toolbar {
                toolbarContent
            }
            .task {
                setupOnAppear()
            }
            .onDisappear {
                timerManager?.activeSession?.stopUITimer()
            }
            .onChange(of: goals) { old, new in
                handleGoalsChange(old: old, new: new)
                goalStore.goals = new
            }
            .onChange(of: sessions) { old, new in
                goalStore.sessions = new
            }
#if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Check for external changes when coming back to foreground
                timerManager?.checkForExternalChanges()
                
                if timerManager?.activeSession?.id != nil {
                    timerManager?.activeSession?.startUITimer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                timerManager?.activeSession?.stopUITimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Also check when app becomes active (e.g., after widget interaction)
                timerManager?.checkForExternalChanges()
            }
#endif
            .sheet(isPresented: $navigation.showPlannerSheet) {
                plannerSheet
            }

        
            .sheet(isPresented: $navigation.showingGoalEditor) {
                goalEditorSheet
            }
            .sheet(isPresented: $navigation.showAllGoals) {
                allGoalsSheet
            }
            .fullScreenCover(isPresented: $navigation.showNowPlaying) {
                nowPlayingView
            }
            .sheet(isPresented: $navigation.showSettings) {
                settingsSheet
            }
            .sheet(isPresented: $navigation.showDayOverview) {
                dayOverviewSheet
            }
            .sheet(item: $navigation.sessionToLogManually) { session in
                manualLogSheet(for: session)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSessionFromWidget"))) { notification in
                if let sessionID = notification.object as? String {
                    handleDeepLink(sessionID: sessionID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSearch"))) { _ in
                navigation.isSearching = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNewGoal"))) { _ in
                navigation.showingGoalEditor = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowToast"))) { notification in
                if let message = notification.object as? String {
                    navigation.toastConfig = ToastConfig(
                        message: message,
                        showUndo: false
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncChecklistToSessions"))) { notification in
                if let goal = notification.object as? Goal {
                    syncChecklistToSessions(for: goal)
                }
            }
            .navigationDestination(item: $navigation.selectedSession) { session in
                if let timerManager = timerManager {
                    GoalSessionDetailView(
                        session: session,
                        animation: animation,
                        timerManager: timerManager,
                        onMarkedComplete: {
                            // Dismiss the detail view
                            navigation.selectedSession = nil
                            
                            // Show toast
                            navigation.toastConfig = ToastConfig(
                                message: "Marked as complete - moved to Completed filter",
                                showUndo: false
                            )
                        }
                    )
                    .tint(session.themeDark)
                    .environment(goalStore)
                }
            }
    }
    
    // MARK: - Main List View
    
    // MARK: - Search Sheet
    
    private var searchSheet: some View {
        SearchSheet(
            sessions: focusFilteredSessions,
            availableFilters: availableFilters,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: $navigation.selectedSession,
            sessionToLogManually: $navigation.sessionToLogManually,
            searchText: $navigation.searchText,
            onSkip: skip,
            onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
            isSyncingHealthKit: viewModel.isSyncingHealthKit,
            isGoalValid: isGoalValid
        )
    }
    
    // MARK: - Focus Banner

    private var focusBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.fill")
                .imageScale(.small)
            Text("Focus Filter Active")
                .font(.caption)
                .fontWeight(.medium)
            Text("·")
                .foregroundStyle(.secondary)
            Text(focusFilterStore.activeFocusTagTitles.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Main List View

    private var mainListView: some View {
        ScrollViewReader { proxy in
            List {
                // Show daily progress card once user has saved at least one session
                Section {
                
            } footer: {
                Spacer()
                    .frame(height: LayoutConstants.Heights.smallSpacer)
            }

            Section {
                dailyProgressCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listSectionSpacing(.compact)

            if !focusFilteredSessions.isEmpty || planningViewModel.isPlanning || planningViewModel.showPlanningComplete {
                // Always show all sessions in contextual sections
                let recommendedSessions = getRecommendedSessions()
                let allSessionsFiltered = SessionFilterService.filter(
                    focusFilteredSessions,
                    by: .activeToday,  // Use activeToday logic for base filtering
                    validationCheck: isGoalValid,
                    weatherManager: weatherManager
                )
                
                // Group sessions into contextual sections - this now includes all sections
                let contextualSections = ContextualSection.groupSessions(
                    allSessionsFiltered,
                    recommendedSessions: recommendedSessions,
                    allGoals: focusFilteredSessions  // Pass all focus-filtered sessions
                )
                
                ForEach(contextualSections) { section in
                    contextualSectionView(section: section)
                }
                
                // Show planning indicator after all sessions
                if planningViewModel.isPlanning || planningViewModel.showPlanningComplete {
                    planningIndicatorSection
                }
            }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .onAppear {
                navigation.scrollProxy = proxy
            }
        }
    }
    

    
    @ViewBuilder
    private func contextualSectionView(section: ContextualSection) -> some View {
        switch section.type {
        case .recommendedNow:
            // Recommended Now section with featured card style
            Section {
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let icon = section.type.icon {
                            Image(systemName: icon)
                                .foregroundStyle(.yellow)
                        }
                        Text(section.type.title)
                            .font(.headline)
                    }
                    
                    if let explanation = section.explanation {
                        Text(explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .id(section.type)
            .listSectionSpacing(.compact)
            
            // Individual featured cards
            ForEach(section.sessions) { session in
                Section {
                    RecommendedSessionRowView(
                        session: session,
                        day: day,
                        timerManager: timerManager,
                        animation: animation,
                        selectedSession: $navigation.selectedSession,
                        sessionToLogManually: $navigation.sessionToLogManually,
                        onSkip: skip,
                        onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
                        isSyncingHealthKit: viewModel.isSyncingHealthKit
                    )
                }
                .listSectionSpacing(.compact)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
        case .weatherWindow, .timeWindow, .energyWindow:
            // Contextual time-based sections
            Section {
                if navigation.expandedSections.contains(section.type) {
                    ForEach(section.sessions) { session in
                        sessionRow(for: session)
                    }
                }
            } header: {
                Button(action: {
                    withAnimation {
                        if navigation.expandedSections.contains(section.type) {
                            navigation.expandedSections.remove(section.type)
                        } else {
                            navigation.expandedSections.insert(section.type)
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let icon = section.type.icon {
                                Image(systemName: icon)
                                    .foregroundStyle(.blue)
                            }
                            Text(section.type.title)
                                .font(.headline)
                            if !navigation.expandedSections.contains(section.type) && !section.sessions.isEmpty {
                                Text("(\(section.sessions.count))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: navigation.expandedSections.contains(section.type) ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let explanation = section.explanation, navigation.expandedSections.contains(section.type) {
                            Text(explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .id(section.type)
            .listSectionSpacing(.compact)
            
        case .available:
            // Available goals section (backup goals not scheduled today)
            Section {
                if navigation.expandedSections.contains(section.type) {
                    ForEach(section.sessions) { session in
                        sessionRow(for: session)
                    }
                }
            } header: {
                Button(action: {
                    withAnimation {
                        if navigation.expandedSections.contains(section.type) {
                            navigation.expandedSections.remove(section.type)
                        } else {
                            navigation.expandedSections.insert(section.type)
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let icon = section.type.icon {
                                Image(systemName: icon)
                                    .foregroundStyle(.orange)
                            }
                            Text(section.type.title)
                                .font(.headline)
                            if !navigation.expandedSections.contains(section.type) && !section.sessions.isEmpty {
                                Text("(\(section.sessions.count))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: navigation.expandedSections.contains(section.type) ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let explanation = section.explanation, navigation.expandedSections.contains(section.type) {
                            Text(explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .id(section.type)
            .listSectionSpacing(.compact)
            
        case .later:
            // Later section (standard rows)
            Section {
                if navigation.expandedSections.contains(section.type) {
                    ForEach(section.sessions) { session in
                        sessionRow(for: session)
                    }
                }
            } header: {
                Button(action: {
                    withAnimation {
                        if navigation.expandedSections.contains(section.type) {
                            navigation.expandedSections.remove(section.type)
                        } else {
                            navigation.expandedSections.insert(section.type)
                        }
                    }
                }) {
                    HStack {
                        Text(section.type.title)
                            .font(.headline)
                        if !navigation.expandedSections.contains(section.type) && !section.sessions.isEmpty {
                            Text("(\(section.sessions.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: navigation.expandedSections.contains(section.type) ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .id(section.type)
            .listSectionSpacing(.compact)
            
        case .workingOffSchedule:
            // Working off-schedule section
            Section {
                if navigation.expandedSections.contains(section.type) {
                    ForEach(section.sessions) { session in
                        sessionRow(for: session)
                    }
                }
            } header: {
                Button(action: {
                    withAnimation {
                        if navigation.expandedSections.contains(section.type) {
                            navigation.expandedSections.remove(section.type)
                        } else {
                            navigation.expandedSections.insert(section.type)
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let icon = section.type.icon {
                                Image(systemName: icon)
                                    .foregroundStyle(.purple)
                            }
                            Text(section.type.title)
                                .font(.headline)
                            if !navigation.expandedSections.contains(section.type) && !section.sessions.isEmpty {
                                Text("(\(section.sessions.count))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: navigation.expandedSections.contains(section.type) ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let explanation = section.explanation, navigation.expandedSections.contains(section.type) {
                            Text(explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .id(section.type)
            .listSectionSpacing(.compact)
            
        case .completed:
            // Completed Today section
            Section {
                if navigation.expandedSections.contains(section.type) {
                    ForEach(section.sessions) { session in
                        sessionRow(for: session)
                    }
                }
            } header: {
                Button(action: {
                    withAnimation {
                        if navigation.expandedSections.contains(section.type) {
                            navigation.expandedSections.remove(section.type)
                        } else {
                            navigation.expandedSections.insert(section.type)
                        }
                    }
                }) {
                    HStack {
                        if let icon = section.type.icon {
                            Image(systemName: icon)
                                .foregroundStyle(.green)
                        }
                        Text(section.type.title)
                            .font(.headline)
                        if !navigation.expandedSections.contains(section.type) && !section.sessions.isEmpty {
                            Text("(\(section.sessions.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: navigation.expandedSections.contains(section.type) ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .id(section.type)
            .listSectionSpacing(.compact)
            
        case .inactive:
            // Inactive section
            Section {
                if navigation.expandedSections.contains(section.type) {
                    ForEach(section.sessions) { session in
                        sessionRow(for: session)
                    }
                }
            } header: {
                Button(action: {
                    withAnimation {
                        if navigation.expandedSections.contains(section.type) {
                            navigation.expandedSections.remove(section.type)
                        } else {
                            navigation.expandedSections.insert(section.type)
                        }
                    }
                }) {
                    HStack {
                        if let icon = section.type.icon {
                            Image(systemName: icon)
                                .foregroundStyle(.gray)
                        }
                        Text(section.type.title)
                            .font(.headline)
                        if !navigation.expandedSections.contains(section.type) && !section.sessions.isEmpty {
                            Text("(\(section.sessions.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: navigation.expandedSections.contains(section.type) ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .id(section.type)
            .listSectionSpacing(.compact)
        }
    }
    
    private func laterSection(sessions: [GoalSession]) -> some View {
        Section {
            ForEach(sessions) { session in
                sessionRow(for: session)
            }
        } header: {
            // Only show "Later" title if there are more than 4 total sessions
            // (which means recommended section is shown)
            if self.sessions.count > 4 {
                Text("Later")
                    .font(.headline)
            }
        }
        .listSectionSpacing(.compact)
    }
    
    private var planningIndicatorSection: some View {
        Section {
            HStack {
                if planningViewModel.isPlanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating plan...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        planningViewModel.cancelPlanning()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                } else if planningViewModel.showPlanningComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.small)
                    Text("All done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .listSectionSpacing(.compact)
        .transition(.opacity)
    }
    
    private var dailyProgressCard: some View {
        let size = 80.0
        let viewModel = progressViewModel
        let hasVisibleTiles = showProgressTile || showWeatherTile || showCalendarTile
        
        return Group {
            if hasVisibleTiles {
                HStack(spacing: 12) {
                    // Progress Ring
                    if showProgressTile {
                        CircularProgressView(progress: viewModel.dailyProgress, foregroundColor: .blue, backgroundColor: Color.blue.opacity(0.4))
                            .overlay {
                                VStack(spacing: 2) {
                                    Text("\(Int(viewModel.dailyProgress * 100))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("done")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .matchedTransitionSource(id: "dayOverviewCard", in: animation)
                            .onTapGesture {
                                navigation.showDayOverview = true
                            }
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Weather Card
                    if showWeatherTile {
                        if let weather = weatherManager.currentWeather {
                            VStack(spacing: 6) {
                                Image(systemName: weatherSymbol(for: weather.condition))
                                    .font(.title)
                                    .foregroundStyle(.blue)
                                
                                Text("\(Int(weather.temperature.value))°")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .transition(.scale.combined(with: .opacity))
                        } else if weatherManager.isLoading {
                            // Loading state
                            VStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.regular)
                                
                                Text("Loading")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Error or no data state
                            VStack(spacing: 6) {
                                Image(systemName: weatherManager.error != nil ? "exclamationmark.triangle" : "cloud.slash")
                                    .font(.title)
                                    .foregroundStyle(.gray)
                                
                                Text(weatherManager.error != nil ? "Error" : "No Data")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .onTapGesture {
                                weatherManager.forceRefreshWeather()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // Calendar Free Time Card
                    if showCalendarTile {
                        if let nextEvent = nextCalendarEvent {
                            VStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.title)
                                    .foregroundStyle(.orange)
                                
                                Text(freeTimeText)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                                
                                Text("Free")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .animation(.spring(), value: showProgressTile)
                .animation(.spring(), value: showWeatherTile)
                .animation(.spring(), value: showCalendarTile)
            }
        }
    }
    
    private var progressViewModel: DailyProgressViewModel {
        DailyProgressViewModel(sessions: Array(sessions))
    }
    
    // MARK: - Weather & Calendar Helpers
    
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
    
    private var freeTimeText: String {
        guard let event = nextCalendarEvent else { return "All day" }
        
        let now = Date()
        let timeUntilEvent = event.startDate.timeIntervalSince(now)
        
        if timeUntilEvent < 0 {
            // Event is happening now
            let timeUntilEnd = event.endDate.timeIntervalSince(now)
            if timeUntilEnd > 0 {
                return "Busy now"
            } else {
                return "All day"
            }
        }
        
        // Calculate free time
        let hours = Int(timeUntilEvent / 3600)
        let minutes = Int((timeUntilEvent.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
    
    private func fetchNextCalendarEvent() {
        Task { @MainActor in
            do {
                let granted = try await calendarEventStore.requestFullAccessToEvents()
                guard granted else { return }
                
                let now = Date()
                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
                
                let predicate = calendarEventStore.predicateForEvents(
                    withStart: now,
                    end: endOfDay,
                    calendars: nil
                )
                
                let events = calendarEventStore.events(matching: predicate)
                    .filter { !$0.isAllDay }
                    .sorted { $0.startDate < $1.startDate }
                
                nextCalendarEvent = events.first
            } catch {
                // Silently fail - calendar is optional
                nextCalendarEvent = nil
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    navigation.showAllGoals = true
                } label: {
                    Image(systemName: "target")
                }
                
                #if DEBUG
                

                NavigationLink {
                    ThemePreviewView()
                        .modelContainer(previewOnlyContainer())
                } label: {
                    Text("Themes")
                }
                #endif
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                navigation.showSettings = true
            } label: {
                Image(systemName: "gear")
            }
   
        }
#endif
        
    
  
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                navigation.isSearching = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .matchedTransitionSource(id: "searchButton", in: animation)
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                navigation.showDayOverview = true
            } label: {
                Label("Day Overview", systemImage: "calendar.badge.checkmark")
            }
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                // Cache themes before showing sheet to avoid SwiftData faults
                planningViewModel.cachedThemes = availableGoalThemes
                navigation.showPlannerSheet = true
            } label: {
                if planningViewModel.isPlanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Plan Day", systemImage: "sparkles")
                }
            }
            .disabled(planningViewModel.isPlanning)
            .matchedTransitionSource(id: "plannerButton", in: animation)
        }
        
        
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }
        
        if let timerManager,
           let activeSession = timerManager.activeSession,
           let session = sessions.first(where: { $0.id == activeSession.id }) {
            
            ToolbarItem(placement: .bottomBar) {
                ActionView(session: session, details: activeSession) { event in
                    handle(event: event)
                }
                .onTapGesture {
                    navigation.showNowPlaying = true
                }
                .frame(minWidth: 140.0)
            }
        }
        
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button(action: { navigation.showingGoalEditor = true }) {
                Label("Add Item", systemImage: "plus")
            }
            .overlay {
                Color.clear
            }
            .matchedTransitionSource(id: "info", in: animation)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupOnAppear() {
        // Sync ViewModel's timerManager with ContentView's (ViewModel is injected from WeektimeApp)
        viewModel.timerManager = timerManager

        // Initialize timer manager if needed
        if timerManager == nil {
            let manager = SessionTimerManager(goalStore: goalStore, modelContext: modelContext)
            
            // Set up callback for external changes (e.g., widget stopping timer)
            manager.onExternalChange = { [weak manager] in
                // Note: SwiftData automatically tracks changes from other contexts
                // We just need to reload the timer state to sync with UserDefaults
                manager?.loadTimerState(sessions: sessions)
            }
            
            timerManager = manager
        }
        
        // Load saved timer states from UserDefaults
        timerManager?.loadTimerState(sessions: sessions)
        
        // Update GoalStore for App Intents
        goalStore.goals = goals
        goalStore.sessions = sessions
        
        // Use Task to ensure proper async data loading
        Task {
            refreshGoals()
            syncHealthKitData()
            
            // Fetch calendar events
            fetchNextCalendarEvent()
            
            // Auto-plan once per day on launch if we haven't already
            await checkAndRunAutoPlan()
            
            // Reschedule notifications for all goals with notifications enabled
            await rescheduleGoalNotifications()
        }
        
        // Initialize weather data asynchronously in background to avoid blocking launch
        Task(priority: .background) {
            weatherManager.refreshWeatherIfNeeded()
        }
    }
    
    /// Reschedule notifications for all goals with schedule notifications enabled
    @MainActor
    private func rescheduleGoalNotifications() async {
        let notificationManager = GoalNotificationManager()
        
        // Get all active goals with schedule notifications enabled
        let notificationGoals = goals.filter { $0.scheduleNotificationsEnabled && $0.hasSchedule && $0.status == .active }
        
        guard !notificationGoals.isEmpty else {
            AppLogger.notifications.debug("No goals with notifications enabled")
            return
        }
        
        AppLogger.notifications.info("Rescheduling notifications for \(notificationGoals.count) goals...")
        
        do {
            try await notificationManager.rescheduleAllGoals(goals: notificationGoals)
        } catch {
            AppLogger.notifications.error("Failed to reschedule notifications: \(error)")
        }
    }
    
    /// Check if we should auto-plan and run it if needed
    private func checkAndRunAutoPlan() async {
        AppLogger.planner.debug("Auto-plan check: hasAutoPlannedToday=\(planningViewModel.hasAutoPlannedToday), goals.count=\(goals.count)")
        
        // Skip if we've already auto-planned in this session (prevents duplicate runs)
        guard !planningViewModel.hasAutoPlannedToday else {
            AppLogger.planner.debug("Skipping: already planned in this session")
            return
        }
        
        // Mark as started immediately to prevent concurrent runs
        planningViewModel.hasAutoPlannedToday = true
        
        // Skip if there are no goals
        guard !goals.isEmpty else {
            AppLogger.planner.debug("Skipping: no goals available")
            planningViewModel.hasAutoPlannedToday = false // Reset so it can try again if goals are added
            return
        }
        
        // Check if less than 1 hour has passed since last plan generation
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastPlan = currentTime - lastPlanGeneratedTimestamp
        let oneHourInSeconds: Double = 3600
        
        if lastPlanGeneratedTimestamp > 0 && timeSinceLastPlan < oneHourInSeconds {
            let remainingMinutes = Int((oneHourInSeconds - timeSinceLastPlan) / 60)
            AppLogger.planner.debug("Skipping: Plan generated \(Int(timeSinceLastPlan / 60)) minutes ago. Will regenerate in \(remainingMinutes) minutes")
            planningViewModel.hasAutoPlannedToday = false // Reset so it can try again later
            return
        }
        
        AppLogger.planner.info("Starting auto-plan...")
        
        
        await generateDailyPlan()
    }
    
    /// Update recommendation reasons for existing planned sessions
    private func updateExistingSessionReasons() async {
        await MainActor.run {
            for session in sessions where session.plannedStartTime != nil {
                guard let goal = session.goal else { continue }
                let reasons = calculateRecommendationReasons(for: session, goal: goal)
                session.recommendationReasons = reasons
            }
            modelContext.safeSave(showingToast: $navigation.toastConfig)
        }
    }
    
    private func handleGoalsChange(old: [Goal], new: [Goal]) {
        Task {
            refreshGoals()
            
            // Check if any new goals have HealthKit metrics that need authorization
            let newHealthKitGoals = new.filter { newGoal in
                newGoal.healthKitSyncEnabled &&
                newGoal.healthKitMetric != nil &&
                !old.contains(where: { $0.id == newGoal.id })
            }
            
            // If there are new HealthKit goals, request authorization immediately
            if !newHealthKitGoals.isEmpty {
                let newMetrics = newHealthKitGoals.compactMap { $0.healthKitMetric }
                if !newMetrics.isEmpty {
                    do {
                        try await healthKitManager.requestAuthorization(for: newMetrics)
                    } catch {
                        AppLogger.healthKit.error("HealthKit authorization failed for new goals: \(error)")
                    }
                }
            }
            
            // Always sync to ensure data is up to date
            syncHealthKitData()
        }
    }
    
    // MARK: - Sheet Views
    
    private var plannerSheet: some View {
        PlannerConfigurationSheet(
            selectedThemes: $planningViewModel.selectedThemes,
            availableTimeMinutes: $planningViewModel.availableTimeMinutes,
            allThemes: planningViewModel.cachedThemes,
            animation: animation
        ) {
            navigation.showPlannerSheet = false
            planningViewModel.planningTask = Task {
                await generateDailyPlan()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.thinMaterial)
        .onAppear {
            // Cache themes when sheet appears to avoid SwiftData faults
            planningViewModel.cachedThemes = availableGoalThemes
            
            // Prewarm the model to reduce initial planning delay
            Task {
                await planningViewModel.planner.prewarm()
            }
        }
    }
    
    private var goalEditorSheet: some View {
        GoalEditorView(viewModel: GoalEditorViewModel())
            .navigationTransition(
                .zoom(sourceID: "info", in: animation)
            )
    }
    
    private var allGoalsSheet: some View {
        AllGoalsView(goals: goals)
    }
    
    private var nowPlayingView: some View {
        Group {
            if let timerManager,
               let activeSession = timerManager.activeSession,
               let session = sessions.first(where: { $0.id == activeSession.id }) {
                NowPlayingView(
                    session: session,
                    activeSessionDetails: activeSession,
                    currentIntervalName: timerManager.currentIntervalName,
                    intervalProgress: timerManager.intervalProgress,
                    intervalTimeRemaining: timerManager.intervalTimeRemaining,
                    onStopTapped: {
                        handleTimerToggle(for: session)
                    },
                    onAdjustStartTime: { adjustment in
                        handleStartTimeAdjustment(for: session, adjustment: adjustment)
                    }
                )
            }
        }
    }
    
    private var settingsSheet: some View {
        SettingsView()
    }
    
    private var dayOverviewSheet: some View {
        DayOverviewView(
            day: day,
            sessions: Array(sessions),
            goals: goals,
            animation: animation,
            timerManager: timerManager,
            selectedSession: $navigation.selectedSession,
            sessionToLogManually: $navigation.sessionToLogManually,
            onSkip: skip,
            onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
            isSyncingHealthKit: viewModel.isSyncingHealthKit
        )
    }
    
    private func manualLogSheet(for session: GoalSession) -> some View {
        ManualLogSheet(session: session, day: day)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
    
    // MARK: - Computed Properties
    
    private var availableGoalThemes: [GoalTag] {
        let activeGoals = goals.filter { $0.status == .active }
        var uniqueThemes: [GoalTag] = []
        var seenIDs: Set<String> = []
        
        for goal in activeGoals {
            guard let primaryTag = goal.primaryTag else { continue }
            let themeID = primaryTag.themeID
            if !seenIDs.contains(themeID) {
                uniqueThemes.append(primaryTag)
                seenIDs.insert(themeID)
            }
        }
        
        return uniqueThemes
    }
    
    private var availableFilters: [Filter] {
        SessionFilterService.buildAvailableFilters(from: availableGoalThemes, sessions: sessions)
    }
    
    private var sessionCountsForFilters: [FilterCount] {
        availableFilters.map { filter in
            FilterCount(
                filter: filter,
                count: SessionFilterService.count(focusFilteredSessions, for: filter)
            )
        }
    }

    /// Sessions pre-filtered by the active Focus filter (if any).
    /// When no Focus filter is active this is identical to `sessions`.
    private var focusFilteredSessions: [GoalSession] {
        let activeTags = focusFilterStore.activeFocusTagTitles
        guard !activeTags.isEmpty else { return Array(sessions) }
        return sessions.filter { session in
            guard let primaryTag = session.goal?.primaryTag else { return false }
            return activeTags.contains(primaryTag.title)
        }
    }


    
    private func refreshGoals() {
        // First, clean up any sessions whose goals have been deleted
        let orphanedSessions = sessions.filter { !isGoalValid($0) }
        for session in orphanedSessions {
            modelContext.delete(session)
        }
        
        // Then create sessions for goals that don't have them
        for goal in goals {
            if !sessions.contains(where: { $0.goal == goal }) {
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                modelContext.insert(session)
                
                // Create checklist item sessions for this goal session
                if let checklistItems = goal.checklistItems {
                    for checklistItem in checklistItems {
                        let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                        modelContext.insert(itemSession)
                        session.checklist?.append(itemSession)
                    }
                }
            }
        }
        
        // Save changes if there were any insertions or deletions
        if modelContext.hasChanges {
            if modelContext.safeSave(showingToast: $navigation.toastConfig) {
                // Reload widgets when sessions are created or deleted
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }

    /// Sync checklist changes from a goal to its existing sessions
    func syncChecklistToSessions(for goal: Goal) {
        // Get all sessions for this goal
        let goalSessions = sessions.filter { $0.goal == goal }

        guard let goalChecklistItems = goal.checklistItems else {
            // Goal has no checklist items - remove all checklist sessions
            for session in goalSessions {
                if let checklistSessions = session.checklist {
                    for checklistSession in checklistSessions {
                        modelContext.delete(checklistSession)
                    }
                    session.checklist?.removeAll()
                }
            }
            return
        }

        // Sync checklist to each session
        for session in goalSessions {
            var sessionChecklist = session.checklist ?? []

            // Get existing checklist item IDs in the session
            let existingItemIDs = Set(sessionChecklist.compactMap { $0.checklistItem?.id })
            let goalItemIDs = Set(goalChecklistItems.map { $0.id })

            // Remove checklist sessions for items that no longer exist in goal
            let itemsToRemove = sessionChecklist.filter { checklistSession in
                guard let item = checklistSession.checklistItem else { return true }
                return !goalItemIDs.contains(item.id)
            }

            for checklistSession in itemsToRemove {
                modelContext.delete(checklistSession)
                if let index = sessionChecklist.firstIndex(where: { $0.id == checklistSession.id }) {
                    sessionChecklist.remove(at: index)
                }
            }

            // Add new checklist sessions for items that don't exist in session yet
            for checklistItem in goalChecklistItems {
                if !existingItemIDs.contains(checklistItem.id) {
                    let newChecklistSession = ChecklistItemSession(
                        checklistItem: checklistItem,
                        isCompleted: false,
                        session: session
                    )
                    modelContext.insert(newChecklistSession)
                    sessionChecklist.append(newChecklistSession)
                }
            }

            // Update the session's checklist
            session.checklist = sessionChecklist
        }

        // Save changes
        if modelContext.hasChanges {
            modelContext.safeSave(showingToast: $navigation.toastConfig)
        }
    }

    func skip(session: GoalSession) {
        // Delegate to ViewModel
        viewModel.skip(session)
    }
    
    /// Check if a session's goal is still valid (not deleted)
    private func isGoalValid(_ session: GoalSession) -> Bool {
        // Try to access the session and goal properties - if it throws or fails, they were deleted
        // We need to catch both Swift errors and SwiftData faults
        guard let _ = try? session.persistentModelID else {
            return false
        }
        
        do {
            _ = session.status
            guard let goal = session.goal else { return false }
            _ = goal.id
            _ = goal.title
            _ = goal.status
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Scroll to Section
    
    /// Scrolls to the section corresponding to the selected filter
    private func scrollToFilterSection(_ filter: Filter) {
        guard let proxy = navigation.scrollProxy else { return }
        
        // Map filter to section type
        let targetSection: ContextualSection.SectionType?
        
        switch filter {
        case .activeToday:
            // Scroll to the "Now" section (recommended)
            targetSection = .recommendedNow
            
        case .completedToday:
            targetSection = .completed
            
        case .inactive:
            targetSection = .inactive
            
        case .theme(_):
            // For theme filters, scroll to "Available" section where themed goals appear
            targetSection = .available
            
        case .skippedSessions:
            // Skipped sessions don't have a dedicated section in the contextual view
            // Just scroll to top
            targetSection = nil
        }
        
        // Scroll to the target section with animation
        if let section = targetSection {
            withAnimation {
                proxy.scrollTo(section, anchor: .top)
            }
        }
    }
    
    // MARK: - Recommendations
    
    /// Get recommended sessions for right now (top 3)
    private func getRecommendedSessions() -> [GoalSession] {
        return SessionFilterService.getRecommendedSessions(
            from: focusFilteredSessions,
            filter: navigation.activeFilter,
            planner: planningViewModel.planner,
            preferences: planningViewModel.plannerPreferences,
            validationCheck: isGoalValid,
            weatherManager: weatherManager
        )
    }
    

    // MARK: - Session Row
    
    @ViewBuilder
    private func sessionRow(for session: GoalSession) -> some View {
        SessionRowView(
            session: session,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: $navigation.selectedSession,
            sessionToLogManually: $navigation.sessionToLogManually,
            onSkip: skip,
            onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
            isSyncingHealthKit: viewModel.isSyncingHealthKit
        )
    }
    

    func handleTimerToggle(for session: GoalSession) {
        guard let timerManager else { return }
        
        // Check if session is currently completed
        let wasCompleted = session.hasMetDailyTarget
        
        // Toggle the timer
        timerManager.toggleTimer(for: session, in: day)
        
        // If it was completed and we just started it, switch to Today filter and show toast
        if wasCompleted && timerManager.activeSession?.id == session.id {
            withAnimation {
                navigation.activeFilter = .activeToday
            }
            
            navigation.toastConfig = ToastConfig(
                message: "Session resumed - moved to Today",
                showUndo: false
            )
        }
    }
    
    func handleStartTimeAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        guard let timerManager,
              let activeSession = timerManager.activeSession,
              activeSession.id == session.id else { return }
        
        // Adjust start time using the ActiveSessionDetails method
        activeSession.adjustStartTime(by: adjustment)
        
        // Save to UserDefaults
        if let defaults = UserDefaults(suiteName: "group.com.moosa.momentum.ios") {
            defaults.set(activeSession.startDate.timeIntervalSince1970, forKey: "ActiveSessionStartDateV1")
            defaults.synchronize()
        }
        
        let minutes = Int(abs(adjustment) / 60)
        let direction = adjustment > 0 ? "earlier" : "later"
        navigation.toastConfig = ToastConfig(
            message: "Adjusted start time: \(minutes)m \(direction)",
            showUndo: false
        )
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handleDailyGoalAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        // Delegate to ViewModel
        viewModel.adjustDailyTarget(for: session, by: adjustment)
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handle(event: ActionView.Event) {
        guard let timerManager else { return }
        switch event {
        case .stopTapped:
            if let session = sessions.first(where: { $0.id == timerManager.activeSession?.id }) {
                handleTimerToggle(for: session)
            }
        }
    }
    
    func timerText(for session: GoalSession) -> String {
        return timerManager?.timerText(for: session) ?? "00:00"
    }
    
    // MARK: - HealthKit Integration
    
    private func syncHealthKitData(userInitiated: Bool = false) {
        // Delegate to ViewModel
        Task {
            await viewModel.syncHealthKitData(
                for: goals,
                sessions: Array(sessions),
                in: day,
                userInitiated: userInitiated
            )
        }
    }
    
    /// Sync historical sessions from HealthKit samples
    /// - Parameter samples: Already-merged HealthKit samples
    private func syncHistoricalSessions(from samples: [HealthKitSample], for goal: Goal, in session: GoalSession) {
        // Note: samples are already merged at this point
        
        // Get existing HealthKit-sourced historical sessions for this goal and day
        let existingHealthKitSessionIDs = Set(
            (day.historicalSessions ?? [])
                .filter { $0.healthKitType != nil && $0.goalIDs.contains(goal.id.uuidString) }
                .map { $0.id }
        )
        
        // Track which sample IDs we're keeping
        var processedSampleIDs = Set<String>()
        
        for sample in samples {
            processedSampleIDs.insert(sample.id)
            
            // Check if this sample already exists as a historical session
            if existingHealthKitSessionIDs.contains(sample.id) {
                // Session already exists, skip
                continue
            }
            
            // Create new historical session from HealthKit sample
            let historicalSession = HistoricalSession(
                id: sample.id,
                title: "\(sample.metric.displayName) - \(sample.sourceName)",
                start: sample.startDate,
                end: sample.endDate,
                healthKitType: sample.metric.rawValue,
                needsHealthKitRecord: false // Already synced from HealthKit
            )
            historicalSession.goalIDs.append(goal.id.uuidString)
            day.add(historicalSession: historicalSession)
            
            modelContext.insert(historicalSession)
        }
        
        // Remove historical sessions that no longer exist in HealthKit
        let sessionsToRemove = (day.historicalSessions ?? []).filter { session in
            guard session.healthKitType != nil,
                  session.goalIDs.contains(goal.id.uuidString) else {
                return false
            }
            return !processedSampleIDs.contains(session.id)
        }
        
        for session in sessionsToRemove {
            modelContext.delete(session)
        }
    }
    
    /// Merge consecutive HealthKit samples that are short and have no time gap between them
    /// - Parameter samples: Array of HealthKit samples to merge
    /// - Returns: Array with consecutive short sessions merged
    private func mergeSamples(_ samples: [HealthKitSample]) -> [HealthKitSample] {
        guard !samples.isEmpty else { return [] }
        
        // Sort by start date
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var merged: [HealthKitSample] = []
        var currentGroup: [HealthKitSample] = [sorted[0]]
        
        for i in 1..<sorted.count {
            let previous = sorted[i - 1]
            let current = sorted[i]
            
            // Check if we should merge with the current group
            let timeBetween = current.startDate.timeIntervalSince(previous.endDate)
            let shouldMerge = timeBetween <= 0 && // No gap (or overlap)
                              previous.duration < 300 && // Previous session < 5 minutes
                              current.duration < 300 && // Current session < 5 minutes
                              previous.metric == current.metric && // Same metric type
                              previous.sourceName == current.sourceName // Same source app
            
            if shouldMerge {
                currentGroup.append(current)
            } else {
                // Finalize the current group
                merged.append(createMergedSample(from: currentGroup))
                currentGroup = [current]
            }
        }
        
        // Don't forget the last group
        merged.append(createMergedSample(from: currentGroup))
        
        return merged
    }
    
    /// Create a single merged sample from a group of samples
    private func createMergedSample(from samples: [HealthKitSample]) -> HealthKitSample {
        guard !samples.isEmpty else {
            fatalError("Cannot create merged sample from empty array")
        }
        
        // If only one sample, return it as-is
        if samples.count == 1 {
            return samples[0]
        }
        
        // Merge multiple samples
        let sortedByDate = samples.sorted { $0.startDate < $1.startDate }
        let earliestStart = sortedByDate.first!.startDate
        let latestEnd = sortedByDate.max { $0.endDate < $1.endDate }!.endDate
        let totalDuration = latestEnd.timeIntervalSince(earliestStart)
        
        // Create a combined ID from all merged sample IDs
        let combinedID = sortedByDate.map { $0.id }.joined(separator: "_")
        
        return HealthKitSample(
            id: combinedID,
            startDate: earliestStart,
            endDate: latestEnd,
            duration: totalDuration,
            metric: samples[0].metric,
            sourceName: samples[0].sourceName
        )
    }
    
    /// Start observing HealthKit changes for real-time updates
    private func startHealthKitObservers() {
        // Delegate to ViewModel
        viewModel.startHealthKitObservers(for: goals)
    }
    
    /// Stop all HealthKit observers
    private func stopHealthKitObservers() {
        // Delegate to ViewModel
        viewModel.stopHealthKitObservers()
    }
    
    
    // MARK: - AI Planning
    
    /// Parse a time string (e.g., "09:30") and combine it with a date to create a full Date object
    private func parseTimeString(_ timeString: String, for date: Date) -> Date? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]) else {
            return nil
        }
        
        var calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hours
        dateComponents.minute = minutes
        dateComponents.second = 0
        
        return calendar.date(from: dateComponents)
    }
    
    /// Generate a daily plan and create GoalSession objects
    private func generateDailyPlan() async {
        await MainActor.run {
            planningViewModel.isPlanning = true
            planningViewModel.showPlanningComplete = false
            // Clear previous revealed sessions
            planningViewModel.revealedSessionIDs.removeAll()
        }
        defer { 
            Task { @MainActor in
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    planningViewModel.isPlanning = false
                    planningViewModel.planningTask = nil
                    return
                }
                
                // Show completion state immediately when planning finishes
                planningViewModel.isPlanning = false
                planningViewModel.planningTask = nil
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    planningViewModel.showPlanningComplete = true
                }
                
                // Keep completion state visible for 0.6 seconds
                try? await Task.sleep(for: .seconds(0.6))
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    planningViewModel.showPlanningComplete = false
                }
                
                // Update timestamp to cache when plan was last generated
                lastPlanGeneratedTimestamp = Date().timeIntervalSince1970
                AppLogger.planner.debug("Updated plan generation timestamp")
                
                // Reload widgets to show updated sessions
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
        
        do {
            // Generate the plan using active goals
            var activeGoals = goals.filter { $0.status == .active }
            
            // Filter by selected themes if any are selected
            if !planningViewModel.selectedThemes.isEmpty {
                activeGoals = activeGoals.filter { goal in
                    guard let primaryTag = goal.primaryTag else { return false }
                    return planningViewModel.selectedThemes.contains(primaryTag.themeID)
                }
            }
            
            // Set max sessions in planner preferences
            var preferences = planningViewModel.plannerPreferences
            if !unlimitedPlannedSessions {
                preferences.maxSessionsPerDay = maxPlannedSessions
            } else {
                preferences.maxSessionsPerDay = 100 // Effectively unlimited
            }
            
            // Apply time-based limit (assuming ~30 minutes per session on average)
            let timeBasedMaxSessions = planningViewModel.availableTimeMinutes / 30
            preferences.maxSessionsPerDay = min(
                preferences.maxSessionsPerDay,
                max(1, timeBasedMaxSessions)
            )
            
            // Clear planning details at the start to give a "from scratch" appearance
            await MainActor.run {
                for session in sessions {
                    session.clearPlanningDetails()
                }
                modelContext.safeSave()
            }
            
            // Use streaming to get real-time updates
            let stream = planningViewModel.planner.streamDailyPlan(
                for: activeGoals,
                goalSessions: sessions,
                currentDate: day.startDate,
                userPreferences: preferences
            )
            
            var latestPlan: DailyPlan?
            
            for try await partialPlan in stream {
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    AppLogger.planner.debug("Planning cancelled by user")
                    return
                }
                
                // Convert partial plan to full plan if we have sessions
                if let sessions = partialPlan.sessions {
                    let fullyGeneratedSessions = sessions.compactMap { partialSession -> PlannedSession? in
                        guard let id = partialSession.id,
                              let goalTitle = partialSession.goalTitle,
                              let recommendedStartTime = partialSession.recommendedStartTime,
                              let suggestedDuration = partialSession.suggestedDuration,
                              let priority = partialSession.priority,
                              let reasoning = partialSession.reasoning else {
                            return nil
                        }
                        
                        return PlannedSession(
                            id: id,
                            goalTitle: goalTitle,
                            recommendedStartTime: recommendedStartTime,
                            suggestedDuration: suggestedDuration,
                            priority: priority,
                            reasoning: reasoning
                        )
                    }
                    
                    // Only update latestPlan - don't apply yet to avoid reordering during streaming
                    if !fullyGeneratedSessions.isEmpty {
                        let plan = DailyPlan(
                            sessions: fullyGeneratedSessions,
                            overallStrategy: partialPlan.overallStrategy ?? nil
                        )
                        latestPlan = plan
                    }
                }
            }
            
            // Apply the final plan once after streaming completes
            if let plan = latestPlan {
                await applyPlan(plan)
                await animatePlannedSessions(plan)

                
                // Clear planning details for sessions NOT in the plan
                await MainActor.run {
                    let plannedGoalIDs = Set(plan.sessions.compactMap { UUID(uuidString: $0.id) })
                    for session in sessions {
                        guard let goalID = session.goal?.id else { continue }
                        if !plannedGoalIDs.contains(goalID) {
                            session.clearPlanningDetails()
                        }
                    }
                    modelContext.safeSave()
                }
            }
            
            // Ensure all active goals have sessions (even if not in the plan)
            await MainActor.run {
                let allActiveGoals = goals.filter { $0.status == .active }
                let existingSessionGoalIDs = Set(sessions.compactMap { $0.goal?.id })
                
                for goal in allActiveGoals {
                    if !existingSessionGoalIDs.contains(goal.id) {
                        // Create session for goal not in the plan
                        let session = GoalSession(title: goal.title, goal: goal, day: day)
                        session.status = .active
                        modelContext.insert(session)
                        
                        // Create checklist item sessions for this goal session
                        if let checklistItems = goal.checklistItems {
                            for checklistItem in checklistItems {
                                let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                                modelContext.insert(itemSession)
                                session.checklist?.append(itemSession)
                            }
                        }
                    }
                }
                
                modelContext.safeSave()
            }
            
        } catch {
            AppLogger.planner.error("Planning failed: \(error)")
            
            // Show error alert
            #if os(iOS)
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            #endif
        }
    }
    
    /// Animate the reveal of planned sessions one by one
    private func animatePlannedSessions(_ plan: DailyPlan) async {
        // Provide haptic feedback for completion
        #if os(iOS)
        await MainActor.run {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        }
        #endif
    }
    
    /// Analyze historical sessions to find usage patterns for a goal
    private func analyzeUsagePattern(for goal: Goal, session: GoalSession, currentHour: Int) -> Bool {
        // Get historical sessions for this specific GoalSession
        let historicalSessions = session.historicalSessions
        
        // Filter to sessions in the past 2 weeks
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recentSessions = historicalSessions.filter { $0.startDate >= twoWeeksAgo }
        
        // Count how many times this goal was worked on in the current hour (+/- 1 hour window)
        let sessionsInTimeWindow = recentSessions.filter { histSession in
            let sessionHour = Calendar.current.component(.hour, from: histSession.startDate)
            return abs(sessionHour - currentHour) <= 1
        }
        
        // If this goal has been worked on 3+ times in this time window over the past 2 weeks, consider it a pattern
        return sessionsInTimeWindow.count >= 3
    }
    
    /// Calculate recommendation reasons for a session
    private func calculateRecommendationReasons(for session: GoalSession, goal: Goal) -> [RecommendationReason] {
        var reasons: [RecommendationReason] = []
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        let currentWeekday = calendar.component(.weekday, from: Date())
        
        // 1. Weekly Progress - check if behind for the day of week
        let dailyTarget = goal.weeklyTarget / 7
        let weeklyTarget = goal.weeklyTarget
        let daysIntoWeek = currentWeekday // Sunday = 1, Saturday = 7
        let expectedProgress = (weeklyTarget / 7) * TimeInterval(daysIntoWeek)
        // This would need actual weekly data - for now use daily as proxy
        if session.elapsedTime < dailyTarget * 0.5 && daysIntoWeek >= 4 { // Less than 50% and past Wednesday
            reasons.append(.weeklyProgress)
        }
        
        // 2. Quick Finish - less than 25% remaining
        let remaining = dailyTarget - session.elapsedTime
        if remaining > 0 && remaining < dailyTarget * 0.25 {
            reasons.append(.quickFinish)
        }
        
        // 3. Preferred Time - matches user's preferred time of day
        let preferredTimes = goal.timesForWeekday(currentWeekday)
        if !preferredTimes.isEmpty {
            let matchesPreferred = preferredTimes.contains { timeOfDay in
                switch timeOfDay {
                case .morning: return currentHour >= 6 && currentHour < 10
                case .midday: return currentHour >= 10 && currentHour < 14
                case .afternoon: return currentHour >= 14 && currentHour < 18
                case .evening: return currentHour >= 18 && currentHour < 22
                case .night: return currentHour >= 22 || currentHour < 6
                }
            }
            if matchesPreferred {
                reasons.append(.preferredTime)
            }
        }
        
        // 4. Energy Level - morning/early afternoon are typically high energy
        if (6...9).contains(currentHour) || (13...15).contains(currentHour) {
            reasons.append(.energyLevel)
        }
        
        // 5. Planned Theme - check if matches selected themes
        if let primaryTag = goal.primaryTag, planningViewModel.selectedThemes.contains(primaryTag.themeID) {
            reasons.append(.plannedTheme)
        }
        
        // 6. Usual Time - based on historical usage patterns
        if analyzeUsagePattern(for: goal, session: session, currentHour: currentHour) {
            reasons.append(.usualTime)
        }
        
        return reasons
    }
    
    /// Apply the generated plan by creating GoalSession objects
    @MainActor
    private func applyPlan(_ plan: DailyPlan) async {
            // Get existing sessions to avoid duplicates during streaming
            let existingSessionGoalIDs = Set(sessions.compactMap { $0.goal?.id })
            
            // Sort planned sessions by start time to maintain stable order during streaming
            let sortedPlannedSessions = plan.sessions.sorted { session1, session2 in
                // Parse time strings to compare
                if let time1 = parseTimeString(session1.recommendedStartTime, for: day.startDate),
                   let time2 = parseTimeString(session2.recommendedStartTime, for: day.startDate) {
                    return time1 < time2
                }
                // Fallback to priority if times can't be parsed
                return session1.priority < session2.priority
            }
            
            // Create new GoalSession objects for each planned session
            for plannedSession in sortedPlannedSessions {
                // Try to find the goal by UUID first
                var goal: Goal?
                let goalIDs = goals.map { $0.id }
                if let goalID = UUID(uuidString: plannedSession.id) {
                    // UUID parsing succeeded - find by ID
                    goal = goals.first(where: { $0.id == goalID })
                }
                
                
                // Fallback: if UUID parsing failed or goal not found, try matching by title
                if goal == nil {
                    goal = goals.first(where: { $0.title == plannedSession.goalTitle })
                }
                
                guard let matchedGoal = goal else {
                    AppLogger.planner.warning("Could not find goal for planned session: \(plannedSession.goalTitle) (ID: \(plannedSession.id))")
                    continue
                }
                
                // Check if a session already exists for this goal
                if let existingSession = sessions.first(where: { $0.goal?.id == matchedGoal.id }) {
                    // Update existing session's planning details
                    // Convert time string (e.g., "09:30") to Date for today
                    if let startTime = parseTimeString(plannedSession.recommendedStartTime, for: day.startDate) {
                        let reasons = calculateRecommendationReasons(for: existingSession, goal: matchedGoal)
                        existingSession.updatePlanningDetails(
                            startTime: startTime,
                            duration: plannedSession.suggestedDuration,
                            priority: plannedSession.priority,
                            reasoning: plannedSession.reasoning,
                            reasons: reasons
                        )
                    }
                    existingSession.status = .active
                } else {
                    // Create a new GoalSession only if one doesn't exist
                    let session = GoalSession(title: matchedGoal.title, goal: matchedGoal, day: day)
                    
                    // Apply planning details
                    // Convert time string (e.g., "09:30") to Date for today
                    if let startTime = parseTimeString(plannedSession.recommendedStartTime, for: day.startDate) {
                        let reasons = calculateRecommendationReasons(for: session, goal: matchedGoal)
                        session.updatePlanningDetails(
                            startTime: startTime,
                            duration: plannedSession.suggestedDuration,
                            priority: plannedSession.priority,
                            reasoning: plannedSession.reasoning,
                            reasons: reasons
                        )
                    }
                    
                    // Mark as active
                    session.status = .active
                    
                    // Insert into model context
                    modelContext.insert(session)
                    
                    // Create checklist item sessions for this goal session
                    if let checklistItems = matchedGoal.checklistItems {
                        for checklistItem in checklistItems {
                            let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                            modelContext.insert(itemSession)
                            session.checklist?.append(itemSession)
                        }
                    }
                }
            }
            
            // Save the new/updated sessions
            modelContext.safeSave()
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(sessionID: String?) {
        guard let sessionID = sessionID,
              let uuid = UUID(uuidString: sessionID),
              let session = sessions.first(where: { $0.id == uuid }) else {
            AppLogger.app.warning("Session not found for ID: \(sessionID ?? "nil")")
            return
        }
        
        AppLogger.app.info("Found session to open: \(session.title)")
        
        // Open the session detail using selectedSession which triggers NavigationLink
        navigation.selectedSession = session
        
    }
}

/// Creates an isolated in-memory ModelContainer for preview purposes only
/// Returns a default container if initialization fails
private func previewOnlyContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    
    do {
        return try ModelContainer(
            for: Day.self, Goal.self, GoalSession.self, GoalTag.self,
            configurations: config
        )
    } catch {
        // Fallback for preview - create minimal container
        fatalError("Failed to create preview ModelContainer: \(error.localizedDescription)")
    }
}

#Preview {
    let store = GoalStore()
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    let healthKitManager = HealthKitManager()
    let healthKitSyncService = HealthKitSyncService(healthKitManager: healthKitManager)
    
    // Create dependencies for preview
    let container = previewOnlyContainer()
    let repository = SessionRepository(modelContext: container.mainContext)
    let logger = ProductionLogger(subsystem: "com.moosa.momentum.ios", category: "SessionViewModel")
    let sessionViewModel = SessionViewModel(repository: repository, logger: logger)
    let healthKitViewModel = HealthKitViewModel(
        healthKitManager: healthKitManager,
        healthKitSyncService: healthKitSyncService
    )
    let calendarViewModel = CalendarViewModel(calendarEventStore: EKEventStore())
    
    let viewModel = ContentViewModel(
        navigation: NavigationState(),
        sessionViewModel: sessionViewModel,
        healthKitViewModel: healthKitViewModel,
        calendarViewModel: calendarViewModel,
        planningViewModel: PlanningViewModel(),
        focusFilterStore: FocusFilterStore.shared,
        healthKitManager: healthKitManager,
        weatherManager: WeatherManager.shared
    )
    ContentView(day: day, viewModel: viewModel)
        .environment(store)
        .modelContainer(for: Item.self, inMemory: true)
}

