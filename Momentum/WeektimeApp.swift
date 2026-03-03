//
//  MomentumApp.swift
//  Momentum
//
//  Created by Mo Moosa on 22/07/2025.
//

import SwiftUI
import SwiftData
import MomentumKit
import UserNotifications
import BackgroundTasks
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - App Delegate for Notification Handling

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self
        
        // Register background refresh task
        registerBackgroundTasks()
        
        return true
    }
    
    // Register background task for widget updates
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.moosa.ios.momentum.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    // Handle background refresh
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleAppRefresh()
        
        // Create task to refresh widget data
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = BlockOperation {
            // Reload widgets with fresh data
            #if canImport(WidgetKit)
            WidgetKit.WidgetCenter.shared.reloadAllTimelines()
            print("🔄 Background refresh: Reloaded widget timelines")
            #endif
        }
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        queue.addOperation(operation)
    }
    
    // Schedule next background refresh
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.moosa.ios.momentum.refresh")
        // Request refresh in 15 minutes (iOS may delay this)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background refresh")
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner, play sound, and update badge even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle different notification types
        if let goalId = userInfo["goalId"] as? String {
            print("📱 User tapped notification for goal: \(goalId)")
            // TODO: Navigate to goal detail if needed
        }
        
        completionHandler()
    }
}

@main
struct MomentumApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            GoalTag.self,
            GoalSession.self,
            Day.self,
            HistoricalSession.self
        ])
        
        // Use App Group container for widget access
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ iOS: App Group container not found for '\(appGroupIdentifier)'")
            fatalError("App Group container not found. Make sure '\(appGroupIdentifier)' is configured.")
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        print("✅ iOS: Using shared container at: \(storeURL.path)")
        
        // Check if the database file exists
        if FileManager.default.fileExists(atPath: storeURL.path) {
            print("✅ iOS: Database file exists")
            // Get file size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
               let fileSize = attrs[.size] as? UInt64 {
                print("✅ iOS: Database file size: \(fileSize) bytes")
            }
        } else {
            print("⚠️ iOS: Database file does NOT exist - will be created")
        }
        
        let modelConfiguration = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ iOS: ModelContainer created successfully")
            
            // Debug: Query data counts
            let context = container.mainContext
            let goalDescriptor = FetchDescriptor<Goal>()
            let sessionDescriptor = FetchDescriptor<GoalSession>()
            let dayDescriptor = FetchDescriptor<Day>()
            
            do {
                let goals = try context.fetch(goalDescriptor)
                let sessions = try context.fetch(sessionDescriptor)
                let days = try context.fetch(dayDescriptor)
                print("📊 iOS Data Counts: Goals=\(goals.count), Sessions=\(sessions.count), Days=\(days.count)")
                
                #if targetEnvironment(simulator)
                print("ℹ️ iOS: Running in simulator. Note that Watch simulator uses a separate App Group container.")
                print("ℹ️ iOS: Data will be shared correctly on real devices (paired iPhone + Apple Watch).")
                #endif
            } catch {
                print("❌ iOS: Error fetching data counts: \(error)")
            }
            
            return container
        } catch {
            print("❌ iOS: Failed to create ModelContainer: \(error)")
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
                .onOpenURL { url in
                    handleURL(url)
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // Schedule background refresh when app goes to background
                appDelegate.scheduleAppRefresh()
            }
        }
    }
    
    // Handle deep link URLs from widgets
    private func handleURL(_ url: URL) {
        print("📱 Received URL: \(url.absoluteString)")
        
        guard url.scheme == "momentum" else {
            print("⚠️ Invalid URL scheme")
            return
        }
        
        switch url.host {
        case "goal":
            // Parse URL like: momentum://goal/{sessionID}
            guard let sessionID = url.pathComponents.last,
                  sessionID != "/" else {
                print("⚠️ Invalid goal URL format")
                return
            }
            print("✅ Opening session: \(sessionID)")
            NotificationCenter.default.post(name: NSNotification.Name("OpenSessionFromWidget"), object: sessionID)
            
        case "search":
            // momentum://search
            print("✅ Opening search")
            NotificationCenter.default.post(name: NSNotification.Name("OpenSearch"), object: nil)
            
        case "new":
            // momentum://new
            print("✅ Opening new goal editor")
            NotificationCenter.default.post(name: NSNotification.Name("OpenNewGoal"), object: nil)
            
        default:
            print("⚠️ Unknown URL host: \(url.host ?? "none")")
        }
    }
}
