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
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .modelContainer(for: [Goal.self, GoalSession.self, Day.self, HistoricalSession.self])
        }
    }
}
