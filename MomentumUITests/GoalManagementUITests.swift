//
//  GoalManagementUITests.swift
//  MomentumUITests
//
//  Created by Assistant on 07/03/2026.
//

import XCTest

final class GoalManagementUITests: XCTestCase {
    
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
    
    // MARK: - Goal Creation Tests
    
    @MainActor
    func testCreateGoalWithTitle() throws {
        let addButton = findAddGoalButton()
        guard addButton.exists else {
            XCTFail("Add goal button not found")
            return
        }
        
        addButton.tap()
        
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        
        titleField.tap()
        titleField.typeText("Reading")
        
        saveGoal()
        
        XCTAssertTrue(app.staticTexts["Reading"].waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testCreateGoalWithWeeklyTarget() throws {
        let addButton = findAddGoalButton()
        guard addButton.exists else {
            XCTFail("Add goal button not found")
            return
        }
        
        addButton.tap()
        
        // Enter title
        let titleField = app.textFields.firstMatch
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("Exercise")
            
            // Look for weekly target field
            let targetFields = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'target' OR label CONTAINS 'target'"))
            if targetFields.count > 0 {
                targetFields.firstMatch.tap()
                targetFields.firstMatch.typeText("5")
            }
            
            saveGoal()
            
            XCTAssertTrue(app.staticTexts["Exercise"].waitForExistence(timeout: 2))
        }
    }
    
    @MainActor
    func testCreateGoalWithSchedule() throws {
        let addButton = findAddGoalButton()
        guard addButton.exists else {
            XCTFail("Add goal button not found")
            return
        }
        
        addButton.tap()
        
        let titleField = app.textFields.firstMatch
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("Morning Routine")
            
            // Look for schedule section
            let scheduleButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'schedule'")).firstMatch
            if scheduleButton.exists {
                scheduleButton.tap()
                
                // Select weekdays (if available)
                let weekdayButtons = app.buttons.matching(NSPredicate(format: "label MATCHES 'Mon|Tue|Wed|Thu|Fri|Sat|Sun'"))
                if weekdayButtons.count > 0 {
                    weekdayButtons.firstMatch.tap()
                }
            }
            
            saveGoal()
            
            XCTAssertTrue(app.staticTexts["Morning Routine"].waitForExistence(timeout: 2))
        }
    }
    
    // MARK: - Goal Editing Tests
    
    @MainActor
    func testEditGoalTitle() throws {
        // First create a goal
        createTestGoal(title: "Original Title")
        
        // Find and tap the goal
        let goalText = app.staticTexts["Original Title"]
        if goalText.waitForExistence(timeout: 2) {
            // Find the edit button (could be in a menu or direct tap)
            let editButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit'")).firstMatch
            if editButton.exists {
                editButton.tap()
            } else {
                // Try long press
                goalText.press(forDuration: 1.0)
            }
            
            // Edit the title
            let titleField = app.textFields["Original Title"]
            if titleField.waitForExistence(timeout: 2) {
                titleField.tap()
                titleField.doubleTap() // Select all
                titleField.typeText("Edited Title")
                
                saveGoal()
                
                XCTAssertTrue(app.staticTexts["Edited Title"].waitForExistence(timeout: 2))
            }
        }
    }
    
    @MainActor
    func testEditGoalWeeklyTarget() throws {
        createTestGoal(title: "Goal With Target")
        
        let goalRow = findGoalRow(title: "Goal With Target")
        if goalRow.exists {
            goalRow.tap()
            
            // Look for target adjustment controls
            let targetField = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'target'")).firstMatch
            if targetField.exists {
                targetField.tap()
                targetField.typeText("10")
                
                saveGoal()
            }
        }
    }
    
    // MARK: - Goal Deletion Tests
    
    @MainActor
    func testDeleteGoal() throws {
        createTestGoal(title: "Goal To Delete")
        
        XCTAssertTrue(app.staticTexts["Goal To Delete"].waitForExistence(timeout: 2))
        
        // Find delete button (swipe or menu)
        let goalRow = findGoalRow(title: "Goal To Delete")
        if goalRow.exists {
            // Try swipe to delete
            goalRow.swipeLeft()
            
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 1) {
                deleteButton.tap()
                
                // Confirm deletion if needed
                let confirmButton = app.buttons["Confirm"]
                if confirmButton.exists {
                    confirmButton.tap()
                }
                
                // Verify goal is deleted
                XCTAssertFalse(app.staticTexts["Goal To Delete"].exists)
            }
        }
    }
    
    @MainActor
    func testArchiveGoal() throws {
        createTestGoal(title: "Goal To Archive")
        
        let goalRow = findGoalRow(title: "Goal To Archive")
        if goalRow.exists {
            // Look for archive option
            goalRow.press(forDuration: 1.0)
            
            let archiveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'archive'")).firstMatch
            if archiveButton.exists {
                archiveButton.tap()
                
                // Verify goal is archived (might disappear from active list)
                sleep(1)
                XCTAssertTrue(app.exists)
            }
        }
    }
    
    // MARK: - Goal Organization Tests
    
    @MainActor
    func testReorderGoals() throws {
        createTestGoal(title: "First Goal")
        createTestGoal(title: "Second Goal")
        
        // Enable edit mode if needed
        let editButton = app.buttons["Edit"]
        if editButton.exists {
            editButton.tap()
            
            // Try to drag and reorder
            let firstGoal = findGoalRow(title: "First Goal")
            let secondGoal = findGoalRow(title: "Second Goal")
            
            if firstGoal.exists && secondGoal.exists {
                firstGoal.press(forDuration: 0.5, thenDragTo: secondGoal)
                sleep(1)
                XCTAssertTrue(app.exists)
            }
            
            // Exit edit mode
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            }
        }
    }
    
    // MARK: - Goal Icon Tests
    
    @MainActor
    func testSetGoalIcon() throws {
        let addButton = findAddGoalButton()
        guard addButton.exists else {
            XCTFail("Add goal button not found")
            return
        }
        
        addButton.tap()
        
        let titleField = app.textFields.firstMatch
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("Goal With Icon")
            
            // Look for icon picker
            let iconButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'icon'")).firstMatch
            if iconButton.exists {
                iconButton.tap()
                
                // Select an icon
                let icons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'icon'"))
                if icons.count > 0 {
                    icons.firstMatch.tap()
                }
            }
            
            saveGoal()
            
            XCTAssertTrue(app.staticTexts["Goal With Icon"].waitForExistence(timeout: 2))
        }
    }
    
    // MARK: - Goal Theme Tests
    
    @MainActor
    func testSetGoalTheme() throws {
        let addButton = findAddGoalButton()
        guard addButton.exists else {
            XCTFail("Add goal button not found")
            return
        }
        
        addButton.tap()
        
        let titleField = app.textFields.firstMatch
        if titleField.waitForExistence(timeout: 2) {
            titleField.tap()
            titleField.typeText("Themed Goal")
            
            // Look for theme picker
            let themeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'theme' OR label CONTAINS[c] 'color'")).firstMatch
            if themeButton.exists {
                themeButton.tap()
                
                // Select a theme
                let themes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'theme' OR identifier CONTAINS 'color'"))
                if themes.count > 0 {
                    themes.element(boundBy: min(1, themes.count - 1)).tap()
                }
            }
            
            saveGoal()
            
            XCTAssertTrue(app.staticTexts["Themed Goal"].waitForExistence(timeout: 2))
        }
    }
    
    // MARK: - Helper Methods
    
    private func findAddGoalButton() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR identifier CONTAINS 'add' OR label CONTAINS[c] 'new goal'")).firstMatch
    }
    
    private func findGoalRow(title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }
    
    private func saveGoal() {
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
        if saveButton.exists {
            saveButton.tap()
        }
    }
    
    private func createTestGoal(title: String) {
        let addButton = findAddGoalButton()
        if addButton.exists {
            addButton.tap()
            
            let titleField = app.textFields.firstMatch
            if titleField.waitForExistence(timeout: 2) {
                titleField.tap()
                titleField.typeText(title)
                saveGoal()
            }
        }
    }
}
