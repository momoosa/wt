
import Foundation
import SwiftData

/// A model representing a named collection of Interval items associated to a Goal.
@Model
public final class IntervalSectionSession: Identifiable  {
    /// Unique identifier for the IntervalList.
    public var id: String
    /// The order index of the IntervalList.
    public var orderIndex: Int
    /// The Goal associated with this IntervalList.
    /// The collection of Interval items belonging to this list.
    public var section: IntervalSection
    public var intervals: [IntervalSession]

    public init(section: IntervalSection,
        orderIndex: Int = 0,
                intervals: [IntervalSession]) {
        self.id = UUID().uuidString
        self.orderIndex = orderIndex
        self.section = section
        var intervals = [IntervalSession]()
        for (index, interval) in section.intervals.enumerated() {
            let interval = IntervalSession(interval: interval)
            intervals.append(interval)
        }
        
        self.intervals = intervals
    }
    
    public func contains(id: String) -> Bool {
        intervals.contains(where: { $0.id == id })
    }
}
