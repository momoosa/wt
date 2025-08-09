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
    @Namespace var namespace

    var body: some View {
            List {
                ForEach(sessions) { session in
                    Section {
                    NavigationLink {
                        ChecklistDetailView(session: session, animation: namespace)
                    } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(session.goal.title)
                                        HStack {
                                            Text("25/30 min")
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
                                        
                                    } label: {
                                        Image(systemName: "play.circle.fill")
                                    }
                                }
                                .foregroundStyle(colorScheme == .dark ? session.goal.primaryTheme.theme.neon : session.goal.primaryTheme.theme.dark)
                            .listRowBackground(colorScheme == .dark ? session.goal.primaryTheme.theme.light.opacity(0.03) : Color(.systemBackground))
                            .onTapGesture {
                                    selectedSession = session
                            }
                        .matchedTransitionSource(id: session.id, in: namespace)                    }
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
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
    
        .onAppear {
            refreshGoals()
        }
        .onChange(of: goals) { old, new in
            refreshGoals()
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
}

#Preview {
    let day = Day(start: Date.now.startOfDay()!, end: Date.now.endOfDay()!)
    ContentView(day: day)
        .modelContainer(for: Item.self, inMemory: true)
}
