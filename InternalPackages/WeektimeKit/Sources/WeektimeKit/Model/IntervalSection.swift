//
//  IntervalSection.swift
//  WeektimeKit
//
//  Created by [Your Name] on 2025-11-07.
//

import Foundation
import SwiftData

@Model
public final class IntervalSection {
    public var id: String = UUID().uuidString
    public var name: String = ""
    public var durationSeconds: Int = 0
    public var orderIndex: Int = 0
    // Relationship to IntervalList without inverse to avoid compile-time coupling
    public var list: IntervalList?
    public var intervals: [Interval] = []
    public init(name: String, durationSeconds: Int, orderIndex: Int = 0, list: IntervalList? = nil) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.orderIndex = orderIndex
        self.list = list
    }
    
    /// Builds an ordered sequence alternating break and work intervals.
    /// Example for repeatCount = 4: break, work, break, work, break, work, break, work
    /// - Parameters:
    ///   - breakDurationSeconds: Duration in seconds for each break interval.
    ///   - workDurationSeconds: Duration in seconds for each work interval.
    ///   - repeatCount: Number of break/work pairs to create.
    ///   - list: Optional IntervalList to associate with each created interval.
    ///   - breakName: Optional name to assign to break intervals (defaults to "Break").
    ///   - workName: Optional name to assign to work intervals (defaults to "Work").
    /// - Returns: An array of `Interval` alternating `.breakTime` and `.work` with increasing `orderIndex`.
}

