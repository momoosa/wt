//
//  Filter.swift
//  Weektime
//
//  Created by Mo Moosa on 19/08/2025.
//

import WeektimeKit
import SwiftUI

extension ContentView {
    
    enum Filter: Identifiable, Hashable {
        public var id: String {
            switch self {
            case .activeToday:
                "activeToday"
            case .recommendedGoals:
                "recommendedGoals"
            case .allGoals:
                "allGoals"
            case .archivedGoals:
                "archivedGoals"
            case .skippedSessions:
                "skippedSessions"
            case .planned:
                "planned"
            case .theme(let theme):
                "theme_\(theme.id)"
            }
        }
        
        var label: (text: String?, imageName: String?) {
            var text: String?
            var image: String?
            switch self {
            case .activeToday:
                text = "Today"
            case .recommendedGoals:
                image = "star.fill"
            case .allGoals:
                text = "All"
            case .archivedGoals:
                text = "Archived"
            case .skippedSessions:
                text = "Skipped"
            case .planned:
                image = "sparkles"
                text = "Planned"
            case .theme(let theme):
                text = theme.title
            }
            return (text, image)
        }
        
        var tintColor: Color {
            switch self {
            case .activeToday, .recommendedGoals, .allGoals, .archivedGoals, .skippedSessions:
                return themes.first(where: { $0.id == "blue "})?.dark ?? .blue // TODO:
            case .planned:
                return .purple
            case .theme(let goalTheme):
                return goalTheme.theme.dark
            }
        }
        case activeToday
        case recommendedGoals
        case allGoals
        case archivedGoals
        case skippedSessions
        case planned
        case theme(GoalTag)
    }
}

