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
import OSLog
import AppIntents
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
        
        #if os(iOS)
        // Initialize WatchConnectivity early to start listening for Watch messages
        _ = WatchConnectivityManager.shared
        AppLogger.app.info("WatchConnectivityManager initialized")
        #endif
        
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
            AppLogger.background.info("Background refresh: Reloaded widget timelines")
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
            AppLogger.background.info("Scheduled background refresh")
        } catch {
            AppLogger.background.error("Could not schedule app refresh: \(error)")
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
            AppLogger.notifications.debug("User tapped notification for goal: \(goalId)")
            // Note: Navigation to goal detail handled by ContentView's onReceive(OpenSessionFromWidget)
        }
        
        completionHandler()
    }
}

@main
struct MomentumApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    static var appShortcutsProvider: MomentumAppShortcutsProvider {
        MomentumAppShortcutsProvider()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            GoalTag.self,
            GoalSession.self,
            Day.self,
            HistoricalSession.self
        ])
        
        // Use App Group container for widget access
        let appGroupIdentifier = "group.com.moosa.momentum.ios"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            AppLogger.data.error("iOS: App Group container not found for '\(appGroupIdentifier)'")
            fatalError("App Group container not found. Make sure '\(appGroupIdentifier)' is configured.")
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        AppLogger.data.info("iOS: Using shared container at: \(storeURL.path)")
        
        // Check if the database file exists
        if FileManager.default.fileExists(atPath: storeURL.path) {
            AppLogger.data.info("iOS: Database file exists")
            // Get file size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
               let fileSize = attrs[.size] as? UInt64 {
                AppLogger.data.info("iOS: Database file size: \(fileSize) bytes")
            }
        } else {
            AppLogger.data.warning("iOS: Database file does NOT exist - will be created")
        }
        
        // CloudKit sync enabled - all models have been updated to meet requirements
        let cloudKitIdentifier = "iCloud.com.moosa.momentum.ios"
        let modelConfiguration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .private(cloudKitIdentifier)
        )
        
        AppLogger.data.info("iOS: CloudKit sync enabled with container: \(cloudKitIdentifier)")

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            AppLogger.data.info("iOS: ModelContainer created successfully")
            
            // Debug: Query data counts
            let context = container.mainContext
            let goalDescriptor = FetchDescriptor<Goal>()
            let sessionDescriptor = FetchDescriptor<GoalSession>()
            let dayDescriptor = FetchDescriptor<Day>()
            
            do {
                let goals = try context.fetch(goalDescriptor)
                let sessions = try context.fetch(sessionDescriptor)
                let days = try context.fetch(dayDescriptor)
                AppLogger.data.debug("iOS Data Counts: Goals=\(goals.count), Sessions=\(sessions.count), Days=\(days.count)")
                
                #if targetEnvironment(simulator)
                AppLogger.data.info("iOS: Running in simulator. Note that Watch simulator uses a separate App Group container.")
                AppLogger.data.info("iOS: Data will be shared correctly on real devices (paired iPhone + Apple Watch).")
                #endif
            } catch {
                AppLogger.data.error("iOS: Error fetching data counts: \(error)")
            }
            
            return container
        } catch {
            AppLogger.data.error("iOS: Failed to create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State var goalStore = GoalStore()
    @State var day: Day?
    @Query var days: [Day]
    private let permissionHandler = PermissionsHandler()
    
    // CloudKit sync toast state
    @AppStorage("hasShownCloudKitToast") private var hasShownCloudKitToast = false
    @State private var showCloudKitToast = false
    @State private var cloudKitToastStatus: CloudKitSyncToast.SyncStatus = .enabled
    
    // Day change detection
    @State private var dayChangeTimer: Timer?
    
    var body: some Scene {
        WindowGroup {
            if let day {
                NavigationStack {
                    ContentView(day: day)
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationTitle(day.startDate.formatted(.dateTime.month().day()))
                        .environment(goalStore)
                        .task {
                            // Request ScreenTime authorization on app launch
                            await permissionHandler.requestScreentimeAuthorization()
                            
                            // Show CloudKit sync toast on first launch
                            if !hasShownCloudKitToast {
                                // Wait a bit for the UI to settle
                                try? await Task.sleep(for: .seconds(1.5))
                                
                                // Check if CloudKit is properly configured
                                let syncStatus = await checkCloudKitStatus()
                                cloudKitToastStatus = syncStatus
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showCloudKitToast = true
                                }
                                
                                hasShownCloudKitToast = true
                            }
                            
                            // Start monitoring for day changes
                            startDayChangeMonitoring()
                        }
                        .onDisappear {
                            // Clean up timer when view disappears
                            dayChangeTimer?.invalidate()
                            dayChangeTimer = nil
                        }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
                .cloudKitSyncToast(isShowing: $showCloudKitToast, status: cloudKitToastStatus)
            } else {
                Text("")
                    .task {
                        if day == nil {
                            do {
                                let weekStore = WeekStore(modelContext: sharedModelContainer.mainContext)
                                
                                // Clean up any duplicate days from sync conflicts
                                try? weekStore.cleanupDuplicateDays()
                                
                                // Fetch the current day
                                let currentDay = try weekStore.fetchCurrentDay()
                                
                                // Eagerly create sessions for the day to avoid blank screen
                                try createSessionsForDay(currentDay, context: sharedModelContainer.mainContext)
                                
                                // Update the day (this will trigger ContentView to load)
                                self.day = currentDay
                                
                                AppLogger.app.info("Initial day load complete with sessions")
                            } catch {
                                AppLogger.app.error("Failed to load initial day: \(error.localizedDescription)")
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
            } else if newPhase == .active {
                // Check for day change when app becomes active
                checkForDayChange()
            }
        }
    }
    
    // Handle deep link URLs from widgets
    private func handleURL(_ url: URL) {
        AppLogger.app.debug("Received URL: \(url.absoluteString)")
        
        guard url.scheme == "momentum" else {
            AppLogger.app.warning("Invalid URL scheme")
            return
        }
        
        switch url.host {
        case "goal":
            // Parse URL like: momentum://goal/{sessionID}
            guard let sessionID = url.pathComponents.last,
                  sessionID != "/" else {
                AppLogger.app.warning("Invalid goal URL format")
                return
            }
            AppLogger.app.info("Opening session: \(sessionID)")
            NotificationCenter.default.post(name: NSNotification.Name("OpenSessionFromWidget"), object: sessionID)
            
        case "search":
            // momentum://search
            AppLogger.app.info("Opening search")
            NotificationCenter.default.post(name: NSNotification.Name("OpenSearch"), object: nil)
            
        case "new":
            // momentum://new
            AppLogger.app.info("Opening new goal editor")
            NotificationCenter.default.post(name: NSNotification.Name("OpenNewGoal"), object: nil)
            
        default:
            AppLogger.app.warning("Unknown URL host: \(url.host ?? "none")")
        }
    }
    
    // Check CloudKit sync status
    private func checkCloudKitStatus() async -> CloudKitSyncToast.SyncStatus {
        // Check if CloudKit container is accessible
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moosa.momentum.ios") else {
            return .error("iCloud sync not configured")
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        
        // Check if store file exists
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return .syncing
        }
        
        // Check if we can read the store
        do {
            _ = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            return .enabled
        } catch {
            return .error("Failed to access sync storage")
        }
    }
    
    // Monitor for day changes and update the day when midnight passes
    private func startDayChangeMonitoring() {
        // Check every minute for day changes
        dayChangeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            checkForDayChange()
        }
    }
    
    private func checkForDayChange() {
        guard let currentDay = day else { return }
        
        let currentDayID = Date.now.yearMonthDayID(with: Calendar.current)
        
        // If the day has changed, fetch the new day
        if currentDayID != currentDay.id {
            AppLogger.app.info("Day changed from \(currentDay.id) to \(currentDayID), reloading...")
            
            Task { @MainActor in
                do {
                    let weekStore = WeekStore(modelContext: sharedModelContainer.mainContext)
                    
                    // Clean up any duplicate days from sync conflicts
                    try? weekStore.cleanupDuplicateDays()
                    
                    // Fetch the new current day
                    let newDay = try weekStore.fetchCurrentDay()
                    
                    // Eagerly create sessions for the new day to avoid blank screen
                    try createSessionsForDay(newDay, context: sharedModelContainer.mainContext)
                    
                    // Update the day (this will trigger ContentView to reload)
                    self.day = newDay
                    
                    AppLogger.app.info("Successfully loaded new day: \(currentDayID) with sessions")
                } catch {
                    AppLogger.app.error("Failed to load new day: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Creates GoalSession objects for all active goals for the given day
    private func createSessionsForDay(_ day: Day, context: ModelContext) throws {
        // Fetch all goals and filter for active ones (status is computed property)
        let goalDescriptor = FetchDescriptor<Goal>()
        let allGoals = try context.fetch(goalDescriptor)
        let activeGoals = allGoals.filter { $0.status == .active }
        
        // Fetch existing sessions for this day
        let dayID = day.id
        let sessionDescriptor = FetchDescriptor<GoalSession>(
            predicate: #Predicate { session in
                session.day?.id == dayID
            }
        )
        let existingSessions = try context.fetch(sessionDescriptor)
        
        // Create sessions for goals that don't have them yet
        for goal in activeGoals {
            if !existingSessions.contains(where: { $0.goal?.id == goal.id }) {
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                context.insert(session)
                
                // Create checklist item sessions
                if let checklistItems = goal.checklistItems {
                    for checklistItem in checklistItems {
                        let itemSession = ChecklistItemSession(checklistItem: checklistItem, session: session)
                        context.insert(itemSession)
                        session.checklist?.append(itemSession)
                    }
                }
                
                AppLogger.app.debug("Created session for goal: \(goal.title)")
            }
        }
        
        // Save if we made changes
        if context.hasChanges {
            try context.save()
            AppLogger.app.info("Created \(activeGoals.count - existingSessions.count) new sessions for day \(day.id)")
        }
    }
}
