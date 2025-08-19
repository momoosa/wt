//
//  ContentView.swift
//  Weektime
//
//  Created by Mo Moosa on 22/07/2025.
//

import SwiftUI
import SwiftData
import WeektimeKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query private var sessions: [GoalSession]
    let day: Day
    @State private var selectedSession: GoalSession?
    @Namespace var animation
    @State private var showingGoalEditor = false
    
    @State private var timer: Timer?
    @State private var activeSessionID: GoalSession.ID? = nil
    @State private var activeSessionStartDate: Date? = nil
    @State private var activeSessionElapsedTime: TimeInterval = 0
    @State private var now = Date()
    let timerInterval: TimeInterval = 1.0
    
    // MARK: - UserDefaults Keys for Timer Persistence
    private let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
    private let activeSessionStartDateKey = "ActiveSessionStartDateV1"
    private let activeSessionIDKey = "ActiveSessionIDV1"
    
    var body: some View {
        // Wrapping main content in a ZStack to enable overlaying "Active Timers" above the plus button
        ZStack(alignment: .bottom) {
            List {
                ForEach(sessions) { session in
                    Section {
                        NavigationLink {
                            ChecklistDetailView(session: session, animation: animation)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.goal.title)
                                    HStack {
                                        Text(timerText(for: session))
                                            .fontWeight(.semibold)
                                            .font(.footnote)
                                        
                                        Text(session.goal.primaryTheme.title)
                                            .font(.caption2)
                                            .padding(4)
                                            .background(Capsule()
                                                .fill(session.goal.primaryTheme.theme.light.opacity(0.15)))
                                        Spacer()
                                        
                                    }
                                    .opacity(0.7)
                                }
                                
                                Spacer()
                                
                                Button {
                                    toggleTimer(for: session)
                                } label: {
                                    Image(systemName: session.id == activeSessionID ? "stop.circle.fill" : "play.circle.fill")
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
                    }
                    .listSectionSpacing(.compact)
                }
                .onDelete(perform: deleteItems)
            }
            .animation(.spring(), value: goals)
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            
        }
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
#endif
            
            if activeSessionID != nil, let session = sessions.first(where: { $0.id == activeSessionID }) {
                ToolbarItem(placement: .bottomBar) {
                    
                    ActionView(session: session, activeSessionID: $activeSessionID, activeSessionStartDate: $activeSessionStartDate, activeSessionElapsedTime: $activeSessionElapsedTime, currentTime: $now) { event in
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
            if activeSessionID != nil {
                startUITimer()
            }
        }
        .onChange(of: goals) { old, new in
            refreshGoals()
        }
        .onDisappear {
            stopUITimer()
        }
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh UI timer update on foreground
            if activeSessionID != nil {
                startUITimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Stop UI timer updates on background
            stopUITimer()
        }
#endif
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorView()
                .navigationTransition(
                    .zoom(sourceID: "info", in: animation)
                )
        }
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
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(goals[index])
            }
        }
    }
    
    func handle(event: ActionView.Event) {
        switch event {
        case .stopTapped:
            if let session = sessions.first(where: { $0.id == activeSessionID }) {
                toggleTimer(for: session)
            }
        }
    }
    
    private func toggleTimer(for session: GoalSession) {
        if activeSessionID == session.id {
            // Stop the current active timer
            withAnimation {
                if let startDate = activeSessionStartDate {
                    let elapsed = Date().timeIntervalSince(startDate)
                    activeSessionElapsedTime += elapsed
                }
                activeSessionID = nil
            }
                activeSessionStartDate = nil
                activeSessionElapsedTime = 0
                saveTimerState()
                stopUITimer()
        } else {
            // Stop any other running timer
            if let startDate = activeSessionStartDate {
                let elapsed = Date().timeIntervalSince(startDate)
                activeSessionElapsedTime += elapsed
            }
            // Start timer for the new session
            withAnimation {
                activeSessionID = session.id
                activeSessionStartDate = Date()
                activeSessionElapsedTime = 0
                saveTimerState()
                startUITimer()
            }
        }
    }
    
    private func startUITimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            self.now = Date()
        }
    }
    
    private func stopUITimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerText(for session: GoalSession) -> String {
        let elapsed: TimeInterval
        if activeSessionID == session.id, let startDate = activeSessionStartDate {
            elapsed = activeSessionElapsedTime + now.timeIntervalSince(startDate)
        } else {
            elapsed = 0
        }
        return Duration.seconds(elapsed).formatted()
    }
    
    // MARK: - Persistence Helpers
    
    private func saveTimerState() {
        if let activeID = activeSessionID {
            UserDefaults.standard.set(activeID.uuidString, forKey: activeSessionIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeSessionIDKey)
        }
        
        if let startDate = activeSessionStartDate {
            UserDefaults.standard.set(startDate.timeIntervalSince1970, forKey: activeSessionStartDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeSessionStartDateKey)
        }
        
        UserDefaults.standard.set(activeSessionElapsedTime, forKey: activeSessionElapsedTimeKey)
    }
    
    private func loadTimerState() {
        if let idString = UserDefaults.standard.string(forKey: activeSessionIDKey),
           let id = UUID(uuidString: idString) {
            activeSessionID = id
        } else {
            activeSessionID = nil
        }
        
        if UserDefaults.standard.object(forKey: activeSessionStartDateKey) != nil {
            let timeInterval = UserDefaults.standard.double(forKey: activeSessionStartDateKey)
            activeSessionStartDate = Date(timeIntervalSince1970: timeInterval)
        } else {
            activeSessionStartDate = nil
        }
        
        activeSessionElapsedTime = UserDefaults.standard.double(forKey: activeSessionElapsedTimeKey)
    }
}

#Preview {
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .modelContainer(for: Item.self, inMemory: true)
}
