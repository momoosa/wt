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
    public enum Kind: String {
        case work
        case breakTime
    }
    public var id: String = UUID().uuidString
    public var name: String = ""
    public var durationSeconds: Int = 0
    public var orderIndex: Int = 0
    private var kindRawValue: String = Kind.work.rawValue
    public var kind: Kind {
        get {
            Kind(rawValue: kindRawValue) ?? .breakTime
        }
        set {
            kindRawValue = newValue.rawValue
        }
    }
    // Relationship to IntervalList without inverse to avoid compile-time coupling
    public var list: IntervalList?
    
    public init(name: String, durationSeconds: Int, orderIndex: Int = 0, list: IntervalList? = nil, kind: Kind) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.orderIndex = orderIndex
        self.list = list
        self.kind = kind
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
    public static func buildAlternatingSequence(
        breakDurationSeconds: Int,
        workDurationSeconds: Int,
        repeatCount: Int,
        list: IntervalList? = nil,
        breakName: String = "Break",
        workName: String = "Work"
    ) -> [Interval] {
        guard repeatCount > 0 else { return [] }
        var result: [Interval] = []
        var index = 0
        for i in 0..<repeatCount {
            // Break first
            let breakInterval = Interval(
                name: "\(breakName) \(i + 1)",
                durationSeconds: breakDurationSeconds,
                orderIndex: index,
                list: list,
                kind: .breakTime
            )
            result.append(breakInterval)
            index += 1

            // Then work
            let workInterval = Interval(
                name: "\(workName) \(i + 1)",
                durationSeconds: workDurationSeconds,
                orderIndex: index,
                list: list,
                kind: .work
            )
            result.append(workInterval)
            index += 1
        }
        return result
    }
}

