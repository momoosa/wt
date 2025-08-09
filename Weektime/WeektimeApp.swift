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
            GoalTheme.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    
    @State var day: Day?
    var body: some Scene {
        WindowGroup {
            if let day {
                ContentView(day: day)
            } else {
                Text("")
                    .onAppear {
                        guard let startDate = Date.now.startOfDay() else {
                            fatalError("Could not create Day")
                        }
                        
                        guard let endDate = Date.now.endOfDay() else {
                            fatalError("Could not create Day")
                        }
                        self.day = Day(start: startDate, end: endDate)
                        
                    }
                
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
