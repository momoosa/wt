//
//  Filter.swift
//  Momentum
//
//  Created by Mo Moosa on 19/08/2025.
//

import MomentumKit
import SwiftUI
import SwiftData

extension ContentView {
    
    enum Filter: Identifiable, Hashable {
        public var id: String {
            switch self {
            case .activeToday:
                "activeToday"
            case .allGoals:
                "allGoals"
            case .completedToday:
                "completedToday"
            case .skippedSessions:
                "skippedSessions"
            case .inactive:
                "inactive"
            case .theme(let tag):
                "theme_\(tag.persistentModelID)"
            }
        }
        
        var text: String {
            switch self {
            case .activeToday:
                return "Today"
            case .allGoals:
                return "All"
            case .completedToday:
                return "Completed"
            case .skippedSessions:
                return "Skipped"
            case .inactive:
                return "Inactive"
            case .theme(let tag):
                return tag.title
            }
        }
        
        var tintColor: Color {
            switch self {
            case .activeToday, .allGoals:
                return .primary
            case .completedToday:
                return .green
            case .skippedSessions:
                return .orange
            case .inactive:
                return .gray
            case .theme(let tag):
                return tag.theme.dark
            }
        }
        case activeToday
        case allGoals
        case completedToday
        case skippedSessions
        case inactive
        case theme(GoalTag)
    }
}

