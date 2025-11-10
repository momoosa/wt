//
//  IntervalSession.swift
//  WeektimeKit
//
//  Created by [Your Name] on [Date].
//

import Foundation
import SwiftData

@Model
public final class IntervalSession {
    public var id: String = UUID().uuidString
    public var interval: Interval
    public var elapsedSeconds: Int = 0
    public var isCompleted: Bool = false
    public var session: GoalSession?

    public init(interval: Interval, session: GoalSession? = nil, elapsedSeconds: Int = 0, isCompleted: Bool = false) {
        self.interval = interval
        self.session = session
        self.elapsedSeconds = elapsedSeconds
        self.isCompleted = isCompleted
    }
}
