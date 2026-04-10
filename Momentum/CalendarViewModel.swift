//
//  CalendarViewModel.swift
//  Momentum
//
//  ViewModel for calendar event management
//

import Foundation
import EventKit

/// ViewModel handling calendar event state
@Observable
class CalendarViewModel {
    // MARK: - Dependencies
    
    private let calendarEventStore: EKEventStore
    
    // MARK: - State
    
    /// Next calendar event
    var nextCalendarEvent: EKEvent?
    
    // MARK: - Initialization
    
    init(calendarEventStore: EKEventStore) {
        self.calendarEventStore = calendarEventStore
    }
    
    // MARK: - Calendar Operations
    
    /// Fetch the next calendar event
    func fetchNextCalendarEvent() {
        // TODO: Implement calendar event fetching
        // This would query the calendar event store for upcoming events
    }
}
