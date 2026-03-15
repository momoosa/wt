//
//  ContentView.swift
//  Momentum
//
//  Created by Mo Moosa on 22/07/2025.
//

import SwiftUI
import SwiftData
import MomentumKit
import HealthKit
import OSLog
import EventKit
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
    let day: Day
    @State private var selectedSession: GoalSession?
    @State private var sessionIDToOpen: String?
    @Namespace var animation
    @State private var showingGoalEditor = false
    @State private var activeFilter: Filter = .activeToday
    @State private var navigationPath = NavigationPath()
    
    // Timer manager for session tracking
    @State private var timerManager: SessionTimerManager?
    
    // Planning
    @State private var planningViewModel = PlanningViewModel()
    
    // Navigation state
    @State private var showPlannerSheet = false
    @State private var showAllGoals = false
    @State private var showSettings = false
    @State private var showNowPlaying = false
    @State private var showDayOverview = false
    @State private var sessionToLogManually: GoalSession?
    
    // Focus filter
    @State private var focusFilterStore = FocusFilterStore.shared

    // Search state
    @State private var isSearching = false
    @State private var searchText = ""
    
    // Toast state
    @State private var toastConfig: ToastConfig?
    
    // HealthKit
    @State private var healthKitManager = HealthKitManager()
    @State private var healthKitObservers = [HKObserverQuery]()
    @State private var isSyncingHealthKit = false
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0
    
    // Weather
    @State private var weatherManager = WeatherManager.shared
    
    // Calendar
    @State private var nextCalendarEvent: EKEvent?
    @State private var calendarEventStore = EKEventStore()
    
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
                        activeFilter: $activeFilter,
                        sessionCounts: sessionCountsForFilters
                    )
                    Spacer()
                }
            }
            .overlay(alignment: .bottom) {
                if let toastConfig = toastConfig {
                    VStack {
                        Spacer()
                        ToastView(
                            config: toastConfig,
                            onDismiss: {
                                self.toastConfig = nil
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $isSearching) {
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
            .sheet(isPresented: $showPlannerSheet) {
                plannerSheet
            }

        
            .sheet(isPresented: $showingGoalEditor) {
                goalEditorSheet
            }
            .sheet(isPresented: $showAllGoals) {
                allGoalsSheet
            }
            .fullScreenCover(isPresented: $showNowPlaying) {
                nowPlayingView
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .sheet(isPresented: $showDayOverview) {
                dayOverviewSheet
            }
            .sheet(item: $sessionToLogManually) { session in
                manualLogSheet(for: session)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSessionFromWidget"))) { notification in
                if let sessionID = notification.object as? String {
                    handleDeepLink(sessionID: sessionID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSearch"))) { _ in
                isSearching = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNewGoal"))) { _ in
                showingGoalEditor = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowToast"))) { notification in
                if let message = notification.object as? String {
                    toastConfig = ToastConfig(
                        message: message,
                        showUndo: false
                    )
                }
            }
            .navigationDestination(item: $selectedSession) { session in
                if let timerManager = timerManager {
                    GoalSessionDetailView(
                        session: session,
                        animation: animation,
                        timerManager: timerManager,
                        onMarkedComplete: {
                            // Dismiss the detail view
                            selectedSession = nil
                            
                            // Show toast
                            toastConfig = ToastConfig(
                                message: "Marked as complete - moved to Completed filter",
                                showUndo: false
                            )
                        }
                    )
                    .tint(session.goal?.primaryTag?.themePreset.dark ?? .blue)
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
            selectedSession: $selectedSession,
            sessionToLogManually: $sessionToLogManually,
            searchText: $searchText,
            onSkip: skip,
            onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
            isSyncingHealthKit: isSyncingHealthKit,
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
        List {
            // Show daily progress card once user has saved at least one session
            Section {
                
            } footer: {
                Spacer()
                    .frame(height: LayoutConstants.Heights.smallSpacer)
            }

            if activeFilter == .activeToday {
                Section {
                    dailyProgressCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listSectionSpacing(.compact)
            }

            if !focusFilteredSessions.isEmpty || planningViewModel.isPlanning || planningViewModel.showPlanningComplete {
                // Only show contextual sections for "Today" filter
                if activeFilter == .activeToday {
                    let recommendedSessions = getRecommendedSessions()
                    let allSessions = SessionFilterService.filter(
                        focusFilteredSessions,
                        by: activeFilter,
                        validationCheck: isGoalValid,
                        weatherManager: weatherManager
                    )
                    
                    // Group sessions into contextual sections
                    let contextualSections = ContextualSection.groupSessions(
                        allSessions,
                        recommendedSessions: recommendedSessions,
                        allGoals: sessions
                    )
                    
                    ForEach(contextualSections) { section in
                        contextualSectionView(section: section)
                    }
                } else {
                    // For other filters, show all sessions as regular rows
                    if !focusFilteredSessions.isEmpty {
                        let allSessions = SessionFilterService.filter(
                            focusFilteredSessions,
                            by: activeFilter,
                            validationCheck: isGoalValid,
                            weatherManager: weatherManager
                        )
                        
                        if !allSessions.isEmpty {
                            laterSection(sessions: allSessions)
                        }
                    }
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
    }
    

    @ViewBuilder
    private func recommendedSection(sessions: [GoalSession]) -> some View {
        // Header section
        Section {
        } header: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Recommended Now")
                    .font(.headline)
            }
        }
        .listSectionSpacing(.compact)
        
        // Individual card for each recommended session
        ForEach(sessions) { session in
            Section {
                RecommendedSessionRowView(
                    session: session,
                    day: day,
                    timerManager: timerManager,
                    animation: animation,
                    selectedSession: $selectedSession,
                    sessionToLogManually: $sessionToLogManually,
                    onSkip: skip,
                    onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
                    isSyncingHealthKit: isSyncingHealthKit
                )
            }
            .listSectionSpacing(.compact)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .opacity
            ))
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
            .listSectionSpacing(.compact)
            
            // Individual featured cards
            ForEach(section.sessions) { session in
                Section {
                    RecommendedSessionRowView(
                        session: session,
                        day: day,
                        timerManager: timerManager,
                        animation: animation,
                        selectedSession: $selectedSession,
                        sessionToLogManually: $sessionToLogManually,
                        onSkip: skip,
                        onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
                        isSyncingHealthKit: isSyncingHealthKit
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
                ForEach(section.sessions) { session in
                    sessionRow(for: session)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let icon = section.type.icon {
                            Image(systemName: icon)
                                .foregroundStyle(.blue)
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
            .listSectionSpacing(.compact)
            
        case .available:
            // Available goals section (backup goals not scheduled today)
            Section {
                ForEach(section.sessions) { session in
                    sessionRow(for: session)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let icon = section.type.icon {
                            Image(systemName: icon)
                                .foregroundStyle(.orange)
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
            .listSectionSpacing(.compact)
            
        case .later:
            // Later section (standard rows)
            Section {
                ForEach(section.sessions) { session in
                    sessionRow(for: session)
                }
            } header: {
                if sessions.count > 4 {
                    Text(section.type.title)
                        .font(.headline)
                }
            }
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
        return HStack(spacing: 12) {
            // Progress Ring
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
                    showDayOverview = true
                }

            // Weather Card
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
            }
            
            // Calendar Free Time Card
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
            }
            
            Spacer()
        }
        .padding()
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
                    showAllGoals = true
                } label: {
                    Image(systemName: "target")
                }
                EditButton()
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
            }
   
        }
#endif
        
    
  
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                isSearching = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .matchedTransitionSource(id: "searchButton", in: animation)
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                // Cache themes before showing sheet to avoid SwiftData faults
                planningViewModel.cachedThemes = availableGoalThemes
                showPlannerSheet = true
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
                    showNowPlaying = true
                }
                .frame(minWidth: 140.0)
            }
        }
        
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }
        
        ToolbarItem(placement: .bottomBar) {
            Button(action: { showingGoalEditor = true }) {
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
            try? modelContext.save()
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
            showPlannerSheet = false
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
        GoalEditorView()
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
        DayOverviewView(day: day, sessions: Array(sessions), goals: goals, animation: animation)
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
    
    private var sessionCountsForFilters: [Filter: Int] {
        var counts: [Filter: Int] = [:]
        for filter in availableFilters {
            counts[filter] = SessionFilterService.count(focusFilteredSessions, for: filter)
        }
        return counts
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

    
    init(day: Day) {
        self.day = day
        let dayID = day.id
        
        self._sessions = Query(
            filter: #Predicate<GoalSession> { event in
                event.day?.id == dayID
            }
        )
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
            try? modelContext.save()
            
            // Reload widgets when sessions are created or deleted
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
    
    func skip(session: GoalSession) {
        let previousStatus = session.status
        
        withAnimation {
            session.status = session.status == .skipped ? .active : .skipped
        }
        
        let message = session.status == .skipped ? "Goal skipped" : "Goal unskipped"
        toastConfig = ToastConfig(
            message: message,
            showUndo: true,
            onUndo: { [weak session] in
                guard let session = session else { return }
                withAnimation {
                    session.status = previousStatus
                }
            }
        )
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
    
    // MARK: - Recommendations
    
    /// Get recommended sessions for right now (top 3)
    private func getRecommendedSessions() -> [GoalSession] {
        return SessionFilterService.getRecommendedSessions(
            from: focusFilteredSessions,
            filter: activeFilter,
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
            selectedSession: $selectedSession,
            sessionToLogManually: $sessionToLogManually,
            onSkip: skip,
            onSyncHealthKit: { syncHealthKitData(userInitiated: true) },
            isSyncingHealthKit: isSyncingHealthKit
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
                activeFilter = .activeToday
            }
            
            toastConfig = ToastConfig(
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
        toastConfig = ToastConfig(
            message: "Adjusted start time: \(minutes)m \(direction)",
            showUndo: false
        )
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    func handleDailyGoalAdjustment(for session: GoalSession, adjustment: TimeInterval) {
        // Adjust the session's daily target
        let newTarget = max(60, session.dailyTarget + adjustment) // Minimum 1 minute
        session.dailyTarget = newTarget
        
        // Update active session if needed
        if let timerManager,
           let activeSession = timerManager.activeSession,
           activeSession.id == session.id {
            activeSession.dailyTarget = newTarget
        }
        
        // Save context
        try? modelContext.save()
        
        let minutes = Int(abs(adjustment) / 60)
        let direction = adjustment > 0 ? "increased" : "decreased"
        toastConfig = ToastConfig(
            message: "Daily goal \(direction) by \(minutes)m",
            showUndo: false
        )
        
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
        return timerManager?.timerText(for: session) ?? "TODO..."
    }
    
    // MARK: - HealthKit Integration
    
    private func syncHealthKitData(userInitiated: Bool = false) {
        guard healthKitManager.isHealthKitAvailable else { return }
        
        // Set syncing state
        isSyncingHealthKit = true
        
        // Get all goals with HealthKit sync enabled
        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }
        
        AppLogger.healthKit.info("Starting HealthKit sync for \(healthKitGoals.count) goals (user initiated: \(userInitiated))")
        for goal in healthKitGoals {
            AppLogger.healthKit.info("  - '\(goal.title)' (metric: \(goal.healthKitMetric?.rawValue ?? "none"))")
        }
        
        // Request authorization if needed
        let metrics = healthKitGoals.compactMap { $0.healthKitMetric }
        guard !metrics.isEmpty else {
            isSyncingHealthKit = false
            return
        }
        
        Task {
            // Request authorization first (this will be a no-op if already authorized)
            do {
                try await healthKitManager.requestAuthorization(for: metrics)
            } catch {
                AppLogger.healthKit.error("HealthKit authorization failed: \(error)")
                return
            }
            
            // Track allocated samples to prevent double-counting across goals
            var allocatedSampleIDs = Set<String>()
            
            // Track sync results for toast notification
            var syncedGoalsCount = 0
            var totalDurationImported: TimeInterval = 0
            var syncErrors: [String] = []
            
            // Fetch and allocate data for each goal (first-come-first-served)
            for goal in healthKitGoals {
                guard let metric = goal.healthKitMetric else { continue }
                
                do {
                    // Fetch individual samples (for history display)
                    let samples = try await healthKitManager.fetchSamples(
                        for: metric,
                        from: day.startDate,
                        to: day.endDate
                    )
                    
                    // Filter out samples created by this app to prevent double-counting
                    let externalSamples = samples.filter { !$0.isFromThisApp }
                    
                    // Filter out samples already allocated to other goals
                    let availableSamples = externalSamples.filter { !allocatedSampleIDs.contains($0.id) }
                    
                    // Merge samples to avoid double-counting
                    let mergedSamples = mergeSamples(availableSamples)
                    
                    // Calculate total duration from merged samples
                    let duration = mergedSamples.reduce(0.0) { $0 + $1.duration }
                    
                    // Update the corresponding session
                    await MainActor.run {
                        AppLogger.healthKit.info("Syncing HealthKit data for goal '\(goal.title)' (metric: \(metric.rawValue))")
                        AppLogger.healthKit.info("  - Found \(samples.count) samples total")
                        AppLogger.healthKit.info("  - Filtered out \(samples.count - externalSamples.count) samples from this app")
                        AppLogger.healthKit.info("  - \(availableSamples.count) external samples available after allocation")
                        AppLogger.healthKit.info("  - Merged to \(mergedSamples.count) samples")
                        AppLogger.healthKit.info("  - Total duration: \(duration.formatted()) seconds")
                        AppLogger.healthKit.info("  - Looking for session in \(sessions.count) total sessions")
                        
                        if let session = sessions.first(where: { $0.goal?.id == goal.id }) {
                            AppLogger.healthKit.info("  - Found matching session for goal '\(goal.title)'")
                            session.updateHealthKitTime(duration)
                            
                            // Mark these samples as allocated
                            for sample in mergedSamples {
                                allocatedSampleIDs.insert(sample.id)
                            }
                            
                            // Track sync results
                            if duration > 0 {
                                syncedGoalsCount += 1
                                totalDurationImported += duration
                            }
                            
                            // Create or update historical sessions from HealthKit samples
                            syncHistoricalSessions(from: mergedSamples, for: goal, in: session)
                        } else {
                            AppLogger.healthKit.warning("  - No session found for goal '\(goal.title)' (ID: \(goal.id))")
                            AppLogger.healthKit.warning("  - Available sessions: \(sessions.map { ($0.goal?.title ?? "nil", $0.goal?.id.uuidString ?? "nil") })")
                        }
                    }
                } catch {
                    AppLogger.healthKit.error("Failed to fetch HealthKit data for \(goal.title): \(error)")
                    syncErrors.append(goal.title)
                }
            }
            
            // Reset syncing state and show toast when done
            await MainActor.run {
                isSyncingHealthKit = false
                
                // Only show toast if user-initiated
                if userInitiated {
                    // Show toast with sync results
                    if !syncErrors.isEmpty {
                        // Show error toast
                        toastConfig = ToastConfig(
                            message: "Sync failed for \(syncErrors.count) goal\(syncErrors.count == 1 ? "" : "s")"
                        )
                    } else if syncedGoalsCount > 0 {
                        // Show success toast with details
                        let minutes = Int(totalDurationImported / 60)
                        let goalText = syncedGoalsCount == 1 ? "goal" : "goals"
                        let minuteText = minutes == 1 ? "minute" : "minutes"
                        toastConfig = ToastConfig(
                            message: "Synced \(syncedGoalsCount) \(goalText): \(minutes) \(minuteText) imported"
                        )
                    } else {
                        // No data synced
                        toastConfig = ToastConfig(
                            message: "No new data to sync"
                        )
                    }
                }
            }
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
        // Stop any existing observers first
        stopHealthKitObservers()
        
        guard healthKitManager.isHealthKitAvailable else { return }
        
        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }
        let uniqueMetrics = Set(healthKitGoals.compactMap { $0.healthKitMetric })
        
        for metric in uniqueMetrics {
            do {
                let observer = try healthKitManager.observeMetric(metric) { _ in
                    // When HealthKit data changes, re-sync
                    self.syncHealthKitData()
                }
                healthKitObservers.append(observer)
            } catch {
                AppLogger.healthKit.error("Failed to start observer for \(metric.displayName): \(error)")
            }
        }
    }
    
    /// Stop all HealthKit observers
    private func stopHealthKitObservers() {
        for observer in healthKitObservers {
            healthKitManager.stopObserving(observer)
        }
        healthKitObservers.removeAll()
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
                try? modelContext.save()
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
                    try? modelContext.save()
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
                
                try? modelContext.save()
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
            try? modelContext.save()
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
        selectedSession = session
        
    }
}

#Preview {
    let store = GoalStore()
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .environment(store)
        .modelContainer(for: Item.self, inMemory: true)
}

