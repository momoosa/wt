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
    @Query private var items: [Goal]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { goal in
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(goal.title)
                                HStack {
                                    Text("25/30 min")
                                        .fontWeight(.semibold)
                                        .font(.footnote)
                                    
                                    Text(goal.primaryTheme.title)
                                        .font(.caption2)
                                        .padding(4)
                                        .background(Capsule()
                                            .fill(goal.primaryTheme.theme.light.opacity(0.15)))
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
                        .foregroundStyle(colorScheme == .dark ? goal.primaryTheme.theme.neon : goal.primaryTheme.theme.dark)
                        .listRowBackground(colorScheme == .dark ? goal.primaryTheme.theme.light.opacity(0.03) : Color(.systemBackground))
                    }
                        
                            .listSectionSpacing(.compact)
                }
                .onDelete(perform: deleteItems)

            }
            .animation(.spring(), value: items)
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
        } detail: {
            Text("Select an item")
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
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
