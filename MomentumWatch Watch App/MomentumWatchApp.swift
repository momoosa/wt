//
//  MomentumWatchApp.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 03/03/2026.
//

import SwiftUI
import MomentumKit
import SwiftData
import OSLog

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
        let appGroupIdentifier = "group.com.moosa.momentum.ios"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            AppLogger.watch.error("Watch: App Group container not found for '\(appGroupIdentifier)'")
            AppLogger.watch.error("Watch: Make sure the App Group is configured in the watch target's capabilities")
            fatalError("App Group container not found. Make sure '\(appGroupIdentifier)' is configured.")
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        AppLogger.watch.info("Watch: Using shared container at: \(storeURL.path)")
        
        // Check if the database file exists
        if FileManager.default.fileExists(atPath: storeURL.path) {
            AppLogger.watch.info("Watch: Database file exists")
        } else {
            AppLogger.watch.warning("Watch: Database file does NOT exist - will be created")
        }
        
        // CloudKit sync enabled (same as iPhone app)
        let cloudKitIdentifier = "iCloud.com.moosa.momentum.ios"
        let modelConfiguration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .private(cloudKitIdentifier)
        )
        
        AppLogger.watch.info("Watch: CloudKit sync enabled with container: \(cloudKitIdentifier)")

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            AppLogger.watch.info("Watch: ModelContainer created successfully")
            
            // Debug: Query data counts
            let context = container.mainContext
            let goalDescriptor = FetchDescriptor<Goal>()
            let sessionDescriptor = FetchDescriptor<GoalSession>()
            let dayDescriptor = FetchDescriptor<Day>()
            
            do {
                let goals = try context.fetch(goalDescriptor)
                let sessions = try context.fetch(sessionDescriptor)
                let days = try context.fetch(dayDescriptor)
                AppLogger.watch.debug("Watch Data Counts: Goals=\(goals.count), Sessions=\(sessions.count), Days=\(days.count)")
                
                #if targetEnvironment(simulator)
                if goals.isEmpty && sessions.isEmpty {
                    AppLogger.watch.warning("Watch: No data found. NOTE: In iOS Simulator, iPhone and Watch use separate App Group containers.")
                    AppLogger.watch.warning("Watch: Data sharing between iPhone and Watch simulators is not supported.")
                    AppLogger.watch.warning("Watch: Creating sample data for simulator testing...")
                    
                    // Create sample data for simulator testing
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    let today = Day(start: startOfDay, end: endOfDay)
                    context.insert(today)
                    
                    // Create a sample tag
                    let sampleTag = GoalTag(title: "Work", themeID: "blue")
                    context.insert(sampleTag)
                    
                    // Create a sample goal
                    let sampleGoal = Goal(title: "Sample Goal", primaryTag: sampleTag, weeklyTarget: 3600)
                    context.insert(sampleGoal)
                    
                    // Create a sample session
                    let sampleSession = GoalSession(title: "Sample Goal", goal: sampleGoal, day: today)
                    context.insert(sampleSession)
                    
                    // Save the context
                    try? context.save()
                    AppLogger.watch.info("Watch: Created sample data for simulator testing")
                    AppLogger.watch.info("Watch: On real devices, data will sync from iPhone automatically.")
                }
                #endif
            } catch {
                AppLogger.watch.error("Watch: Error fetching data counts: \(error)")
            }
            
            return container
        } catch {
            AppLogger.watch.error("Watch: Failed to create ModelContainer: \(error)")
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
