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
        
        // Custom hash implementation to use persistentModelID for theme case
        func hash(into hasher: inout Hasher) {
            switch self {
            case .activeToday:
                hasher.combine("activeToday")
            case .completedToday:
                hasher.combine("completedToday")
            case .skippedSessions:
                hasher.combine("skippedSessions")
            case .inactive:
                hasher.combine("inactive")
            case .theme(let tag):
                hasher.combine("theme")
                hasher.combine(tag.persistentModelID)
            }
        }
        
        // Custom equality to compare persistentModelID for theme case
        static func == (lhs: Filter, rhs: Filter) -> Bool {
            switch (lhs, rhs) {
            case (.activeToday, .activeToday),
                 (.completedToday, .completedToday),
                 (.skippedSessions, .skippedSessions),
                 (.inactive, .inactive):
                return true
            case (.theme(let lhsTag), .theme(let rhsTag)):
                return lhsTag.persistentModelID == rhsTag.persistentModelID
            default:
                return false
            }
        }
        
        var text: String {
            switch self {
            case .activeToday:
                return "Today"
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
            case .activeToday:
                return .blue
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
        case completedToday
        case skippedSessions
        case inactive
        case theme(GoalTag)
    }
}

