//
//  UITestHelpers.swift
//  MomentumUITests
//
//  Created by Assistant on 07/03/2026.
//

import XCTest

/// Helper class for UI test utilities and common operations
class UITestHelpers {
    
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - Test Data Setup
    
    /// Launch app with fresh test data
    func launchWithFreshData() {
        app.launchArguments = [
            "UI-Testing",
            "RESET-DATA" // Signal to reset all data
        ]
        app.launch()
    }
    
    /// Launch app with sample test data
    func launchWithSampleData() {
        app.launchArguments = [
            "UI-Testing",
            "SAMPLE-DATA" // Signal to populate sample data
        ]
        app.launch()
    }
    
    /// Launch app preserving existing data
    func launchPreservingData() {
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    // MARK: - Navigation Helpers
    
    func navigateToSettings() {
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'settings' OR identifier CONTAINS 'settings'")).firstMatch
        if settingsButton.exists {
            settingsButton.tap()
        }
    }
    
    func dismissSettings() {
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
    
    func navigateToAllGoals() {
        let allGoalsButton = app.buttons["All Goals"]
        if allGoalsButton.exists {
            allGoalsButton.tap()
        }
    }
    
    func navigateBack() {
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
    
    // MARK: - Goal Helpers
    
    @discardableResult
    func createGoal(title: String, weeklyTarget: String? = nil) -> Bool {
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR identifier CONTAINS 'add'")).firstMatch
        
        guard addButton.exists else {
            return false
        }
        
        addButton.tap()
        
        let titleField = app.textFields.firstMatch
        guard titleField.waitForExistence(timeout: 2) else {
            return false
        }
        
        titleField.tap()
        titleField.typeText(title)
        
        if let target = weeklyTarget {
            let targetFields = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'target'"))
            if targetFields.count > 0 {
                targetFields.firstMatch.tap()
                targetFields.firstMatch.typeText(target)
            }
        }
        
        saveCurrentSheet()
        
        return app.staticTexts[title].waitForExistence(timeout: 2)
    }
    
    func deleteGoal(title: String) -> Bool {
        let goalRow = findGoalRow(title: title)
        guard goalRow.exists else {
            return false
        }
        
        goalRow.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        guard deleteButton.waitForExistence(timeout: 1) else {
            return false
        }
        
        deleteButton.tap()
        
        // Confirm if needed
        if app.buttons["Confirm"].exists {
            app.buttons["Confirm"].tap()
        }
        
        return !app.staticTexts[title].exists
    }
    
    func findGoalRow(title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }
    
    // MARK: - Session Helpers
    
    func findFirstSession() -> XCUIElement? {
        let sessionRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session' OR identifier CONTAINS 'goal'"))
        return sessionRows.count > 0 ? sessionRows.firstMatch : nil
    }
    
    func startSession(at index: Int = 0) -> Bool {
        let sessions = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session'"))
        
        guard sessions.count > index else {
            return false
        }
        
        sessions.element(boundBy: index).tap()
        
        let startButton = app.buttons["Start"]
        guard startButton.waitForExistence(timeout: 2) else {
            return false
        }
        
        startButton.tap()
        
        // Verify session started
        return app.buttons["Stop"].exists || app.buttons["Pause"].exists
    }
    
    func stopCurrentSession() -> Bool {
        let stopButton = app.buttons["Stop"]
        guard stopButton.exists else {
            return false
        }
        
        stopButton.tap()
        return true
    }
    
    // MARK: - Common Actions
    
    func saveCurrentSheet() {
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
        if saveButton.exists {
            saveButton.tap()
        }
    }
    
    func cancelCurrentSheet() {
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            app.swipeDown() // Dismiss via gesture
        }
    }
    
    func dismissKeyboard() {
        app.keyboards.buttons["Done"].tap()
    }
    
    // MARK: - Wait Helpers
    
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
    
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // MARK: - Assertion Helpers
    
    func assertElementExists(_ element: XCUIElement, timeout: TimeInterval = 2, message: String = "Element should exist") {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
    }
    
    func assertElementDoesNotExist(_ element: XCUIElement, message: String = "Element should not exist") {
        XCTAssertFalse(element.exists, message)
    }
    
    // MARK: - Screenshot Helpers
    
    func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
            activity.add(attachment)
        }
    }
    
    // MARK: - Search Helpers
    
    func performSearch(query: String) -> Bool {
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search' OR identifier CONTAINS 'search'")).firstMatch
        
        guard searchButton.exists else {
            return false
        }
        
        searchButton.tap()
        
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 2) else {
            return false
        }
        
        searchField.tap()
        searchField.typeText(query)
        
        return true
    }
    
    func clearSearch() {
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
        }
    }
    
    func dismissSearch() {
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
    }
    
    // MARK: - Filter Helpers
    
    func selectFilter(named filterName: String) -> Bool {
        let filterButton = app.buttons[filterName]
        guard filterButton.exists else {
            return false
        }
        
        filterButton.tap()
        return true
    }
    
    // MARK: - Cleanup Helpers
    
    func cleanupTestGoals() {
        // Delete any goals starting with "Test" or "UI Test"
        let testGoalPrefixes = ["Test", "UI Test", "Automation"]
        
        for prefix in testGoalPrefixes {
            let testGoals = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            
            for i in 0..<testGoals.count {
                let goal = testGoals.element(boundBy: i)
                if goal.exists {
                    _ = deleteGoal(title: goal.label)
                }
            }
        }
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Safely tap an element if it exists
    func tapIfExists() -> Bool {
        if exists && isHittable {
            tap()
            return true
        }
        return false
    }
    
    /// Type text if element exists and is a text field
    func typeTextIfExists(_ text: String) -> Bool {
        if exists {
            tap()
            typeText(text)
            return true
        }
        return false
    }
    
    /// Clear text and type new text
    func clearAndType(_ text: String) {
        guard exists else { return }
        
        tap()
        
        // Select all and delete
        if let stringValue = value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            typeText(deleteString)
        }
        
        typeText(text)
    }
}
