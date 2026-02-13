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

// MARK: - App Delegate for Notification Handling

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self
        return true
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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            GoalTag.self,
        ])
        
        // Use App Group container for widget access
        let appGroupIdentifier = "group.com.moosa.ios.momentum"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            fatalError("App Group container not found. Make sure '\(appGroupIdentifier)' is configured.")
        }
        
        let storeURL = containerURL.appendingPathComponent("default.store")
        let modelConfiguration = ModelConfiguration(url: storeURL)

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
    }
    
    // Handle deep link URLs from widgets
    private func handleURL(_ url: URL) {
        print("📱 Received URL: \(url.absoluteString)")
        
        // Parse URL like: momentum://goal/{sessionID}
        guard url.scheme == "momentum",
              url.host == "goal",
              let sessionID = url.pathComponents.last,
              sessionID != "/" else {
            print("⚠️ Invalid URL format")
            return
        }
        
        print("✅ Opening session: \(sessionID)")
        // Post notification to ContentView
        NotificationCenter.default.post(name: NSNotification.Name("OpenSessionFromWidget"), object: sessionID)
    }
}
