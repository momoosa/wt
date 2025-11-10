//
//  Interval.swift
//  WeektimeKit
//
//  Created by [Your Name] on 2025-11-07.
//

import Foundation
import SwiftData

@Model
public final class Interval {
    public var id: String = UUID().uuidString
    public var name: String = ""
    public var durationSeconds: Int = 0
    public var orderIndex: Int = 0
    
    // Relationship to Goal without inverse to avoid compile-time coupling
    public var goal: Goal?
    
    public init(name: String, durationSeconds: Int, orderIndex: Int = 0, goal: Goal? = nil) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.orderIndex = orderIndex
        self.goal = goal
    }
}
