//
//  WeektimeApp.swift
//  Weektime
//
//  Created by Mo Moosa on 22/07/2025.
//

import SwiftUI
import SwiftData
import WeektimeKit

@main
struct WeektimeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            GoalTag.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State var goalStore = GoalStore()
    @State var day: Day?
    @Query var days: [Day]
    private let permissionHandler = PermissionsHandler()
    var body: some Scene {
        WindowGroup {
            if let day {
                NavigationStack {
                    ContentView(day: day)
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationTitle(day.startDate.formatted(.dateTime.month().day()))
                        .environment(goalStore)
                        .task {
                            await permissionHandler.requestScreentimeAuthorization() // TODO: MOve somewhere...
                        }
                }
            } else {
                Text("")
                    .task {
                        if day == nil {
                            // TODO: Switch day
                            do {
                                let weekStore = WeekStore(modelContext: sharedModelContainer.mainContext)
                                
                                self.day = try weekStore.fetchCurrentDay()
                                
                            } catch {
                                
                            }
                        }
                    }
                
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
