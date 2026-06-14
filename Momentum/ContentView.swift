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
    
    // Track which sections are currently visible so we can highlight the topmost pill
    @State private var visibleSectionIDs: Set<String> = []
    @State private var scrollProxy: ScrollViewProxy?
    
    // Permissions
    @State private var permissionsViewModel = AppPermissionsViewModel()
    
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
                    SectionPillBar(
                        sections: contextualSections,
                        visibleSectionType: navigation.visibleSectionType,
                        onSectionTapped: { sectionType in
                            if let section = contextualSections.first(where: { $0.type == sectionType }) {
                                withAnimation {
                                    scrollProxy?.scrollTo(section.id, anchor: .top)
                                }
                            }
                        }
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
                await permissionsViewModel.refresh()
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
                
                if let activeSession = timerManager?.activeSession {
                    activeSession.startUITimer()
                    
                    // Sync GoalSession.currentValue with the dynamic elapsed time
                    let dynamicElapsed = activeSession.elapsedTime + Date.now.timeIntervalSince(activeSession.startDate)
                    if let session = sessions.first(where: { $0.id == activeSession.id }),
                       session.targetUnit.isTimeBased {
                        session.currentValue = dynamicElapsed
                    }
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
                if show, goalEditorViewModel == nil {
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
            if !focusFilteredSessions.isEmpty {
                // Show daily progress card once user has saved at least one session
                Section {
                
                } footer: {
                    Spacer()
                        .frame(height: LayoutConstants.Heights.smallSpacer)
                }
            } else {
                // Greeting header for empty state
                Section {
                    Text(timeOfDayGreeting)
                        .font(.largeTitle.bold())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            // Inline permissions prompt — shown when any permission is undetermined
            if permissionsViewModel.hasAnyUndetermined {
                Section {
                    PermissionsPromptCard(viewModel: permissionsViewModel)
                        .listRowInsets(EdgeInsets())
                }
                .listSectionSpacing(.compact)
            }
            
            if !focusFilteredSessions.isEmpty || planningViewModel.isPlanning || planningViewModel.showPlanningComplete {
                ForEach(contextualSections) { section in
                    contextualSectionView(section: section)
                }
                
                // Show planning indicator after all sessions
                if planningViewModel.isPlanning || planningViewModel.showPlanningComplete {
                    planningIndicatorSection
                }
            } else {
                emptyStateView
            }
        }
        .onAppear { scrollProxy = proxy }
        } // ScrollViewReader
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
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
    

    
    // MARK: - Empty State
    
    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default: return "Good evening."
        }
    }
    
    private static let starterTemplateIDs = ["walk", "exercise_minutes", "meditation", "reading"]
    
    private var starterSuggestions: [(template: GoalTemplateSuggestion, category: GoalCategory)] {
        let data = GoalSuggestionsLoader.shared.loadSuggestions()
        return Self.starterTemplateIDs.compactMap { templateID in
            for category in data.categories {
                if let template = category.suggestions.first(where: { $0.id == templateID }) {
                    return (template, category)
                }
            }
            return nil
        }
    }
    
    @State private var iCloudSyncStatus: CloudKitSyncToast.SyncStatus?
    
    @ViewBuilder
    private var emptyStateView: some View {
        Section {
            VStack(spacing: 20) {
                // Decorative circle with plus icon
                ZStack {
                    Circle()
                        .fill(.pink.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(.pink.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.pink.opacity(0.6))
                }
                .padding(.top, 8)
                
                VStack(spacing: 8) {
                    Text("What do you want\nto make time for?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("Add your first goal and Momentum\nwill find the right moments for it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // iCloud sync status
                if let status = iCloudSyncStatus {
                    HStack(spacing: 10) {
                        Image(systemName: status.icon)
                            .font(.subheadline)
                            .foregroundStyle(status.color)
                            .symbolEffect(.pulse, isActive: status.isPulsing)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(status.title)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(status.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .task {
                await checkICloudSyncStatus()
            }
        }
        
        Section {
            ForEach(starterSuggestions, id: \.template.id) { item in
                HStack(spacing: 14) {
                    // Gradient icon circle
                    ZStack {
                        Circle()
                            .fill(item.category.themePreset.gradient(for: colorScheme))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: item.template.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.template.title)
                            .font(.subheadline.bold())
                        
                        Text("\(item.category.name) · \(item.template.duration)m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        openEditorWithTemplate(id: item.template.id)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Start with one")
        }
    }
    
    private func checkICloudSyncStatus() async {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moosa.momentum.ios") else {
            withAnimation { iCloudSyncStatus = .error("iCloud sync not configured") }
            return
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            withAnimation { iCloudSyncStatus = .syncing }
            return
        }
        
        do {
            _ = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            withAnimation { iCloudSyncStatus = .enabled }
        } catch {
            withAnimation { iCloudSyncStatus = .error("Failed to access sync storage") }
        }
    }
    
    private func openEditorWithTemplate(id templateID: String) {
        let suggestionsData = GoalSuggestionsLoader.shared.loadSuggestions()
        for (categoryIndex, category) in suggestionsData.categories.enumerated() {
            if let template = category.suggestions.first(where: { $0.id == templateID }) {
                let vm = GoalEditorViewModel()
                vm.selectedTemplate = template
                vm.userInput = template.title
                vm.durationInMinutes = template.duration
                vm.selectedCategoryIndex = categoryIndex
                goalEditorViewModel = vm
                navigation.showingGoalEditor = true
                return
            }
        }
        // Fallback: open blank editor
        navigation.showingGoalEditor = true
    }
    
    @ViewBuilder
    private func contextualSectionView(section: ContextualSection) -> some View {
        if case .recommendedNow = section.type {
            // Recommended Now section with TOP PICKS header
            Section {
            } header: {
                HStack {
                    Text("This Moment")
                        .font(.subheadline.weight(.bold))
                        .tracking(1)
                    Spacer()
                }
            }
            .id(section.id)
            .listSectionSpacing(.compact)
            .onAppear { trackSectionAppeared(section) }
            .onDisappear { trackSectionDisappeared(section) }
            
            // Individual featured cards
            ForEach(Array(section.sessions.enumerated()), id: \.element.id) { index, session in
                Section {
                    RecommendedSessionRowView(
                        session: session,
                        day: day,
                        index: index + 1,
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
        let isCompletedSection = section.type == .completed
        
        return Section {
            ForEach(section.sessions) { session in
                sessionRow(for: session, isCompleted: isCompletedSection)
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let icon = section.type.icon {
                        Image(systemName: icon)
                            .foregroundStyle(section.type.iconColor)
                    }
                    Text(section.type.title)
                        .font(.headline)
                    Spacer()
                }
                
                if let explanation = section.explanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("\(section.type.title), \(section.sessions.count) sessions")
        }
        .id(section.id)
        .listSectionSpacing(.compact)
        .onAppear { trackSectionAppeared(section) }
        .onDisappear { trackSectionDisappeared(section) }
    }
    
    // MARK: - Section Visibility Tracking
    
    private func trackSectionAppeared(_ section: ContextualSection) {
        visibleSectionIDs.insert(section.id)
        updateVisibleSectionType()
    }
    
    private func trackSectionDisappeared(_ section: ContextualSection) {
        visibleSectionIDs.remove(section.id)
        updateVisibleSectionType()
    }
    
    /// Pick the topmost visible section by matching against the ordered contextualSections list
    private func updateVisibleSectionType() {
        let sections = contextualSections
        if let first = sections.first(where: { visibleSectionIDs.contains($0.id) }) {
            navigation.visibleSectionType = first.type
        }
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
            selectedWeather: $planningViewModel.selectedWeather,
            allThemes: planningViewModel.cachedThemes,
            sessions: focusFilteredSessions,
            currentWeather: weatherManager.getCurrentCondition(),
            nextEvent: nextCalendarEvent,
            calendarFreeMinutes: nil,
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
            healthKitManager: healthKitManager,
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
        var seenTitles: Set<String> = []
        
        for goal in activeGoals {
            guard let primaryTag = goal.primaryTag else { continue }
            let key = primaryTag.title.lowercased()
            if !seenTitles.contains(key) {
                uniqueThemes.append(primaryTag)
                seenTitles.insert(key)
            }
        }
        
        return uniqueThemes
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
    
    /// All contextual sections for the current session list
    var contextualSections: [ContextualSection] {
        let recommendedSessions = getRecommendedSessions()
        let filterResult = SessionFilterService.filterActiveSessionsWithDownranked(
            focusFilteredSessions,
            validationCheck: isGoalValid,
            weatherManager: weatherManager
        )
        
        return ContextualSection.groupSessions(
            filterResult.active,
            recommendedSessions: recommendedSessions,
            allGoals: focusFilteredSessions,
            downrankedSessions: filterResult.downranked
        )
    }
    
    // MARK: - Session Management (see ContentView/Handlers/SessionManagement.swift)
    
    // MARK: - Recommendations
    
    func getRecommendedSessions() -> [GoalSession] {
        return SessionFilterService.getRecommendedSessions(
            from: focusFilteredSessions,
            planner: planningViewModel.planner,
            preferences: planningViewModel.plannerPreferences,
            validationCheck: isGoalValid,
            weatherManager: weatherManager
        )
    }
    

    // MARK: - Session Row
    
    @ViewBuilder
    func sessionRow(for session: GoalSession, isCompleted: Bool = false) -> some View {
        SessionRowView(
            session: session,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: $navigation.selectedSession,
            sessionToLogManually: $navigation.sessionToLogManually,
            isCompleted: isCompleted
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
    NavigationStack {
        ContentView(day: day, viewModel: viewModel)
            .environment(store)
            .modelContainer(for: Item.self, inMemory: true)
    }
}

