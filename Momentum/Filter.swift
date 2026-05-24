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
        case activeToday
        case completedToday
        case skippedSessions
        case inactive
        
        public var id: String {
            switch self {
            case .activeToday: "activeToday"
            case .completedToday: "completedToday"
            case .skippedSessions: "skippedSessions"
            case .inactive: "inactive"
            }
        }
        
        var text: String {
            switch self {
            case .activeToday: "Today"
            case .completedToday: "Completed"
            case .skippedSessions: "Skipped"
            case .inactive: "Inactive"
            }
        }
        
        func tintColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .activeToday: .blue
            case .completedToday: .green
            case .skippedSessions: .orange
            case .inactive: .gray
            }
        }
        
        func foregroundColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? .white : .black
        }
    }
    
    /// Holds a filter and its associated session count
    struct FilterCount: Identifiable {
        let filter: Filter
        let count: Int
        
        var id: String { filter.id }
    }
}

