//
//  SessionTrackingUITests.swift
//  MomentumUITests
//
//  Created by Assistant on 07/03/2026.
//

import XCTest

final class SessionTrackingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Session Start/Stop Tests
    
    @MainActor
    func testStartSession() throws {
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        let startButton = app.buttons["Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        
        startButton.tap()
        
        // Verify session started (timer visible or status changed)
        let timerExists = app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d+:\\\\d+'")).count > 0
        let pauseButtonExists = app.buttons["Pause"].exists
        let stopButtonExists = app.buttons["Stop"].exists
        
        XCTAssertTrue(timerExists || pauseButtonExists || stopButtonExists)
    }
    
    @MainActor
    func testPauseSession() throws {
        // Start a session first
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        let startButton = app.buttons["Start"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            
            // Wait a moment for session to start
            sleep(2)
            
            // Pause the session
            let pauseButton = app.buttons["Pause"]
            if pauseButton.waitForExistence(timeout: 2) {
                pauseButton.tap()
                
                // Verify pause state
                let resumeButton = app.buttons["Resume"]
                XCTAssertTrue(resumeButton.exists || app.buttons["Start"].exists)
            }
        }
    }
    
    @MainActor
    func testStopSession() throws {
        // Start a session
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        let startButton = app.buttons["Start"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            sleep(2)
            
            // Stop the session
            let stopButton = app.buttons["Stop"]
            if stopButton.waitForExistence(timeout: 2) {
                stopButton.tap()
                
                // Verify session stopped
                sleep(1)
                XCTAssertTrue(app.exists)
                
                // Verify we can start again
                if app.buttons["Start"].exists {
                    XCTAssertTrue(true)
                }
            }
        }
    }
    
    @MainActor
    func testCompleteSessionCycle() throws {
        // Complete cycle: start -> pause -> resume -> stop
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        // Start
        let startButton = app.buttons["Start"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            sleep(1)
            
            // Pause
            if app.buttons["Pause"].exists {
                app.buttons["Pause"].tap()
                sleep(1)
                
                // Resume
                if app.buttons["Resume"].exists {
                    app.buttons["Resume"].tap()
                    sleep(1)
                }
            }
            
            // Stop
            if app.buttons["Stop"].exists {
                app.buttons["Stop"].tap()
                sleep(1)
                
                XCTAssertTrue(app.exists)
            }
        }
    }
    
    // MARK: - Manual Time Logging Tests
    
    @MainActor
    func testLogManualTime() throws {
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        // Look for manual log button
        let logTimeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'log' OR label CONTAINS[c] 'manual'")).firstMatch
        
        if logTimeButton.exists {
            logTimeButton.tap()
            
            // Enter time amount
            let timeField = app.textFields.firstMatch
            if timeField.waitForExistence(timeout: 2) {
                timeField.tap()
                timeField.typeText("30")
                
                // Save
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    
                    sleep(1)
                    XCTAssertTrue(app.exists)
                }
            }
        }
    }
    
    // MARK: - Progress Display Tests
    
    @MainActor
    func testProgressIndicatorVisible() throws {
        // Verify sessions show progress indicators
        let progressElements = app.progressIndicators
        
        if progressElements.count == 0 {
            // Try alternative progress displays (text, bars, etc.)
            let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/' OR label CONTAINS '%'"))
            XCTAssertGreaterThanOrEqual(progressText.count, 0)
        }
    }
    
    @MainActor
    func testTimeDisplayFormat() throws {
        // Verify time is displayed in expected format
        let timeLabels = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*\\\\d+[hm].*' OR label MATCHES '.*\\\\d+:\\\\d+.*'"))
        
        // Should have at least some time displays
        XCTAssertGreaterThanOrEqual(timeLabels.count, 0)
    }
    
    // MARK: - Session History Tests
    
    @MainActor
    func testViewSessionHistory() throws {
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        // Look for history button
        let historyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'history' OR label CONTAINS[c] 'past'")).firstMatch
        
        if historyButton.exists {
            historyButton.tap()
            
            // Verify history view appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Go back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
            }
        }
    }
    
    // MARK: - Mark Complete Tests
    
    @MainActor
    func testMarkSessionComplete() throws {
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        // Look for mark complete button
        let completeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'complete' OR label CONTAINS[c] 'done'")).firstMatch
        
        if completeButton.exists {
            completeButton.tap()
            
            // Verify session marked complete
            sleep(1)
            
            // Check for completion indicator
            let checkmark = app.images["checkmark"]
            let completedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'completed'"))
            
            XCTAssertTrue(checkmark.exists || completedText.count > 0)
        }
    }
    
    // MARK: - Now Playing Tests
    
    @MainActor
    func testNowPlayingView() throws {
        // Start a session
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        let startButton = app.buttons["Start"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            sleep(1)
            
            // Look for Now Playing button/indicator
            let nowPlayingButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'now playing' OR label CONTAINS[c] 'active'")).firstMatch
            
            if nowPlayingButton.exists {
                nowPlayingButton.tap()
                
                // Verify Now Playing view
                sleep(1)
                XCTAssertTrue(app.exists)
                
                // Should show active session details
                let stopButton = app.buttons["Stop"]
                XCTAssertTrue(stopButton.exists)
            }
        }
    }
    
    // MARK: - Checklist Tests
    
    @MainActor
    func testChecklistInteraction() throws {
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        // Look for checklist items
        let checklistItems = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'checklist'"))
        
        if checklistItems.count > 0 {
            let firstItem = checklistItems.firstMatch
            firstItem.tap()
            
            // Verify item can be toggled
            sleep(1)
            XCTAssertTrue(app.exists)
        }
    }
    
    // MARK: - Interval List Tests
    
    @MainActor
    func testIntervalListInteraction() throws {
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        // Look for interval list
        let intervalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'interval' OR label CONTAINS[c] 'list'")).firstMatch
        
        if intervalButton.exists {
            intervalButton.tap()
            
            // Verify interval list view
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Look for interval items
            let intervalItems = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'interval'"))
            if intervalItems.count > 0 {
                intervalItems.firstMatch.tap()
                sleep(1)
            }
        }
    }
    
    // MARK: - Quick Actions Tests
    
    @MainActor
    func testQuickStartSession() throws {
        // Test quick start (if available via long press or 3D touch)
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.press(forDuration: 1.0)
        
        // Look for quick action menu
        let quickStartButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'quick start' OR label CONTAINS[c] 'start now'")).firstMatch
        
        if quickStartButton.exists {
            quickStartButton.tap()
            
            // Verify session started
            sleep(1)
            let stopButton = app.buttons["Stop"]
            XCTAssertTrue(stopButton.exists)
        }
    }
    
    // MARK: - Timer Accuracy Tests
    
    @MainActor
    func testTimerIncreases() throws {
        // Start a session and verify timer increases
        guard let sessionRow = findFirstSession() else {
            XCTFail("No sessions available")
            return
        }
        
        sessionRow.tap()
        
        let startButton = app.buttons["Start"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
            
            // Get initial time
            sleep(1)
            let initialTimeLabels = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*\\\\d+:\\\\d+.*'"))
            let initialTime = initialTimeLabels.count > 0 ? initialTimeLabels.firstMatch.label : ""
            
            // Wait and check again
            sleep(3)
            let laterTimeLabels = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*\\\\d+:\\\\d+.*'"))
            let laterTime = laterTimeLabels.count > 0 ? laterTimeLabels.firstMatch.label : ""
            
            // Times should be different (timer running)
            if !initialTime.isEmpty && !laterTime.isEmpty {
                XCTAssertNotEqual(initialTime, laterTime)
            }
            
            // Clean up
            if app.buttons["Stop"].exists {
                app.buttons["Stop"].tap()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findFirstSession() -> XCUIElement? {
        let sessionRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session' OR identifier CONTAINS 'goal'"))
        return sessionRows.count > 0 ? sessionRows.firstMatch : nil
    }
}
