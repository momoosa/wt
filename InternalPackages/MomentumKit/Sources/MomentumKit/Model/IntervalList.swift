import Foundation
import SwiftData

/// A model representing a named collection of Interval items associated to a Goal.
@Model
public final class IntervalList {
    /// Unique identifier for the IntervalList.
    public var id: String = UUID().uuidString
    /// The name of the IntervalList.
    public var name: String = ""
    /// The order index of the IntervalList.
    public var orderIndex: Int = 0
    
    /// The Goal associated with this IntervalList.
    @Relationship(deleteRule: .nullify)
    public var goal: Goal?
    
    /// The collection of Interval items belonging to this list.
    @Relationship(deleteRule: .cascade, inverse: \Interval.list)
    public var intervals: [Interval]? = []
    
    /// Inverse relationship for sessions using this list
    @Relationship(deleteRule: .nullify, inverse: \IntervalListSession.list)
    public var sessions: [IntervalListSession]? = []

    /// Initializes a new IntervalList.
    /// - Parameters:
    ///   - name: The name of the list.
    ///   - orderIndex: The order index of the list. Defaults to 0.
    ///   - goal: An optional Goal associated with this list.
    ///   - intervals: An optional array of Interval items. Defaults to empty.
    public init(
        name: String,
        orderIndex: Int = 0,
        goal: Goal? = nil,
        intervals: [Interval] = []
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.orderIndex = orderIndex
        self.goal = goal
        self.intervals = intervals
        for (index, interval) in intervals.enumerated() {
            interval.list = self
            interval.orderIndex = index
        }
    }

    /// Adds a single Interval to the list.
    /// - Parameter interval: The Interval to add.
    public func addInterval(_ interval: Interval) {
        if intervals == nil {
            intervals = []
        }
        interval.list = self
        interval.orderIndex = intervals?.count ?? 0
        intervals?.append(interval)
    }

    /// Adds multiple Intervals to the list.
    /// - Parameter intervals: The array of Intervals to add.
    public func addIntervals(_ intervals: [Interval]) {
        if self.intervals == nil {
            self.intervals = []
        }
        let startIndex = self.intervals?.count ?? 0
        for (offset, interval) in intervals.enumerated() {
            interval.list = self
            interval.orderIndex = startIndex + offset
        }
        self.intervals?.append(contentsOf: intervals)
    }
}
