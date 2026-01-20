//
//  ContentView.swift
//  Weektime
//
//  Created by Mo Moosa on 22/07/2025.
//

import SwiftUI
import SwiftData
import WeektimeKit
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
    
    @State private var activeSession: ActiveSessionDetails?
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
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    @AppStorage("skipPlanningAnimation") private var skipPlanningAnimation: Bool = false
    // MARK: - UserDefaults Keys for Timer Persistence
    private let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
    private let activeSessionStartDateKey = "ActiveSessionStartDateV1"
    private let activeSessionIDKey = "ActiveSessionIDV1"
    
    var body: some View {
            List {
              filtersHeader
                
                if isPlanning && sessions.isEmpty {
                    // Show loading state when planning and no sessions yet
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
                
                ForEach(filter(sessions: sessions, with: activeFilter)) { session in
                    Section {
                        ZStack {
                            NavigationLink {
                                ChecklistDetailView(session: session, animation: animation)
                                    .tint(session.goal.primaryTheme.theme.dark)
                            } label: {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(session.goal.title)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                                                            
                                    }
                                    
                                    HStack {
                                        if let activeSession, activeSession.id == session.id, let timeText = activeSession.timeText {
                                            Text(timeText)
                                                .contentTransition(.numericText())
                                                .fontWeight(.semibold)
                                                .font(.footnote)
                                            
                                            if activeSession.hasMetDailyTarget {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .symbolRenderingMode(.hierarchical)
                                                    .foregroundStyle(.green)
                                                    .font(.footnote)
                                            }
                                        } else {
                                            Text(session.formattedTime)
                                                .fontWeight(.semibold)
                                                .font(.footnote)
                                            
                                            if session.hasMetDailyTarget {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .symbolRenderingMode(.hierarchical)
                                                    .foregroundStyle(.green)
                                                    .font(.footnote)
                                            }
                                        }
                                        
                                        // Show planned start time with animation
                                        Text(session.goal.primaryTheme.title)
                                            .font(.caption2)
                                            .padding(4)
                                            .background(Capsule()
                                                .fill(session.goal.primaryTheme.theme.light.opacity(0.15)))
                                        
                                        HealthKitBadge(
                                            metric: session.goal.healthKitMetric,
                                            isEnabled: session.goal.healthKitSyncEnabled
                                        )
                                        
                                        Spacer()
                                        
                                    }
                                    .opacity(0.7)
                                    
                                    // Show AI reasoning if available with animation
                                    if let reasoning = session.plannedReasoning, selectedSession == session {
                                        Text(reasoning)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 4)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    toggleTimer(for: session)
                                } label: {
                                    let image = session.id == activeSession?.id ? "stop.circle.fill" : "play.circle.fill"
                                    GaugePlayIcon(isActive: session.id == activeSession?.id, imageName: image, progress: session.progress, color: session.goal.primaryTheme.theme.light, font: .title2, gaugeScale: 0.4)
                                        .contentTransition(.symbolEffect(.replace))
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.title2)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(colorScheme == .dark ? session.goal.primaryTheme.theme.neon : session.goal.primaryTheme.theme.dark)
                            .listRowBackground(colorScheme == .dark ? session.goal.primaryTheme.theme.light.opacity(0.03) : Color(.systemBackground))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedSession = session
                                }
                            }
                            .matchedTransitionSource(id: session.id, in: animation)
                            // Add shimmer effect for newly planned sessions
                            .overlay {
                                if let _ = session.plannedStartTime, !revealedSessionIDs.contains(session.id) {
                                    ShimmerEffect()
                                        .ignoresSafeArea()
                                        .allowsHitTesting(false)
                                }
                            }

                        }
                        .swipeActions {
                            Button {
                                skip(session: session)
                            } label: {
                                Label {
                                    Text(session.status == .skipped ? "Reactivate" : "Skip")
                                } icon: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                            .tint(.orange)
                        }
                    }
                    .listSectionSpacing(.compact)
                }
            }
            .animation(.spring(), value: goals)
            .overlay(alignment: .bottom) {
                // Floating Now Playing button
                if let activeSession = activeSession,
                   let session = sessions.first(where: { $0.id == activeSession.id }) {
                    Button {
                        showNowPlaying = true
                    } label: {
                        HStack(spacing: 12) {
                            // Animated pulse indicator
                            Circle()
                                .fill(session.goal.primaryTheme.theme.neon)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle()
                                        .stroke(session.goal.primaryTheme.theme.neon, lineWidth: 2)
                                        .scaleEffect(1.5)
                                        .opacity(0.6)
                                }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.goal.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                if let timeText = activeSession.timeText {
                                    Text(timeText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 80) // Above the toolbar
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            
        .toolbar {
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
            
            if let activeSession = activeSession, let session = sessions.first(where: { $0.id == activeSession.id }) { // TODO: Combine with ActiveSessionDetails?
                ToolbarItem(placement: .bottomBar) {
                    
                    ActionView(session: session, details: activeSession) { event in
                        handle(event: event)
                    }
                    .frame(minWidth: 180.0)
                }
            }
            ToolbarSpacer(.fixed, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                // Planner button
                Button {
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
                // Plus button with overlay of active timer above it
                Button(action: { showingGoalEditor = true }) {
                    Label("Add Item", systemImage: "plus")
                }
                .overlay {
                    // Empty overlay here to ensure plus button remains tappable underneath active timers view.
                    // The actual active timers view is moved above using the ZStack.
                    Color.clear
                }
            }
            .matchedTransitionSource(
                id: "info", in: animation
            )
        }
        .onAppear {
            // Load saved timer states from UserDefaults
            loadTimerState()
            
            refreshGoals()
            syncHealthKitData()
            
            if activeSession?.id != nil {
                activeSession?.startUITimer()
            }
        }
        .onChange(of: goals) { old, new in
            refreshGoals()
            syncHealthKitData()
        }
        .onDisappear {
            activeSession?.stopUITimer()
        }
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh UI timer update on foreground
            if activeSession?.id != nil {
                activeSession?.startUITimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Stop UI timer updates on background
            activeSession?.stopUITimer()
        }
#endif
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorView()
                .navigationTransition(
                    .zoom(sourceID: "info", in: animation)
                )
        }
        .sheet(isPresented: $showAllGoals) {
            AllGoalsView(goals: goals)
        }
        .sheet(isPresented: $showPlannerSheet) {
            PlannerConfigurationSheet(
                selectedThemes: $selectedThemes,
                availableTimeMinutes: $availableTimeMinutes,
                allThemes: availableGoalThemes,
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
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            if let activeSession = activeSession,
               let session = sessions.first(where: { $0.id == activeSession.id }) {
                NowPlayingView(
                    session: session,
                    activeSessionDetails: activeSession
                ) {
                    toggleTimer(for: session)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var availableGoalThemes: [GoalTheme] {
        let activeGoals = goals.filter { $0.status == .active }
        var uniqueThemes: [GoalTheme] = []
        var seenIDs: Set<String> = []
        
        for goal in activeGoals {
            let themeID = goal.primaryTheme.theme.id
            if !seenIDs.contains(themeID) {
                uniqueThemes.append(goal.primaryTheme)
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
            return sessions.filter { $0.goal.primaryTheme.theme.id == goalTheme.id && $0.goal.status != .archived && $0.status != .skipped }.count
        }
    }
    
    var filtersHeader: some View {
            Section {
                
            } header: {
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(dynamicAvailableFilters, id: \.self) { filter in
                            HStack(spacing: 4) {
                                if let image = filter.label.imageName {
                                    Image(systemName: image)
                                }
                                if let text = filter.label.text {
                                    if filter == .skippedSessions || filter == .archivedGoals || filter == .planned {
                                        let count = count(for: filter)
                                        HStack {
                                            Text(text)
                                                .font(.footnote)
                                            Text("\(count)")
                                                .foregroundStyle(Color(.systemBackground))
                                                .font(.caption2)
                                                .padding(4)
                                                .background {
                                                    if count > 9 {
                                                        Capsule()
                                                            .fill(.primary)
                                                    } else {
                                                        Circle()
                                                            .fill(.primary)
                                                    }
                                                }
                                        }
                                        
                                    } else {
                                        Text(text)
                                            .font(.footnote)

                                    }
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
                    }
                    .padding([.leading, .trailing])

                }

            }
            .listRowInsets(EdgeInsets())
        
            .listSectionMargins(.horizontal, 0) // Space around sections. (Requires iOS 26)
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
        for goal in goals {
            if !sessions.contains(where: { $0.goal == goal }) {
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                modelContext.insert(session)
            }
        }
    }
    
    private func addItem() {
        let newItem = GoalTheme(title: "Health", color: themes.randomElement()! ) // TOOD:
        let goal = Goal(title: "New goal", primaryTheme: newItem)
        withAnimation {
            modelContext.insert(goal)
        }
    }
    
    
    func skip(session: GoalSession) {
        withAnimation {
            session.status = session.status == .skipped ? .active : .skipped
        }
    }
    
    private func filter(sessions: [GoalSession], with filter: Filter?) -> [GoalSession] {
        guard let filter else {
            return sessions
        }
        
        let filtered = sessions.filter { session in
            let isArchived = session.goal.status == .archived
            let isSkipped = session.status == .skipped
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
                return session.goal.primaryTheme.theme.id == goalTheme.id && !isArchived && !isSkipped
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
        switch event {
        case .stopTapped:
            if let session = sessions.first(where: { $0.id == activeSession?.id }) {
                toggleTimer(for: session)
            }
        }
    }
    
    func timerText(for session: GoalSession) -> String {
        if let activeSession, activeSession.id == session.id {
            return activeSession.timerText()
        } else {
            return "TODO..." // TODO:
        }
    }
    
    private func toggleTimer(for session: GoalSession) {
        if let activeSession, activeSession.id == session.id {
            // Stopping timer - use medium impact haptic
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            
            goalStore.save(session: session, in: day, startDate: activeSession.startDate, endDate: .now)
            // Stop the current active timer
            activeSession.stopUITimer()
            withAnimation {
                self.activeSession = nil
            }
            saveTimerState()
        } else {
            // Starting timer - use success notification haptic (positive & encouraging!)
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            
            withAnimation {
                activeSession = ActiveSessionDetails(id: session.id, startDate: .now, elapsedTime: session.elapsedTime, dailyTarget: session.dailyTarget)
                saveTimerState()
                activeSession?.startUITimer()
            }
        }
    }
        
    // MARK: - Persistence Helpers
    
    private func saveTimerState() {
        if let activeSession {
            UserDefaults.standard.set(activeSession.id.uuidString, forKey: activeSessionIDKey)
            UserDefaults.standard.set(activeSession.startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
            UserDefaults.standard.set(activeSession.elapsedTime, forKey: activeSessionElapsedTimeKey)

        } else {
            UserDefaults.standard.removeObject(forKey: activeSessionStartDateKey)
            UserDefaults.standard.removeObject(forKey: activeSessionIDKey)
        }
 
    }
    
    private func loadTimerState() {
        if let idString = UserDefaults.standard.string(forKey: activeSessionIDKey), let uuid = UUID(uuidString: idString) {
            let timeInterval = UserDefaults.standard.double(forKey: activeSessionStartDateKey)
            let elapsed = UserDefaults.standard.double(forKey: activeSessionElapsedTimeKey)
            
            // Find the session to get the daily target
            let session = sessions.first(where: { $0.id == uuid })
            let dailyTarget = session?.dailyTarget
            
            activeSession = ActiveSessionDetails(id: uuid, startDate: Date(timeIntervalSince1970: timeInterval), elapsedTime: elapsed, dailyTarget: dailyTarget)
        } else {
            activeSession = nil
        }
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
    
    /// Generate a daily plan and create GoalSession objects
    private func generateDailyPlan() async {
        isPlanning = true
        defer { isPlanning = false }
        
        // Clear previous revealed sessions
        revealedSessionIDs.removeAll()
        
        // Delete all existing GoalSession objects for this day
        await MainActor.run {
            for session in sessions {
                modelContext.delete(session)
            }
            // Save the deletion
            try? modelContext.save()
        }
        
        // Provide haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        do {
            // Generate the plan using active goals
            var activeGoals = goals.filter { $0.status == .active }
            
            // Filter by selected themes if any are selected
            if !selectedThemes.isEmpty {
                activeGoals = activeGoals.filter { goal in
                    selectedThemes.contains(goal.primaryTheme.theme.id)
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
            
            // Use the final plan for animation
            if let plan = latestPlan {
                // Animate the reveal of planned sessions
                await animatePlannedSessions(plan)
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
        // Check if animation should be skipped
        if skipPlanningAnimation {
            // Instant reveal - no animation
            await MainActor.run {
                withAnimation(.spring(response: 0.2)) {
                    activeFilter = .planned
                }
                
                // Mark all as revealed immediately
                for plannedSession in plan.sessions {
                    if let goalID = UUID(uuidString: plannedSession.id),
                       let session = sessions.first(where: { $0.goal.id == goalID }) {
                        revealedSessionIDs.insert(session.id)
                    }
                }
                
                // Single haptic for completion
                #if os(iOS)
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
                #endif
            }
            return
        }
        
        // Animated reveal (faster than before)
        await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
                activeFilter = .planned
            }
        }
        
        // Reduced delay - faster filter switch
        try? await Task.sleep(for: .milliseconds(150))
        
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
                    existingSession.updatePlanningDetails(
                        startTime: plannedSession.recommendedStartTime,
                        duration: plannedSession.suggestedDuration,
                        priority: plannedSession.priority,
                        reasoning: plannedSession.reasoning
                    )
                    existingSession.status = .active
                } else {
                    // Create a new GoalSession only if one doesn't exist
                    let session = GoalSession(title: matchedGoal.title, goal: matchedGoal, day: day)
                    
                    // Apply planning details
                    session.updatePlanningDetails(
                        startTime: plannedSession.recommendedStartTime,
                        duration: plannedSession.suggestedDuration,
                        priority: plannedSession.priority,
                        reasoning: plannedSession.reasoning
                    )
                    
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
        let theme = GoalTheme(title: debugGoal.themeTitle, color: debugGoal.theme)
        let goal = Goal(
            title: debugGoal.title,
            primaryTheme: theme,
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

// MARK: - Shimmer Effect

struct ShimmerEffect: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    Color.purple.opacity(0.3),
                    .clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .clipped()
    }
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
        case .reading: return themes.first(where: { $0.id == "blue" })!
        case .exercise: return themes.first(where: { $0.id == "red" })!
        case .meditation: return themes.first(where: { $0.id == "purple" })!
        case .coding: return themes.first(where: { $0.id == "green" })!
        case .music: return themes.first(where: { $0.id == "orange" })!
        case .cooking: return themes.first(where: { $0.id == "yellow" })!
        case .learning: return themes.first(where: { $0.id == "purple" })!
        case .writing: return themes.first(where: { $0.id == "teal" })!
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
    let goals: [Goal]
    
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
                        }
                    }
                }
                
                if !archivedGoals.isEmpty {
                    Section("Archived Goals") {
                        ForEach(archivedGoals) { goal in
                            GoalRow(goal: goal)
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
                    Text(goal.primaryTheme.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(goal.primaryTheme.theme.light.opacity(0.2))
                        )
                        .foregroundStyle(goal.primaryTheme.theme.dark)
                    
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

#Preview {
    let store = GoalStore()
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .environment(store)
        .modelContainer(for: Item.self, inMemory: true)
}

