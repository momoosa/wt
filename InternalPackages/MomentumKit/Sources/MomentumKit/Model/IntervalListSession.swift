
import Foundation
import SwiftData

/// A model representing a named collection of Interval items associated to a Goal.
@Model
public final class IntervalListSession: Identifiable {
    /// Unique identifier for the IntervalList.
    public var id: String = UUID().uuidString
    /// The order index of the IntervalList.
    public var orderIndex: Int = 0
    
    /// The Goal associated with this IntervalList.
    @Relationship(deleteRule: .nullify)
    public var session: GoalSession?
    
    /// The collection of Interval items belonging to this list.
    @Relationship(deleteRule: .nullify)
    public var list: IntervalList?
    
    @Relationship(deleteRule: .cascade)
    public var intervals: [IntervalSession]? = []

    /// Initializes a new IntervalList.
    /// - Parameters:
    ///   - name: The name of the list.
    ///   - orderIndex: The order index of the list. Defaults to 0.
    ///   - goal: An optional Goal associated with this list.
    ///   - intervals: An optional array of Interval items. Defaults to empty.
    public init(list: IntervalList,
        orderIndex: Int = 0,
        goal: GoalSession? = nil
    ) {
        self.id = UUID().uuidString
        self.orderIndex = orderIndex
        self.session = goal
        self.list = list
        var intervals = [IntervalSession]()
        for interval in list.intervals ?? [] {
            let intervalSession = IntervalSession(interval: interval)
            intervalSession.listSession = self
            intervals.append(intervalSession)
        }
        
        self.intervals = intervals
    }
    
    public func contains(id: String) -> Bool {
        intervals?.contains(where: { $0.id == id }) ?? false
    }
}
