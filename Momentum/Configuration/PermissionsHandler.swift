import FamilyControls
import Foundation
import Combine

@MainActor
class PermissionsHandler: ObservableObject {
    
    @Published var calendarAccessGranted = false
    @Published var screenTimeAccessGranted = false
    
    private let calendarManager = CalendarAvailabilityManager()
    
    /// Request all permissions at once
    func requestAllPermissions() async {
        await requestCalendarAccess()
        await requestScreentimeAuthorization()
    }
    
    /// Request calendar access for schedule flexibility
    func requestCalendarAccess() async {
        let granted = await calendarManager.requestAccess()
        calendarAccessGranted = granted
    }
    
    /// Check if calendar access is already granted
    func checkCalendarAccess() -> Bool {
        let granted = calendarManager.checkAuthorizationStatus()
        calendarAccessGranted = granted
        return granted
    }
    
    /// Get the calendar manager instance
    func getCalendarManager() -> CalendarAvailabilityManager {
        return calendarManager
    }
    
    func requestScreentimeAuthorization() async {
        // Note: ScreenTime authorization is handled by ScreenTimeManager when needed
        // Individual authorization requests are made on-demand per feature
    }
}
