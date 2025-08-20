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
    @State private var availableFilters: [Filter] = [.activeToday, .allGoals, .archivedGoals]
    @State private var activeFilter: Filter?
    
    @State private var activeSession: ActiveSessionDetails?
    @State private var now = Date()
    
    // MARK: - UserDefaults Keys for Timer Persistence
    private let activeSessionElapsedTimeKey = "ActiveSessionElapsedTimeV1"
    private let activeSessionStartDateKey = "ActiveSessionStartDateV1"
    private let activeSessionIDKey = "ActiveSessionIDV1"
    
    var body: some View {
            List {
              filtersHeader
                
                ForEach(sessions) { session in
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
                                    HStack {
                                        if let activeSession, activeSession.id == session.id, let timeText = activeSession.timeText {
                                            Text(timeText)
                                                .contentTransition(.numericText())
                                                .fontWeight(.semibold)
                                                .font(.footnote)
                                        } else {
                                            Text("TODO:")
                                                .fontWeight(.semibold)
                                                .font(.footnote)

                                        }
                                        
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
                                    Image(systemName: session.id == activeSession?.id ? "stop.circle.fill" : "play.circle.fill")
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
            
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
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
            if activeSession?.id != nil {
                activeSession?.startUITimer()
            }
        }
        .onChange(of: goals) { old, new in
            refreshGoals()
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
    
    
    
    var filtersHeader: some View {
            Section {
                
            } header: {
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(availableFilters, id: \.self) { filter in
                            HStack {
                                if let image = filter.label.imageName {
                                    Image(systemName: image)
                                } else if let text = filter.label.text {
                                    Text(text)
                                }
                            }
                            .foregroundStyle(filter.id == activeFilter?.id ? filter.tintColor : .primary)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .padding([.top, .bottom], 6)
                            .padding([.leading, .trailing], 10)
                            .frame(minWidth: 60.0)
                            .background {
                                Capsule()
                                    .fill(filter.id == activeFilter?.id ? filter.tintColor.opacity(0.4) : Color(.systemGray5))
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
        if activeSession?.id == session.id {
            // Stop the current active timer
            activeSession?.stopUITimer()
            withAnimation {
                activeSession = nil
            }
                saveTimerState()
        } else {
            withAnimation {
                activeSession = ActiveSessionDetails(id: session.id, startDate: .now, elapsedTime: 0)
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
            activeSession = ActiveSessionDetails(id: uuid, startDate: Date(timeIntervalSince1970: timeInterval), elapsedTime: elapsed)
        } else {
            activeSession = nil
        }
    }
}

#Preview {
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .modelContainer(for: Item.self, inMemory: true)
}
