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
    @State private var isSearchFieldFocused = false
    
    let sessions: [GoalSession]
    let availableFilters: [ContentView.Filter]
    let day: Day
    let timerManager: SessionTimerManager?
    let animation: Namespace.ID
    
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    @Binding var searchText: String
    
    let onSkip: (GoalSession) -> Void
    let onSyncHealthKit: (() -> Void)?
    let isSyncingHealthKit: Bool
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
                    ForEach(searchResults) { session in
                        sessionRow(for: session)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, isPresented: $isSearchFieldFocused, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search goals...")
            .task {
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
    
    /// Filter sessions by search text and sort alphabetically
    private var searchResults: [GoalSession] {
        let matchingSessions: [GoalSession]
        
        if searchText.isEmpty {
            // Show all sessions when search is empty
            matchingSessions = sessions
        } else {
            // Filter by search text
            matchingSessions = sessions.filter { session in
                session.goal?.title.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Sort alphabetically by goal title
        return matchingSessions.sorted { s1, s2 in
            let title1 = s1.goal?.title ?? ""
            let title2 = s2.goal?.title ?? ""
            return title1.localizedStandardCompare(title2) == .orderedAscending
        }
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
            onSkip: onSkip,
            onSyncHealthKit: onSyncHealthKit,
            isSyncingHealthKit: isSyncingHealthKit
        )
    }
}
