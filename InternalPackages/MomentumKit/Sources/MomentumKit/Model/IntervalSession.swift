//
//  IntervalSession.swift
//  MomentumKit
//
//  Created by [Your Name] on [Date].
//

import Foundation
import SwiftData

@Model
public final class IntervalSession {
    public var id: String = UUID().uuidString
    
    @Relationship(deleteRule: .nullify)
    public var interval: Interval?
    
    public var elapsedSeconds: Int = 0
    public var isCompleted: Bool = false
    
    @Relationship(deleteRule: .nullify)
    public var listSession: IntervalListSession?

    public init(interval: Interval, session: IntervalListSession? = nil, elapsedSeconds: Int = 0, isCompleted: Bool = false) {
        self.interval = interval
        self.listSession = session
        self.elapsedSeconds = elapsedSeconds
        self.isCompleted = isCompleted
    }
}
