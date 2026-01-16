
import Foundation
import SwiftData

/// A model representing a named collection of Interval items associated to a Goal.
@Model
public final class IntervalListSession: Identifiable {
    /// Unique identifier for the IntervalList.
    public var id: String
    /// The order index of the IntervalList.
    public var orderIndex: Int
    /// The Goal associated with this IntervalList.
    public var goalSession: GoalSession?
    /// The collection of Interval items belonging to this list.
    public var list: IntervalList
    public var intervals: [IntervalSession]

    /// Initializes a new IntervalList.
    /// - Parameters:
    ///   - name: The name of the list.
    ///   - orderIndex: The order index of the list. Defaults to 0.
    ///   - goal: An optional Goal associated with this list.
    ///   - intervals: An optional array of Interval items. Defaults to empty.
    public init(list: IntervalList,
        orderIndex: Int = 0,
        goal: GoalSession? = nil,
    ) {
        self.id = UUID().uuidString
        self.orderIndex = orderIndex
        self.goalSession = goal
        self.list = list
        var intervals = [IntervalSession]()
        for (index, interval) in list.intervals.enumerated() {
            let interval = IntervalSession(interval: interval)
            intervals.append(interval)
        }
        
        self.intervals = intervals
    }
    
    public func contains(id: String) -> Bool {
        intervals.contains(where: { $0.id == id })
    }
}
