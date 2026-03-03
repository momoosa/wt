//
//  MomentumWatchApp.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 03/03/2026.
//

import SwiftUI
import MomentumKit
import SwiftData

@main
struct MomentumWatch_Watch_AppApp: App {
    // Shared model container using App Group
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            GoalTag.self,
            GoalSession.self,
            Day.self,
            HistoricalSession.self
        ])
        
        // Use App Group container for shared access with iPhone app
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ Watch: App Group container not found for '\(appGroupIdentifier)'")
            print("❌ Watch: Make sure the App Group is configured in the watch target's capabilities")
            fatalError("App Group container not found. Make sure '\(appGroupIdentifier)' is configured.")
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        print("✅ Watch: Using shared container at: \(storeURL.path)")
        
        // Check if the database file exists
        if FileManager.default.fileExists(atPath: storeURL.path) {
            print("✅ Watch: Database file exists")
        } else {
            print("⚠️ Watch: Database file does NOT exist - will be created")
        }
        
        let modelConfiguration = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ Watch: ModelContainer created successfully")
            
            // Debug: Query data counts
            let context = container.mainContext
            let goalDescriptor = FetchDescriptor<Goal>()
            let sessionDescriptor = FetchDescriptor<GoalSession>()
            let dayDescriptor = FetchDescriptor<Day>()
            
            do {
                let goals = try context.fetch(goalDescriptor)
                let sessions = try context.fetch(sessionDescriptor)
                let days = try context.fetch(dayDescriptor)
                print("📊 Watch Data Counts: Goals=\(goals.count), Sessions=\(sessions.count), Days=\(days.count)")
                
                #if targetEnvironment(simulator)
                if goals.isEmpty && sessions.isEmpty {
                    print("⚠️ Watch: No data found. NOTE: In iOS Simulator, iPhone and Watch use separate App Group containers.")
                    print("⚠️ Watch: Data sharing between iPhone and Watch simulators is not supported.")
                    print("⚠️ Watch: Creating sample data for simulator testing...")
                    
                    // Create sample data for simulator testing
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    let today = Day(start: startOfDay, end: endOfDay)
                    context.insert(today)
                    
                    // Create a sample theme and tag
                    let sampleTheme = Theme(id: "blue", title: "Blue", light: .blue, dark: .blue, neon: .cyan)
                    context.insert(sampleTheme)
                    
                    let sampleTag = GoalTag(title: "Work", color: sampleTheme)
                    context.insert(sampleTag)
                    
                    // Create a sample goal
                    let sampleGoal = Goal(title: "Sample Goal", primaryTag: sampleTag, weeklyTarget: 3600)
                    context.insert(sampleGoal)
                    
                    // Create a sample session
                    let sampleSession = GoalSession(title: "Sample Goal", goal: sampleGoal, day: today)
                    context.insert(sampleSession)
                    
                    // Save the context
                    try? context.save()
                    print("✅ Watch: Created sample data for simulator testing")
                    print("ℹ️ Watch: On real devices, data will sync from iPhone automatically.")
                }
                #endif
            } catch {
                print("❌ Watch: Error fetching data counts: \(error)")
            }
            
            return container
        } catch {
            print("❌ Watch: Failed to create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .modelContainer(sharedModelContainer)
        }
    }
}
