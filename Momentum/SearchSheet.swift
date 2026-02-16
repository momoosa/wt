//
//  SearchSheet.swift
//  Momentum
//
//  Created by Mo Moosa on 16/02/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    let sessions: [GoalSession]
    let availableFilters: [ContentView.Filter]
    let day: Day
    let timerManager: SessionTimerManager?
    let animation: Namespace.ID
    
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    @Binding var searchText: String
    
    let onSkip: (GoalSession) -> Void
    let isGoalValid: (GoalSession) -> Bool
    
    var body: some View {
        NavigationStack {
            List {
                if searchResults.isEmpty {
                    Section {
                        ContentUnavailableView.search(text: searchText)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(availableFilters, id: \.id) { filter in
                        if let sessions = searchResults[filter], !sessions.isEmpty {
                            Section {
                                ForEach(sessions) { session in
                                    sessionRow(for: session)
                                }
                            } header: {
                                HStack {
                                    Text(filter.text)
                                        .font(.headline)
                                        .foregroundStyle(filter.tintColor)
                                    Spacer()
                                    Text("\(sessions.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search goals...")
            .focused($isSearchFieldFocused)
            .onAppear {
                isSearchFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                        searchText = ""
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .navigationTransition(
            .zoom(sourceID: "searchButton", in: animation)
        )
    }
    
    // MARK: - Search Results
    
    /// Filter sessions by search text and group by filter
    private var searchResults: [ContentView.Filter: [GoalSession]] {
        let matchingSessions: [GoalSession]
        
        if searchText.isEmpty {
            // Show all sessions when search is empty
            matchingSessions = sessions
        } else {
            // Filter by search text
            matchingSessions = sessions.filter { session in
                session.goal.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        var grouped: [ContentView.Filter: [GoalSession]] = [:]
        
        // Group by each filter
        for filter in availableFilters {
            let filtered = SessionFilterService.filter(matchingSessions, by: filter, validationCheck: isGoalValid)
            if !filtered.isEmpty {
                grouped[filter] = filtered
            }
        }
        
        return grouped
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
            onSkip: onSkip
        )
    }
}
