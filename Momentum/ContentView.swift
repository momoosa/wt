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
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Query var goals: [Goal]
    @Query var _sessions: [GoalSession]
    let day: Day
    private let dayID: String
    @Namespace var animation
    
    // Filtered sessions for the current day only, deduplicated by goal
    var sessions: [GoalSession] {
        var seen = Set<String>()
        return _sessions.filter { session in
            guard session.day?.id == day.id else { return false }
            let key = session.goal?.id.uuidString ?? session.id.uuidString
            return seen.insert(key).inserted
        }
    }

    // View Model (business logic) - injected from WeektimeApp
    @State var viewModel: ContentViewModel

    // Navigation and UI state (from ViewModel when created)
    @State var navigation = NavigationState()

    // Timer manager for session tracking
    @State var timerManager: SessionTimerManager?

    // Planning
    @State var planningViewModel = PlanningViewModel()

    // Focus filter
    @State var focusFilterStore = FocusFilterStore.shared

    // HealthKit (delegated to ViewModel)
    @State var healthKitManager = HealthKitManager()
    @AppStorage("maxPlannedSessions") var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") var unlimitedPlannedSessions: Bool = false
    @AppStorage("lastPlanGeneratedTimestamp") var lastPlanGeneratedTimestamp: Double = 0

    // Weather
    @State var weatherManager = WeatherManager.shared

    // Calendar
    @State var nextCalendarEvent: EKEvent?
    @State var calendarEventStore = EKEventStore()
    
    // Lifecycle guards to prevent redundant work
    @State var hasCompletedSetup = false
    @State var isRefreshingGoals = false
    
    // Background task tracking for cancellation on disappear
    @State var backgroundTasks: [Task<Void, Never>] = []
    
    // Goal editor view model - held in @State to survive parent re-renders
    @State private var goalEditorViewModel: GoalEditorViewModel?
    
    // Progress Card Tile Visibility Settings
    @AppStorage("showProgressTile") var showProgressTile: Bool = true
    @AppStorage("showWeatherTile") var showWeatherTile: Bool = true
    @AppStorage("showCalendarTile") var showCalendarTile: Bool = true
    
    // Shared session actions for child views (eliminates callback prop drilling)
    @State var sessionActions = SessionActions()

    // MARK: - Initialization

    init(day: Day, viewModel: ContentViewModel) {
        self.day = day
        self.dayID = day.id
        let dayID = day.id
        self.__sessions = Query(filter: #Predicate<GoalSession> { session in
            session.day?.id == dayID
        })
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        mainListView
            .environment(\.sessionActions, sessionActions)
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
            .overlay(alignment: .bottom) {
                if navigation.showExpandedCapsule {
                    expandedCapsuleOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: navigation.showExpandedCapsule)
            .sheet(isPresented: $navigation.isSearching) {
                searchSheet
                    .navigationTransition(.zoom(sourceID: "searchButton", in: animation))
            }
            .toolbar {
                toolbarContent
            }
            .task {
                // Configure shared session actions for child views
                sessionActions.onSkip = { [self] session in skip(session: session) }
                sessionActions.onSyncHealthKit = { [self] in syncHealthKitData(userInitiated: true) }
                sessionActions.isSyncingHealthKit = viewModel.isSyncingHealthKit
                setupOnAppear()
            }
            .onChange(of: viewModel.isSyncingHealthKit) { _, newValue in
                sessionActions.isSyncingHealthKit = newValue
            }
            .onDisappear {
                timerManager?.activeSession?.stopUITimer()
                // Cancel background tasks that may still be running
                for task in backgroundTasks {
                    task.cancel()
                }
                backgroundTasks.removeAll()
                planningViewModel.planningTask?.cancel()
            }
            .onChange(of: goals) { old, new in
                handleGoalsChange(old: old, new: new)
                goalStore.goals = new
            }
            .onChange(of: _sessions) { _, _ in
                // Update goalStore with day-filtered sessions
                // Using _sessions (the @Query) instead of computed sessions
                // to avoid creating intermediate arrays for the equality check
                goalStore.sessions = sessions
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
                    .navigationTransition(.zoom(sourceID: "plannerButton", in: animation))
            }

        
            .sheet(isPresented: $navigation.showingGoalEditor, onDismiss: {
                goalEditorViewModel = nil
            }) {
                if let vm = goalEditorViewModel {
                    GoalEditorView(viewModel: vm)
                        .navigationTransition(
                            .zoom(sourceID: "info", in: animation)
                        )
                }
            }
            .onChange(of: navigation.showingGoalEditor) { _, show in
                if show {
                    goalEditorViewModel = GoalEditorViewModel()
                }
            }
            .sheet(isPresented: $navigation.showAllGoals) {
                allGoalsSheet
            }
            .fullScreenCover(isPresented: $navigation.showNowPlaying) {
                nowPlayingView
                    .navigationTransition(.zoom(sourceID: "plannerButton", in: animation))
            }
            .sheet(isPresented: $navigation.showSettings) {
                settingsSheet
            }
            .sheet(isPresented: $navigation.showDayOverview) {
                dayOverviewSheet
                    .navigationTransition(.zoom(sourceID: "dayOverviewButton", in: animation))
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
                    .tint(session.theme.color(for: colorScheme))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus filter active: \(focusFilterStore.activeFocusTagTitles.joined(separator: ", "))")
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
            .refreshable {
                syncHealthKitData(userInitiated: true)
                refreshGoals()
            }
            .safeAreaInset(edge: .bottom) {
                if !navigation.showExpandedCapsule {
                    bottomCapsuleBar
                        .transition(.move(edge: .bottom))
                }
            }
        }
    }
    

    
    @ViewBuilder
    private func contextualSectionView(section: ContextualSection) -> some View {
        if case .recommendedNow = section.type {
            // Recommended Now section with featured card style
            Section {
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let icon = section.type.icon {
                            Image(systemName: icon)
                                .foregroundStyle(section.type.iconColor)
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
                        sessionToLogManually: $navigation.sessionToLogManually
                    )
                }
                .listSectionSpacing(.compact)
            }
        } else {
            collapsibleSection(section: section)
        }
    }
    
    private func collapsibleSection(section: ContextualSection) -> some View {
        let isExpanded = navigation.expandedSections.contains(section.type)
        
        return Section {
            if isExpanded {
                ForEach(section.sessions) { session in
                    sessionRow(for: session)
                }
            }
        } header: {
            Button(action: {
                withAnimation {
                    if isExpanded {
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
                                .foregroundStyle(section.type.iconColor)
                        }
                        Text(section.type.title)
                            .font(.headline)
                        if !isExpanded && !section.sessions.isEmpty {
                            Text("(\(section.sessions.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let explanation = section.explanation, isExpanded {
                        Text(explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(section.type.title), \(section.sessions.count) sessions, \(isExpanded ? "expanded" : "collapsed")")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        }
        .id(section.type)
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
    
    // MARK: - Daily Progress Card (see ContentView/Components/DailyProgressCardView.swift)
    // MARK: - Weather & Calendar Helpers (see ContentView/Components/DailyProgressCardView.swift)
    
    // MARK: - Toolbar (see ContentView/Components/ToolbarBuilder.swift)
    
    // MARK: - Setup Methods (see ContentView/Integration/SetupMethods.swift)
    
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
//            planningViewModel.cachedThemes = availableGoalThemes
//            
//            // Prewarm the model to reduce initial planning delay
//            Task {
//                await planningViewModel.planner.prewarm()
//            }
        }
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
            sessionToLogManually: $navigation.sessionToLogManually
        )
    }
    
    private func manualLogSheet(for session: GoalSession) -> some View {
        ManualLogSheet(session: session, day: day)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
    
    // MARK: - Computed Properties
    
    var availableGoalThemes: [GoalTag] {
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
    
    var availableFilters: [Filter] {
        SessionFilterService.buildAvailableFilters(from: availableGoalThemes, sessions: sessions)
    }
    
    var sessionCountsForFilters: [FilterCount] {
        availableFilters.map { filter in
            FilterCount(
                filter: filter,
                count: SessionFilterService.count(focusFilteredSessions, for: filter)
            )
        }
    }

    /// Sessions pre-filtered by the active Focus filter (if any).
    /// When no Focus filter is active this is identical to `sessions`.
    var focusFilteredSessions: [GoalSession] {
        let activeTags = focusFilterStore.activeFocusTagTitles
        guard !activeTags.isEmpty else { return Array(sessions) }
        return sessions.filter { session in
            guard let primaryTag = session.goal?.primaryTag else { return false }
            return activeTags.contains(primaryTag.title)
        }
    }


    
    // MARK: - Session Management (see ContentView/Handlers/SessionManagement.swift)
    
    // MARK: - Scroll & Recommendations
    
    func scrollToFilterSection(_ filter: Filter) {
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
    
    func getRecommendedSessions() -> [GoalSession] {
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
    func sessionRow(for session: GoalSession) -> some View {
        SessionRowView(
            session: session,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: $navigation.selectedSession,
            sessionToLogManually: $navigation.sessionToLogManually
        )
    }
    

    // MARK: - HealthKit Integration

    func syncHealthKitData(userInitiated: Bool = false) {
        Task {
            await viewModel.syncHealthKitData(
                for: goals,
                sessions: Array(sessions),
                in: day,
                modelContext: modelContext,
                userInitiated: userInitiated
            )
        }
    }
}

/// Creates an isolated in-memory ModelContainer for preview purposes only
/// Returns a default container if initialization fails
func previewOnlyContainer() -> ModelContainer {
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

