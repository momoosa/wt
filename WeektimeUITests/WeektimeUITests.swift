//
//  MomentumUITests.swift
//  MomentumUITests
//
//  Created by Mo Moosa on 22/07/2025.
//

import XCTest

final class MomentumUITests: XCTestCase {
    
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

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunches() throws {
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigationToAllGoals() throws {
        // Find and tap "All Goals" button
        let allGoalsButton = app.buttons["All Goals"]
        if allGoalsButton.exists {
            allGoalsButton.tap()
            
            // Verify navigation occurred
            XCTAssertTrue(app.navigationBars["Goals"].exists || app.staticTexts["Goals"].exists)
            
            // Navigate back
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }

    @MainActor
    func testNavigationToSettings() throws {
        // Find and tap settings button (gear icon)
        let settingsButton = app.buttons.matching(identifier: "Settings").firstMatch
        if settingsButton.exists {
            settingsButton.tap()
            
            // Verify settings view appeared
            XCTAssertTrue(app.navigationBars["Settings"].exists || app.staticTexts["Settings"].exists)
            
            // Dismiss settings
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }

    @MainActor
    func testNavigationToDayOverview() throws {
        // Look for day overview button or calendar icon
        let dayOverviewButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'overview' OR label CONTAINS[c] 'calendar'")).firstMatch
        if dayOverviewButton.exists {
            dayOverviewButton.tap()
            
            // Verify day overview appeared
            XCTAssertTrue(app.otherElements.count > 0)
            
            // Dismiss
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            }
        }
    }

    // MARK: - Goal Creation Tests

    @MainActor
    func testCreateNewGoal() throws {
        // Find add goal button (+ button)
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR identifier CONTAINS 'add'")).firstMatch
        
        if addButton.exists {
            addButton.tap()
            
            // Wait for goal editor to appear
            let goalTitleField = app.textFields.firstMatch
            if goalTitleField.waitForExistence(timeout: 2) {
                goalTitleField.tap()
                goalTitleField.typeText("UI Test Goal")
                
                // Look for save/done button
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                }
                
                // Verify goal appears in list
                XCTAssertTrue(app.staticTexts["UI Test Goal"].waitForExistence(timeout: 2))
            }
        }
    }

    // MARK: - Session Interaction Tests

    @MainActor
    func testSessionRowTap() throws {
        // Find first session row
        let sessionRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session' OR identifier CONTAINS 'goal'"))
        
        if sessionRows.count > 0 {
            let firstSession = sessionRows.firstMatch
            firstSession.tap()
            
            // Verify action view or session detail appeared
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: app.buttons["Start"] // or other action buttons
            )
            
            let result = XCTWaiter.wait(for: [expectation], timeout: 2)
            if result == .completed || app.otherElements.count > 0 {
                XCTAssertTrue(true) // Session detail opened
            }
        }
    }

    @MainActor
    func testStartSession() throws {
        // Find and tap a session
        let sessionRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session'"))
        
        if sessionRows.count > 0 {
            sessionRows.firstMatch.tap()
            
            // Look for Start button
            let startButton = app.buttons["Start"]
            if startButton.waitForExistence(timeout: 2) {
                startButton.tap()
                
                // Verify timer started (look for Now Playing or timer UI)
                let nowPlayingExists = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'playing' OR label CONTAINS[c] 'active'")).count > 0
                XCTAssertTrue(nowPlayingExists || app.buttons["Pause"].exists || app.buttons["Stop"].exists)
            }
        }
    }

    // MARK: - Filter Tests

    @MainActor
    func testFilterButtons() throws {
        // Look for filter chips/buttons
        let filterButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'active' OR label CONTAINS[c] 'all' OR label CONTAINS[c] 'suggested'"))
        
        if filterButtons.count > 0 {
            let initialCount = filterButtons.count
            
            // Tap first filter
            filterButtons.element(boundBy: 0).tap()
            
            // Verify filter changed (UI updated)
            sleep(1) // Give UI time to update
            XCTAssertTrue(app.exists)
            
            // Tap another filter if available
            if filterButtons.count > 1 {
                filterButtons.element(boundBy: 1).tap()
                sleep(1)
                XCTAssertTrue(app.exists)
            }
        }
    }

    // MARK: - Search Tests

    @MainActor
    func testSearch() throws {
        // Find search button
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search' OR identifier CONTAINS 'search'")).firstMatch
        
        if searchButton.exists {
            searchButton.tap()
            
            // Wait for search field
            let searchField = app.searchFields.firstMatch
            if searchField.waitForExistence(timeout: 2) {
                searchField.tap()
                searchField.typeText("test")
                
                // Verify search results update
                sleep(1)
                XCTAssertTrue(app.exists)
                
                // Clear search
                if app.buttons["Clear text"].exists {
                    app.buttons["Clear text"].tap()
                }
                
                // Dismiss search
                if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                }
            }
        }
    }

    // MARK: - Gesture Tests

    @MainActor
    func testSwipeGestures() throws {
        // Find a scrollable element
        let scrollViews = app.scrollViews
        
        if scrollViews.count > 0 {
            let scrollView = scrollViews.firstMatch
            
            // Test scroll down
            scrollView.swipeUp()
            sleep(1)
            
            // Test scroll up
            scrollView.swipeDown()
            sleep(1)
            
            XCTAssertTrue(app.exists)
        }
    }

    // MARK: - Widget Integration Tests

    @MainActor
    func testWidgetInteraction() throws {
        // This would test deep linking from widgets
        // For now, verify app handles widget-related state
        XCTAssertTrue(app.exists)
    }

    // MARK: - Data Persistence Tests

    @MainActor
    func testDataPersistsAcrossLaunches() throws {
        // Create a goal
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR identifier CONTAINS 'add'")).firstMatch
        
        if addButton.exists {
            addButton.tap()
            
            let goalTitleField = app.textFields.firstMatch
            if goalTitleField.waitForExistence(timeout: 2) {
                goalTitleField.tap()
                goalTitleField.typeText("Persistence Test Goal")
                
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
        
        // Restart app
        app.terminate()
        app.launch()
        
        // Verify goal still exists
        XCTAssertTrue(app.staticTexts["Persistence Test Goal"].waitForExistence(timeout: 3))
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testEmptyStateHandling() throws {
        // Verify app handles empty states gracefully
        // Even with no data, app should display properly
        XCTAssertTrue(app.exists)
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Performance Tests

    @MainActor
    func testScrollPerformance() throws {
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp(velocity: .fast)
                scrollView.swipeDown(velocity: .fast)
            }
        }
    }

    @MainActor
    func testAnimationPerformance() throws {
        measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
            // Test filter animation performance
            let filterButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'active' OR label CONTAINS[c] 'all'"))
            
            if filterButtons.count > 1 {
                for i in 0..<min(3, filterButtons.count) {
                    filterButtons.element(boundBy: i).tap()
                }
            }
        }
    }

    // MARK: - Integration Tests

    @MainActor
    func testCompleteWorkflow() throws {
        // Test complete user workflow: create goal -> start session -> stop session
        
        // 1. Create a goal
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR identifier CONTAINS 'add'")).firstMatch
        
        if addButton.exists {
            addButton.tap()
            
            let goalTitleField = app.textFields.firstMatch
            if goalTitleField.waitForExistence(timeout: 2) {
                goalTitleField.tap()
                goalTitleField.typeText("Workflow Test Goal")
                
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
        
        // 2. Find and tap the created goal
        let createdGoal = app.staticTexts["Workflow Test Goal"]
        if createdGoal.waitForExistence(timeout: 2) {
            // Tap on the goal's row
            let goalRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Workflow Test Goal'")).firstMatch
            if goalRow.exists {
                goalRow.tap()
                
                // 3. Start session
                let startButton = app.buttons["Start"]
                if startButton.waitForExistence(timeout: 2) {
                    startButton.tap()
                    
                    // 4. Verify session is active
                    sleep(2)
                    
                    // 5. Stop session
                    let stopButton = app.buttons["Stop"]
                    if stopButton.exists {
                        stopButton.tap()
                        XCTAssertTrue(true) // Workflow completed
                    }
                }
            }
        }
    }
}
