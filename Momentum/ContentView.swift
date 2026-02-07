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

struct ContentView: View {
    @Environment(GoalStore.self) var goalStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query private var sessions: [GoalSession]
    let day: Day
    @State private var selectedSession: GoalSession?
    @Namespace var animation
    @State private var showingGoalEditor = false
    @State private var availableFilters: [Filter] = [.activeToday, .allGoals, .skippedSessions, .archivedGoals]
    @State private var activeFilter: Filter = .activeToday
    
    private var dynamicAvailableFilters: [Filter] {
        var filters = availableFilters
        
        // Add "Planned" filter if there are any planned sessions
        let hasPlannedSessions = sessions.contains(where: { $0.plannedStartTime != nil })
        if hasPlannedSessions && !filters.contains(.planned) {
            // Insert planned filter after activeToday
            if let index = filters.firstIndex(of: .activeToday) {
                filters.insert(.planned, at: index + 1)
            } else {
                filters.insert(.planned, at: 0)
            }
        }
        
        return filters
    }
    
    // Timer manager for session tracking
    @State private var timerManager: SessionTimerManager?
    
    @State private var now = Date()
    @State private var showPlanner = false
    @State private var showPlannerSheet = false
    @State private var selectedThemes: Set<String> = []
    @State private var availableTimeMinutes: Int = 120
    @State private var showAllGoals = false
    @State private var showSettings = false
    @State private var healthKitManager = HealthKitManager()
    @State private var healthKitObservers = [HKObserverQuery]()
    @State private var planner = GoalSessionPlanner()
    @State private var plannerPreferences = PlannerPreferences.default
    @State private var isPlanning = false
    @State private var revealedSessionIDs: Set<UUID> = []
    @State private var showNowPlaying = false
    @State private var sessionToLogManually: GoalSession?
    @State private var cachedThemes: [GoalTag] = []
    @State private var hasAutoPlannedToday = false
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    
    var body: some View {
        mainListView
            .animation(.spring(), value: goals)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessions.count)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: getRecommendedSessions().map { $0.id })
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(dynamicAvailableFilters, id: \.self) { filter in
                                filterChip(for: filter)
                            }
                        }
                        .padding([.leading, .trailing])
                        .padding([.top, .bottom], 8)
                    }
                    .background(.ultraThinMaterial)
                    
                    Divider()
                }
            }
            .toolbar {
                toolbarContent
            }
            .onAppear {
                setupOnAppear()
            }
            .onDisappear {
                timerManager?.activeSession?.stopUITimer()
            }
            .onChange(of: goals) { old, new in
                handleGoalsChange(old: old, new: new)
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
            .sheet(item: $sessionToLogManually) { session in
                manualLogSheet(for: session)
            }
    }
    
    // MARK: - Main List View
    
    private var mainListView: some View {
        List {
            if isPlanning && sessions.isEmpty {
                planningLoadingSection
            }
            
            if !sessions.isEmpty {
                let recommendedSessions = getRecommendedSessions()
                if !recommendedSessions.isEmpty {
                    recommendedSection(sessions: recommendedSessions)
                }
                
                let recommendedSessionIDs = Set(recommendedSessions.map { $0.id })
                let laterSessions = filter(sessions: sessions, with: activeFilter)
                    .filter { !recommendedSessionIDs.contains($0.id) }
                
                if !laterSessions.isEmpty {
                    laterSection(sessions: laterSessions)
                }
            }
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
    }
    
    private var planningLoadingSection: some View {
        Section {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                
                Text("Generating your plan...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Analyzing your goals and creating an optimized schedule")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
        }
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
                    onSkip: skip
                )
            }
            .listSectionSpacing(.compact)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .opacity
            ))
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
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                
                Button {
                    showAllGoals = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                
                EditButton()
            }
        }
        
        #if DEBUG
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                ForEach(DebugGoals.allCases) { debugGoal in
                    Button {
                        addDebugGoal(debugGoal)
                    } label: {
                        Label(debugGoal.title, systemImage: "plus.circle")
                    }
                }
            } label: {
                Image(systemName: "hammer.fill")
            }
        }
        #endif
#endif
        
    
  
        
        ToolbarItem(placement: .bottomBar) {
            Button {
                // Cache themes before showing sheet to avoid SwiftData faults
                cachedThemes = availableGoalThemes
                showPlannerSheet = true
            } label: {
                if isPlanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Plan Day", systemImage: "sparkles")
                }
            }
            .disabled(isPlanning)
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
                .frame(minWidth: 180.0)
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
            let manager = SessionTimerManager(goalStore: goalStore)
            
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
        
        // Use Task to ensure proper async data loading
        Task {
            refreshGoals()
            syncHealthKitData()
            
            // Auto-plan once per day on launch if we haven't already
            await checkAndRunAutoPlan()
        }
    }
    
    /// Check if we should auto-plan and run it if needed
    private func checkAndRunAutoPlan() async {
        print("🔍 Auto-plan check: hasAutoPlannedToday=\(hasAutoPlannedToday), goals.count=\(goals.count)")
        
        // Skip if we've already auto-planned in this session (prevents duplicate runs)
        guard !hasAutoPlannedToday else {
            print("⏭️ Skipping: already planned in this session")
            return
        }
        
        // Mark as started immediately to prevent concurrent runs
        hasAutoPlannedToday = true
        
        // Skip if there are no goals
        guard !goals.isEmpty else {
            print("⏭️ Skipping: no goals available")
            hasAutoPlannedToday = false // Reset so it can try again if goals are added
            return
        }
        
        print("✅ Starting auto-plan...")
        
        
        await generateDailyPlan()
    }
    
    /// Update recommendation reasons for existing planned sessions
    private func updateExistingSessionReasons() async {
        await MainActor.run {
            for session in sessions where session.plannedStartTime != nil {
                let reasons = calculateRecommendationReasons(for: session, goal: session.goal)
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
                        print("HealthKit authorization failed for new goals: \(error)")
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
            selectedThemes: $selectedThemes,
            availableTimeMinutes: $availableTimeMinutes,
            allThemes: cachedThemes,
            animation: animation
        ) {
            showPlannerSheet = false
            Task {
                await generateDailyPlan()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.thinMaterial)
        .onAppear {
            // Cache themes when sheet appears to avoid SwiftData faults
            cachedThemes = availableGoalThemes
            
            // Prewarm the model to reduce initial planning delay
            Task {
                await planner.prewarm()
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
                    activeSessionDetails: activeSession
                ) {
                    timerManager.toggleTimer(for: session, in: day)
                }
            }
        }
    }
    
    private var settingsSheet: some View {
        SettingsView()
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
            let themeID = goal.primaryTag.themeID
            if !seenIDs.contains(themeID) {
                uniqueThemes.append(goal.primaryTag)
                seenIDs.insert(themeID)
            }
        }
        
        return uniqueThemes
    }
    
    private func count(for filter: Filter) -> Int {
        switch filter {
        case .skippedSessions:
            return sessions.filter { $0.status == .skipped }.count
        case .archivedGoals:
            // Count archived goals that have a session for this day
            let archivedGoalIDs = Set(goals.filter { $0.status == .archived }.map { $0.id })
            return sessions.filter { archivedGoalIDs.contains($0.goal.id) }.count
        case .activeToday:
            return sessions.filter { $0.goal.status != .archived && $0.status != .skipped }.count
        case .allGoals:
            return sessions.count
        case .recommendedGoals:
            // Currently same criteria as active non-skipped/non-archived
            return sessions.filter { $0.goal.status != .archived && $0.status != .skipped }.count
        case .planned:
            return sessions.filter { $0.plannedStartTime != nil && $0.goal.status != .archived && $0.status != .skipped }.count
        case .theme(let goalTheme):
            return sessions.filter { $0.goal.primaryTag.themeID == goalTheme.themeID && $0.goal.status != .archived && $0.status != .skipped }.count
        }
    }
    
    
    private func filterChip(for filter: Filter) -> some View {
        HStack(spacing: 4) {
            if let image = filter.label.imageName {
                Image(systemName: image)
            }
            if let text = filter.label.text {
                filterText(for: filter, text: text)
            }
        }
        .foregroundStyle(filter.id == activeFilter.id ? filter.tintColor : .primary)
        .fontWeight(.semibold)
        .padding([.top, .bottom], 6)
        .padding([.leading, .trailing], 10)
        .frame(minWidth: 60.0)
        .background {
            Capsule()
                .fill(filter.id == activeFilter.id ? filter.tintColor.opacity(0.4) : Color(.systemGray5))
        }
        .onTapGesture {
            withAnimation {
                activeFilter = filter
            }
        }
    }
    
    @ViewBuilder
    private func filterText(for filter: Filter, text: String) -> some View {
        if filter == .skippedSessions || filter == .archivedGoals || filter == .planned {
            let count = count(for: filter)
            HStack {
                Text(text)
                    .font(.footnote)
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }
        } else {
            Text(text)
                .font(.footnote)
        }
    }
    
    init(day: Day) {
        self.day = day
        let dayID = day.id
        
        self._sessions = Query(
                    filter: #Predicate<GoalSession> { event in
                        event.day.id == dayID
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
            }
        }
        
        // Save changes if there were any insertions or deletions
        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }
    
    func skip(session: GoalSession) {
        withAnimation {
            session.status = session.status == .skipped ? .active : .skipped
        }
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
            _ = session.goal.id
            _ = session.goal.title
            _ = session.goal.status
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Recommendations
    
    /// Get recommended sessions for right now (top 3)
    private func getRecommendedSessions() -> [GoalSession] {
        // Filter out deleted/invalid sessions first
        let validSessions = sessions.filter { (try? $0.persistentModelID) != nil }
        let filtered = filter(sessions: validSessions, with: activeFilter)
        
        // During planning or if we have planned sessions, show top 3 with planning details as recommended
        let plannedSessions = filtered
            .filter { $0.plannedStartTime != nil && !$0.recommendationReasons.isEmpty }
            .sorted { ($0.plannedStartTime ?? Date.distantFuture) < ($1.plannedStartTime ?? Date.distantFuture) }
        
        if !plannedSessions.isEmpty {
            return Array(plannedSessions.prefix(3))
        }
        
        // Fallback: try to get AI-generated recommendations from the daily plan
        if let aiRecommendations = planner.getRecommendedSessionsFromPlan(allSessions: filtered),
           !aiRecommendations.isEmpty {
            // Use AI recommendations - filter to only show ones with recommendation reasons
            let recommendationsWithReasons = aiRecommendations.filter { !$0.recommendationReasons.isEmpty }
            
            if !recommendationsWithReasons.isEmpty {
                return Array(recommendationsWithReasons.prefix(3))
            }
        }
        
        // Only show fallback recommendations if we have enough sessions
        guard sessions.count > 4 else {
            return []
        }
        
        // Fallback: Use scoring algorithm (soft refresh)
        let scored = filtered.compactMap { session -> (GoalSession, Double)? in
            guard isGoalValid(session) else { return nil }
            
            let score = planner.scoreSession(
                for: session.goal,
                session: session,
                at: Date(),
                preferences: plannerPreferences
            )
            return (session, score)
        }
        
        // Sort by score and take top 3
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }
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
            onSkip: skip
        )
    }
    
    private func filter(sessions: [GoalSession], with filter: Filter?) -> [GoalSession] {
        guard let filter else {
            return sessions.filter { session in
                // Check if not deleted first
                guard (try? session.persistentModelID) != nil else { return false }
                return isGoalValid(session)
            }
        }
        
        let filtered = sessions.filter { session in
            // Check if not deleted first, before accessing any properties
            guard (try? session.persistentModelID) != nil else {
                return false
            }
            
            // Filter out sessions with deleted goals
            guard isGoalValid(session) else {
                return false
            }
            
            // Safely access status properties that might be faults
            let isArchived: Bool
            let isSkipped: Bool
            
            do {
                isArchived = session.goal.status == .archived
                isSkipped = session.status == .skipped
            } catch {
                // If we can't access the status, assume it's not valid
                return false
            }
            
            switch activeFilter {
            case .activeToday:
                return !isArchived && !isSkipped
            case .recommendedGoals:
                return !isArchived && !isSkipped
            case .allGoals:
                return true
            case .archivedGoals:
                return isArchived
            case .skippedSessions:
                return isSkipped
            case .planned:
                return session.plannedStartTime != nil && !isArchived && !isSkipped
            case .theme(let goalTheme):
                return session.goal.primaryTag.themeID == goalTheme.themeID && !isArchived && !isSkipped
            }
        }
        
        // Sort by planned start time if available, otherwise by goal title
        return filtered.sorted { session1, session2 in
            // First, prioritize sessions with planned times
            let has1 = session1.plannedStartTime != nil
            let has2 = session2.plannedStartTime != nil
            
            if has1 && has2 {
                // Both have planned times - sort by time
                return session1.plannedStartTime! < session2.plannedStartTime!
            } else if has1 {
                // Only session1 has a planned time - it comes first
                return true
            } else if has2 {
                // Only session2 has a planned time - it comes first
                return false
            } else {
                // Neither has a planned time - sort by goal title
                return session1.goal.title < session2.goal.title
            }
        }
    }
    func handle(event: ActionView.Event) {
        guard let timerManager else { return }
        switch event {
        case .stopTapped:
            if let session = sessions.first(where: { $0.id == timerManager.activeSession?.id }) {
                timerManager.toggleTimer(for: session, in: day)
            }
        }
    }
    
    func timerText(for session: GoalSession) -> String {
        return timerManager?.timerText(for: session) ?? "TODO..."
    }
    
    // MARK: - HealthKit Integration
    
    private func syncHealthKitData() {
        guard healthKitManager.isHealthKitAvailable else { return }
        
        // Get all goals with HealthKit sync enabled
        let healthKitGoals = goals.filter { $0.healthKitSyncEnabled && $0.healthKitMetric != nil }
        
        // Request authorization if needed
        let metrics = healthKitGoals.compactMap { $0.healthKitMetric }
        guard !metrics.isEmpty else { return }
        
        Task {
            // Request authorization first (this will be a no-op if already authorized)
            do {
                try await healthKitManager.requestAuthorization(for: metrics)
            } catch {
                print("HealthKit authorization failed: \(error)")
                return
            }
            
            // Fetch data for each goal
            for goal in healthKitGoals {
                guard let metric = goal.healthKitMetric else { continue }
                
                do {
                    // Fetch individual samples (for history display)
                    let samples = try await healthKitManager.fetchSamples(
                        for: metric,
                        from: day.startDate,
                        to: day.endDate
                    )
                    
                    // Merge samples to avoid double-counting
                    let mergedSamples = mergeSamples(samples)
                    
                    // Calculate total duration from merged samples
                    let duration = mergedSamples.reduce(0.0) { $0 + $1.duration }
                    
                    // Update the corresponding session
                    await MainActor.run {
                        if let session = sessions.first(where: { $0.goal.id == goal.id }) {
                            session.updateHealthKitTime(duration)
                            
                            // Create or update historical sessions from HealthKit samples
                            syncHistoricalSessions(from: mergedSamples, for: goal, in: session)
                        }
                    }
                } catch {
                    print("Failed to fetch HealthKit data for \(goal.title): \(error)")
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
            day.historicalSessions
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
        let sessionsToRemove = day.historicalSessions.filter { session in
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
                print("Failed to start observer for \(metric.displayName): \(error)")
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
            isPlanning = true
            // Clear previous revealed sessions
            revealedSessionIDs.removeAll()
        }
        defer { 
            Task { @MainActor in
                isPlanning = false
            }
        }
        
        do {
            // Generate the plan using active goals
            var activeGoals = goals.filter { $0.status == .active }
            
            // Filter by selected themes if any are selected
            if !selectedThemes.isEmpty {
                activeGoals = activeGoals.filter { goal in
                    selectedThemes.contains(goal.primaryTag.themeID)
                }
            }
            
            // Set max sessions in planner preferences
            var preferences = plannerPreferences
            if !unlimitedPlannedSessions {
                preferences.maxSessionsPerDay = maxPlannedSessions
            } else {
                preferences.maxSessionsPerDay = 100 // Effectively unlimited
            }
            
            // Apply time-based limit (assuming ~30 minutes per session on average)
            let timeBasedMaxSessions = availableTimeMinutes / 30
            preferences.maxSessionsPerDay = min(
                preferences.maxSessionsPerDay,
                max(1, timeBasedMaxSessions)
            )
            
            self.day.removeAllSessions()
            
            // Use streaming to get real-time updates
            let stream = planner.streamDailyPlan(
                for: activeGoals,
                goalSessions: sessions,
                currentDate: day.startDate,
                userPreferences: preferences
            )
            
            var latestPlan: DailyPlan?
            
            for try await partialPlan in stream {
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
                    
                    // Only update if we have at least one fully generated session
                    if !fullyGeneratedSessions.isEmpty {
                        let plan = DailyPlan(
                            sessions: fullyGeneratedSessions,
                            overallStrategy: partialPlan.overallStrategy ?? nil
                        )
                        latestPlan = plan
                        
                        // Apply the partial plan as it streams in
                        await applyPlan(plan)
                    }
                }
            }
            
            // Use the final plan for animation or direct application
            if let plan = latestPlan {
                await animatePlannedSessions(plan)

                
                // Clear planning details for sessions NOT in the plan
                await MainActor.run {
                    let plannedGoalIDs = Set(plan.sessions.compactMap { UUID(uuidString: $0.id) })
                    for session in sessions where !plannedGoalIDs.contains(session.goal.id) {
                        session.clearPlanningDetails()
                    }
                    try? modelContext.save()
                }
            }
            
        } catch {
            print("Planning failed: \(error)")
            
            // Show error alert
            #if os(iOS)
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            #endif
        }
    }
    
    /// Animate the reveal of planned sessions one by one
    private func animatePlannedSessions(_ plan: DailyPlan) async {
        
        // Animated reveal (faster than before)
        await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
                activeFilter = .activeToday  // Show all active sessions including recommendations
            }
        }
                
        // Reveal each session one by one
        for (index, plannedSession) in plan.sessions.enumerated() {
            guard let goalID = UUID(uuidString: plannedSession.id),
                  let session = sessions.first(where: { $0.goal.id == goalID }) else {
                continue
            }
            
            // Add session to revealed set with animation
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    revealedSessionIDs.insert(session.id)
                }
                
                // Haptic feedback for each reveal (only for first 3 to avoid overload)
                #if os(iOS)
                if index < 3 {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
                #endif
            }
            
            // Much faster delays - start at 200ms, decrease by 40ms each time, min 50ms
            let delay = max(50, 200 - (index * 40))
            try? await Task.sleep(for: .milliseconds(delay))
        }
        
        // Reduced final wait before clearing shimmer
        try? await Task.sleep(for: .milliseconds(300))
        
        await MainActor.run {
            // Mark all as revealed to remove shimmer effects
            for plannedSession in plan.sessions {
                if let goalID = UUID(uuidString: plannedSession.id),
                   let session = sessions.first(where: { $0.goal.id == goalID }) {
                    revealedSessionIDs.insert(session.id)
                }
            }
        }
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
        if selectedThemes.contains(goal.primaryTag.themeID) {
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
            let existingSessionGoalIDs = Set(sessions.map { $0.goal.id })
            
            // Create new GoalSession objects for each planned session
            for plannedSession in plan.sessions {
                // Try to find the goal by UUID first
                var goal: Goal?
                let goalIDs = goals.map { $0.id }
                if let goalID = UUID(uuidString: plannedSession.id) {
                    // UUID parsing succeeded - find by ID
                    for id in goalIDs {
                        if id.uuidString == plannedSession.id {
                            print("§ maaaatch")
                        }
                        print("§\(id)")
                    }
                    goal = goals.first(where: { $0.id == goalID })
                }
                
                
                // Fallback: if UUID parsing failed or goal not found, try matching by title
                if goal == nil {
                    goal = goals.first(where: { $0.title == plannedSession.goalTitle })
                }
                
                guard let matchedGoal = goal else {
                    print("⚠️ Could not find goal for planned session: \(plannedSession.goalTitle) (ID: \(plannedSession.id))")
                    continue
                }
                
                // Check if a session already exists for this goal
                if let existingSession = sessions.first(where: { $0.goal.id == matchedGoal.id }) {
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
                }
            }
            
            // Save the new/updated sessions
            try? modelContext.save()
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    private func addDebugGoal(_ debugGoal: DebugGoals) {
        let theme = GoalTag(title: debugGoal.themeTitle, color: debugGoal.theme)
        let goal = Goal(
            title: debugGoal.title,
            primaryTag: theme,
            weeklyTarget: TimeInterval(debugGoal.weeklyTargetMinutes * 60),
            notificationsEnabled: debugGoal.notificationsEnabled,
            healthKitMetric: debugGoal.healthKitMetric,
            healthKitSyncEnabled: debugGoal.healthKitSyncEnabled
        )
        withAnimation {
            modelContext.insert(goal)
        }
    }
    #endif
}

// MARK: - Debug Goals

#if DEBUG
enum DebugGoals: String, CaseIterable, Identifiable {
    case reading = "Reading"
    case exercise = "Exercise"
    case meditation = "Meditation"
    case coding = "Coding Practice"
    case music = "Music Practice"
    case cooking = "Cooking"
    case learning = "Language Learning"
    case writing = "Writing"
    
    var id: String { rawValue }
    
    var title: String {
        rawValue
    }
    
    var themeTitle: String {
        switch self {
        case .reading: return "Learning"
        case .exercise: return "Health"
        case .meditation: return "Wellness"
        case .coding: return "Tech"
        case .music: return "Creative"
        case .cooking: return "Home"
        case .learning: return "Education"
        case .writing: return "Creative"
        }
    }
    
    var theme: Theme {
        switch self {
        case .reading: return themePresets.first(where: { $0.id == "blue" })!.toTheme()
        case .exercise: return themePresets.first(where: { $0.id == "red" })!.toTheme()
        case .meditation: return themePresets.first(where: { $0.id == "purple" })!.toTheme()
        case .coding: return themePresets.first(where: { $0.id == "green" })!.toTheme()
        case .music: return themePresets.first(where: { $0.id == "orange" })!.toTheme()
        case .cooking: return themePresets.first(where: { $0.id == "yellow" })!.toTheme()
        case .learning: return themePresets.first(where: { $0.id == "purple" })!.toTheme()
        case .writing: return themePresets.first(where: { $0.id == "teal" })!.toTheme()
        }
    }
    
    var weeklyTargetMinutes: Int {
        switch self {
        case .reading: return 210 // 30 min/day
        case .exercise: return 175 // 25 min/day
        case .meditation: return 70 // 10 min/day
        case .coding: return 420 // 60 min/day
        case .music: return 140 // 20 min/day
        case .cooking: return 105 // 15 min/day
        case .learning: return 210 // 30 min/day
        case .writing: return 140 // 20 min/day
        }
    }
    
    var notificationsEnabled: Bool {
        switch self {
        case .meditation, .exercise, .reading:
            return true
        default:
            return false
        }
    }
    
    var healthKitMetric: HealthKitMetric? {
        switch self {
        case .exercise: return .appleExerciseTime
        case .meditation: return .mindfulMinutes
        default: return nil
        }
    }
    
    var healthKitSyncEnabled: Bool {
        return healthKitMetric != nil
    }
}
#endif

// MARK: - All Goals View

struct AllGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let goals: [Goal]
    
    @State private var goalToDelete: Goal?
    @State private var showingDeleteConfirmation = false
    
    var activeGoals: [Goal] {
        goals.filter { $0.status == .active }
    }
    
    var archivedGoals: [Goal] {
        goals.filter { $0.status == .archived }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !activeGoals.isEmpty {
                    Section("Active Goals") {
                        ForEach(activeGoals) { goal in
                            GoalRow(goal: goal)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        goalToDelete = goal
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                if !archivedGoals.isEmpty {
                    Section("Archived Goals") {
                        ForEach(archivedGoals) { goal in
                            GoalRow(goal: goal)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        goalToDelete = goal
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                if goals.isEmpty {
                    ContentUnavailableView(
                        "No Goals",
                        systemImage: "target",
                        description: Text("Create your first goal to get started")
                    )
                }
            }
            .navigationTitle("All Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete Goal",
                isPresented: $showingDeleteConfirmation,
                presenting: goalToDelete
            ) { goal in
                Button("Delete \"\(goal.title)\"", role: .destructive) {
                    deleteGoal(goal)
                }
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
            } message: { goal in
                Text("Are you sure you want to delete \"\(goal.title)\"? This action cannot be undone.")
            }
        }
    }
    
    private func deleteGoal(_ goal: Goal) {
        withAnimation {
            // First, clean up any related data
            // Delete all sessions for this goal
            for session in goal.goalSessions {
                modelContext.delete(session)
            }
            
            // Delete all checklist items
            for item in goal.checklistItems {
                modelContext.delete(item)
            }
            
            // Delete all interval lists
            for list in goal.intervalLists {
                modelContext.delete(list)
            }
            
            // Now delete the goal itself
            modelContext.delete(goal)
            
            // Save the context to ensure deletion is persisted
            try? modelContext.save()
            
            goalToDelete = nil
            
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.headline)
                
                HStack {
                    Text(goal.primaryTag.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(goal.primaryTag.themePreset.light.opacity(0.2))
                        )
                        .foregroundStyle(goal.primaryTag.themePreset.dark)
                    
                    if goal.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if goal.healthKitSyncEnabled {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(goal.weeklyTarget / 60)) min")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Text("weekly target")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Manual Log Sheet

struct ManualLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let session: GoalSession
    let day: Day
    
    @State private var startDate = Date()
    @State private var duration: TimeInterval = 1800 // Default 30 minutes
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start Time", selection: $startDate, in: day.startDate...day.endDate)
                    
                    Picker("Duration", selection: $duration) {
                        Text("5 min").tag(TimeInterval(300))
                        Text("10 min").tag(TimeInterval(600))
                        Text("15 min").tag(TimeInterval(900))
                        Text("20 min").tag(TimeInterval(1200))
                        Text("30 min").tag(TimeInterval(1800))
                        Text("45 min").tag(TimeInterval(2700))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                    }
                } header: {
                    Text("Activity Details")
                } footer: {
                    Text("Log time you spent on this goal that wasn't captured by HealthKit")
                }
                
                Section("Notes (Optional)") {
                    TextField("Add any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log \(session.goal.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveManualLog()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveManualLog() {
        // Create a historical session for this manual entry
        let endDate = startDate.addingTimeInterval(duration)
        
        let historicalSession = HistoricalSession(
            id: UUID().uuidString,
            title: "\(session.goal.title) - Manual Entry",
            start: startDate,
            end: endDate,
            healthKitType: nil, // Manual entry, not from HealthKit
            needsHealthKitRecord: false
        )
        historicalSession.goalIDs.append(session.goal.id.uuidString)
        
        if !notes.isEmpty {
            // TODO: Add notes property to HistoricalSession if needed
        }
        
        // Add to day
        day.add(historicalSession: historicalSession)
        modelContext.insert(historicalSession)
        
        // Save context
        try? modelContext.save()
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

#Preview {
    let store = GoalStore()
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .environment(store)
        .modelContainer(for: Item.self, inMemory: true)
}

