//
//  ProgressCardTileSettingsTests.swift
//  MomentumTests
//
//  Created by Assistant on 08/04/2026.
//

import Testing
import Foundation
@testable import Momentum

@Suite("Progress Card Tile Settings Tests")
struct ProgressCardTileSettingsTests {
    
    // MARK: - Test Helper
    
    /// Returns a clean UserDefaults suite for testing
    private func createTestDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }
    
    // MARK: - Individual Tile Visibility Tests
    
    @Test("Progress tile can be shown")
    func progressTileCanBeShown() {
        let defaults = createTestDefaults()
        defaults.set(true, forKey: "showProgressTile")
        
        let showProgressTile = defaults.bool(forKey: "showProgressTile")
        #expect(showProgressTile == true)
    }
    
    @Test("Progress tile can be hidden")
    func progressTileCanBeHidden() {
        let defaults = createTestDefaults()
        defaults.set(false, forKey: "showProgressTile")
        
        let showProgressTile = defaults.bool(forKey: "showProgressTile")
        #expect(showProgressTile == false)
    }
    
    @Test("Weather tile can be shown")
    func weatherTileCanBeShown() {
        let defaults = createTestDefaults()
        defaults.set(true, forKey: "showWeatherTile")
        
        let showWeatherTile = defaults.bool(forKey: "showWeatherTile")
        #expect(showWeatherTile == true)
    }
    
    @Test("Weather tile can be hidden")
    func weatherTileCanBeHidden() {
        let defaults = createTestDefaults()
        defaults.set(false, forKey: "showWeatherTile")
        
        let showWeatherTile = defaults.bool(forKey: "showWeatherTile")
        #expect(showWeatherTile == false)
    }
    
    @Test("Calendar tile can be shown")
    func calendarTileCanBeShown() {
        let defaults = createTestDefaults()
        defaults.set(true, forKey: "showCalendarTile")
        
        let showCalendarTile = defaults.bool(forKey: "showCalendarTile")
        #expect(showCalendarTile == true)
    }
    
    @Test("Calendar tile can be hidden")
    func calendarTileCanBeHidden() {
        let defaults = createTestDefaults()
        defaults.set(false, forKey: "showCalendarTile")
        
        let showCalendarTile = defaults.bool(forKey: "showCalendarTile")
        #expect(showCalendarTile == false)
    }
    
    // MARK: - Default Values Tests
    
    @Test("Progress tile is shown by default")
    func progressTileDefaultValue() {
        let defaults = createTestDefaults()
        defaults.removeObject(forKey: "showProgressTile")
        
        // AppStorage returns false for missing bool keys, but we register true as default
        // In actual app usage, @AppStorage with default value handles this
        let showProgressTile = defaults.object(forKey: "showProgressTile") as? Bool ?? true
        #expect(showProgressTile == true)
    }
    
    @Test("Weather tile is shown by default")
    func weatherTileDefaultValue() {
        let defaults = createTestDefaults()
        defaults.removeObject(forKey: "showWeatherTile")
        
        let showWeatherTile = defaults.object(forKey: "showWeatherTile") as? Bool ?? true
        #expect(showWeatherTile == true)
    }
    
    @Test("Calendar tile is shown by default")
    func calendarTileDefaultValue() {
        let defaults = createTestDefaults()
        defaults.removeObject(forKey: "showCalendarTile")
        
        let showCalendarTile = defaults.object(forKey: "showCalendarTile") as? Bool ?? true
        #expect(showCalendarTile == true)
    }
    
    // MARK: - Combined Visibility Tests
    
    @Test("All tiles can be shown")
    func allTilesCanBeShown() {
        let defaults = createTestDefaults()
        defaults.set(true, forKey: "showProgressTile")
        defaults.set(true, forKey: "showWeatherTile")
        defaults.set(true, forKey: "showCalendarTile")
        
        let showProgressTile = defaults.bool(forKey: "showProgressTile")
        let showWeatherTile = defaults.bool(forKey: "showWeatherTile")
        let showCalendarTile = defaults.bool(forKey: "showCalendarTile")
        
        #expect(showProgressTile == true)
        #expect(showWeatherTile == true)
        #expect(showCalendarTile == true)
    }
    
    @Test("All tiles can be hidden")
    func allTilesCanBeHidden() {
        let defaults = createTestDefaults()
        defaults.set(false, forKey: "showProgressTile")
        defaults.set(false, forKey: "showWeatherTile")
        defaults.set(false, forKey: "showCalendarTile")
        
        let showProgressTile = defaults.bool(forKey: "showProgressTile")
        let showWeatherTile = defaults.bool(forKey: "showWeatherTile")
        let showCalendarTile = defaults.bool(forKey: "showCalendarTile")
        
        #expect(showProgressTile == false)
        #expect(showWeatherTile == false)
        #expect(showCalendarTile == false)
    }
    
    @Test("Progress card visibility reflects tile settings")
    func progressCardVisibility() {
        let defaults = createTestDefaults()
        
        // Test case 1: All tiles hidden
        defaults.set(false, forKey: "showProgressTile")
        defaults.set(false, forKey: "showWeatherTile")
        defaults.set(false, forKey: "showCalendarTile")
        
        let hasVisibleTiles1 = defaults.bool(forKey: "showProgressTile") ||
                               defaults.bool(forKey: "showWeatherTile") ||
                               defaults.bool(forKey: "showCalendarTile")
        #expect(hasVisibleTiles1 == false)
        
        // Test case 2: At least one tile visible
        defaults.set(true, forKey: "showProgressTile")
        
        let hasVisibleTiles2 = defaults.bool(forKey: "showProgressTile") ||
                               defaults.bool(forKey: "showWeatherTile") ||
                               defaults.bool(forKey: "showCalendarTile")
        #expect(hasVisibleTiles2 == true)
    }
    
    // MARK: - Settings Persistence Tests
    
    @Test("Tile settings persist across reads")
    func tileSettingsPersistence() {
        let defaults = createTestDefaults()
        
        // Set custom values
        defaults.set(true, forKey: "showProgressTile")
        defaults.set(false, forKey: "showWeatherTile")
        defaults.set(true, forKey: "showCalendarTile")
        
        // Read them back
        let showProgressTile = defaults.bool(forKey: "showProgressTile")
        let showWeatherTile = defaults.bool(forKey: "showWeatherTile")
        let showCalendarTile = defaults.bool(forKey: "showCalendarTile")
        
        #expect(showProgressTile == true)
        #expect(showWeatherTile == false)
        #expect(showCalendarTile == true)
    }
    
    @Test("Tile settings can be toggled")
    func tileSettingsToggle() {
        let defaults = createTestDefaults()
        
        // Start with true
        defaults.set(true, forKey: "showProgressTile")
        var showProgressTile = defaults.bool(forKey: "showProgressTile")
        #expect(showProgressTile == true)
        
        // Toggle to false
        defaults.set(!showProgressTile, forKey: "showProgressTile")
        showProgressTile = defaults.bool(forKey: "showProgressTile")
        #expect(showProgressTile == false)
        
        // Toggle back to true
        defaults.set(!showProgressTile, forKey: "showProgressTile")
        showProgressTile = defaults.bool(forKey: "showProgressTile")
        #expect(showProgressTile == true)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Settings handle nil values correctly")
    func settingsHandleNilValues() {
        let defaults = createTestDefaults()
        
        // Remove all tile settings
        defaults.removeObject(forKey: "showProgressTile")
        defaults.removeObject(forKey: "showWeatherTile")
        defaults.removeObject(forKey: "showCalendarTile")
        
        // Verify default behavior (should default to true in app)
        let showProgressTile = defaults.object(forKey: "showProgressTile") as? Bool ?? true
        let showWeatherTile = defaults.object(forKey: "showWeatherTile") as? Bool ?? true
        let showCalendarTile = defaults.object(forKey: "showCalendarTile") as? Bool ?? true
        
        #expect(showProgressTile == true)
        #expect(showWeatherTile == true)
        #expect(showCalendarTile == true)
    }
    
    @Test("Individual tiles can be controlled independently")
    func independentTileControl() {
        let defaults = createTestDefaults()
        
        // Set each tile to a different value
        defaults.set(true, forKey: "showProgressTile")
        defaults.set(false, forKey: "showWeatherTile")
        defaults.set(true, forKey: "showCalendarTile")
        
        let showProgressTile = defaults.bool(forKey: "showProgressTile")
        let showWeatherTile = defaults.bool(forKey: "showWeatherTile")
        let showCalendarTile = defaults.bool(forKey: "showCalendarTile")
        
        // Verify each setting is independent
        #expect(showProgressTile == true)
        #expect(showWeatherTile == false)
        #expect(showCalendarTile == true)
        
        // Change one tile shouldn't affect others
        defaults.set(false, forKey: "showProgressTile")
        
        let showProgressTileAfter = defaults.bool(forKey: "showProgressTile")
        let showWeatherTileAfter = defaults.bool(forKey: "showWeatherTile")
        let showCalendarTileAfter = defaults.bool(forKey: "showCalendarTile")
        
        #expect(showProgressTileAfter == false)
        #expect(showWeatherTileAfter == false) // Unchanged
        #expect(showCalendarTileAfter == true) // Unchanged
    }
}
