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
    @State private var activeFilter: Filter = .activeToday

    
    // Timer manager for session tracking
    @State private var timerManager: SessionTimerManager?
    
    // Planning
    @State private var planningViewModel = PlanningViewModel()
    
    // Navigation state
    @State private var showPlannerSheet = false
    @State private var showAllGoals = false
    @State private var showSettings = false
    @State private var showNowPlaying = false
    @State private var sessionToLogManually: GoalSession?
    
    // HealthKit
    @State private var healthKitManager = HealthKitManager()
    @State private var healthKitObservers = [HKObserverQuery]()
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    @AppStorage("lastPlanGeneratedTimestamp") private var lastPlanGeneratedTimestamp: Double = 0
    
    var body: some View {
        mainListView
            .animation(.spring(), value: goals)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessions.count)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: getRecommendedSessions().map { $0.id })
            .overlay {
                VStack {
                    GoalFilterBar(
                        filters: availableFilters,
                        activeFilter: $activeFilter,
                        sessionCounts: sessionCountsForFilters
                    )
                    Spacer()
                }
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
            Section {
                
            } footer: {

                Spacer()
                    .frame(height: 10.0)
            }

            if !sessions.isEmpty || planningViewModel.isPlanning || planningViewModel.showPlanningComplete {
                let recommendedSessions = getRecommendedSessions()
                if !recommendedSessions.isEmpty {
                    recommendedSection(sessions: recommendedSessions)
                }
                
                if !sessions.isEmpty {
                    let recommendedSessionIDs = Set(recommendedSessions.map { $0.id })
                    let laterSessions = SessionFilterService.filter(sessions, by: activeFilter, validationCheck: isGoalValid)
                        .filter { !recommendedSessionIDs.contains($0.id) }
                    
                    if !laterSessions.isEmpty {
                        laterSection(sessions: laterSessions)
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
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    showAllGoals = true
                } label: {
                    Image(systemName: "list.bullet")
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
            
            Button {
                showAllGoals = true
            } label: {
                Image(systemName: "list.bullet")
            }
            
        }
#endif
        
    
  
        
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
        
        // Use Task to ensure proper async data loading
        Task {
            refreshGoals()
            syncHealthKitData()
            
            // Auto-plan once per day on launch if we haven't already
            await checkAndRunAutoPlan()
            
            // Reschedule notifications for all goals with notifications enabled
            await rescheduleGoalNotifications()
        }
    }
    
    /// Reschedule notifications for all goals with schedule notifications enabled
    @MainActor
    private func rescheduleGoalNotifications() async {
        let notificationManager = GoalNotificationManager()
        
        // Get all active goals with schedule notifications enabled
        let notificationGoals = goals.filter { $0.scheduleNotificationsEnabled && $0.hasSchedule && $0.status == .active }
        
        guard !notificationGoals.isEmpty else {
            print("⏭️ No goals with notifications enabled")
            return
        }
        
        print("📅 Rescheduling notifications for \(notificationGoals.count) goals...")
        
        do {
            try await notificationManager.rescheduleAllGoals(goals: notificationGoals)
        } catch {
            print("❌ Failed to reschedule notifications: \(error)")
        }
    }
    
    /// Check if we should auto-plan and run it if needed
    private func checkAndRunAutoPlan() async {
        print("🔍 Auto-plan check: hasAutoPlannedToday=\(planningViewModel.hasAutoPlannedToday), goals.count=\(goals.count)")
        
        // Skip if we've already auto-planned in this session (prevents duplicate runs)
        guard !planningViewModel.hasAutoPlannedToday else {
            print("⏭️ Skipping: already planned in this session")
            return
        }
        
        // Mark as started immediately to prevent concurrent runs
        planningViewModel.hasAutoPlannedToday = true
        
        // Skip if there are no goals
        guard !goals.isEmpty else {
            print("⏭️ Skipping: no goals available")
            planningViewModel.hasAutoPlannedToday = false // Reset so it can try again if goals are added
            return
        }
        
        // Check if less than 1 hour has passed since last plan generation
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastPlan = currentTime - lastPlanGeneratedTimestamp
        let oneHourInSeconds: Double = 3600
        
        if lastPlanGeneratedTimestamp > 0 && timeSinceLastPlan < oneHourInSeconds {
            let remainingMinutes = Int((oneHourInSeconds - timeSinceLastPlan) / 60)
            print("⏭️ Skipping: Plan generated \(Int(timeSinceLastPlan / 60)) minutes ago. Will regenerate in \(remainingMinutes) minutes")
            planningViewModel.hasAutoPlannedToday = false // Reset so it can try again later
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
    
    private var availableFilters: [Filter] {
        SessionFilterService.buildAvailableFilters(from: availableGoalThemes, sessions: sessions)
    }
    
    private var sessionCountsForFilters: [Filter: Int] {
        var counts: [Filter: Int] = [:]
        for filter in availableFilters {
            counts[filter] = SessionFilterService.count(sessions, for: filter)
        }
        return counts
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
        return SessionFilterService.getRecommendedSessions(
            from: sessions,
            filter: activeFilter,
            planner: planningViewModel.planner,
            preferences: planningViewModel.plannerPreferences,
            validationCheck: isGoalValid
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
            onSkip: skip
        )
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
                print("📝 Updated plan generation timestamp")
            }
        }
        
        do {
            // Generate the plan using active goals
            var activeGoals = goals.filter { $0.status == .active }
            
            // Filter by selected themes if any are selected
            if !planningViewModel.selectedThemes.isEmpty {
                activeGoals = activeGoals.filter { goal in
                    planningViewModel.selectedThemes.contains(goal.primaryTag.themeID)
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
            
            // Don't remove all sessions - we want to keep sessions for goals not in the plan
            // The applyPlan function will create/update sessions as needed
            
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
                    print("🚫 Planning cancelled by user")
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
            
            // Ensure all active goals have sessions (even if not in the plan)
            await MainActor.run {
                let allActiveGoals = goals.filter { $0.status == .active }
                let existingSessionGoalIDs = Set(sessions.map { $0.goal.id })
                
                for goal in allActiveGoals {
                    if !existingSessionGoalIDs.contains(goal.id) {
                        // Create session for goal not in the plan
                        let session = GoalSession(title: goal.title, goal: goal, day: day)
                        session.status = .active
                        modelContext.insert(session)
                    }
                }
                
                try? modelContext.save()
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
        if planningViewModel.selectedThemes.contains(goal.primaryTag.themeID) {
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
}

#Preview {
    let store = GoalStore()
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .environment(store)
        .modelContainer(for: Item.self, inMemory: true)
}

