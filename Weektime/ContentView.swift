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
    
    @State private var activeSession: ActiveSessionDetails?
    @State private var now = Date()
    @State private var healthKitManager = HealthKitManager()
    @State private var healthKitObservers = [HKObserverQuery]()
    // MARK: - UserDefaults Keys for Timer Persistence
    private let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
    private let activeSessionStartDateKey = "ActiveSessionStartDateV1"
    private let activeSessionIDKey = "ActiveSessionIDV1"
    
    var body: some View {
            List {
              filtersHeader
                
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
                                    Text(session.goal.title)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
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
                                selectedSession = session
                            }
                            .matchedTransitionSource(id: session.id, in: animation)

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

#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
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
        case .theme(let goalTheme):
            return sessions.filter { $0.goal.primaryTheme.theme.id == goalTheme.id && $0.goal.status != .archived && $0.status != .skipped }.count
        }
    }
    
    var filtersHeader: some View {
            Section {
                
            } header: {
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(availableFilters, id: \.self) { filter in
                            HStack(spacing: 4) {
                                if let image = filter.label.imageName {
                                    Image(systemName: image)
                                }
                                if let text = filter.label.text {
                                    if filter == .skippedSessions || filter == .archivedGoals {
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
        
        return sessions.filter { session in
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
            case .theme(let goalTheme):
                return session.goal.primaryTheme.theme.id == goalTheme.id && !isArchived && !isSkipped
 // TODO:
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

#Preview {
    let store = GoalStore()
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .environment(store)
        .modelContainer(for: Item.self, inMemory: true)
}

