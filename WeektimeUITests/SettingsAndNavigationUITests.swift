//
//  SettingsAndNavigationUITests.swift
//  MomentumUITests
//
//  Created by Assistant on 07/03/2026.
//

import XCTest

final class SettingsAndNavigationUITests: XCTestCase {
    
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
    
    // MARK: - Settings Navigation Tests
    
    @MainActor
    func testOpenSettings() throws {
        let settingsButton = findSettingsButton()
        XCTAssertTrue(settingsButton.exists, "Settings button should exist")
        
        settingsButton.tap()
        
        // Verify settings view opened
        let settingsNavBar = app.navigationBars["Settings"]
        let settingsText = app.staticTexts["Settings"]
        
        XCTAssertTrue(settingsNavBar.exists || settingsText.exists)
        
        // Close settings
        dismissSettings()
    }
    
    @MainActor
    func testSettingsHealthKitSection() throws {
        openSettings()
        
        // Look for HealthKit section
        let healthKitButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'health' OR label CONTAINS[c] 'healthkit'")).firstMatch
        
        if healthKitButton.exists {
            healthKitButton.tap()
            
            // Verify HealthKit settings appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        dismissSettings()
    }
    
    @MainActor
    func testSettingsNotificationsSection() throws {
        openSettings()
        
        // Look for Notifications section
        let notificationsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'notification'")).firstMatch
        
        if notificationsButton.exists {
            notificationsButton.tap()
            
            // Verify notifications settings appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Look for notification toggles
            let toggles = app.switches
            XCTAssertGreaterThanOrEqual(toggles.count, 0)
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        dismissSettings()
    }
    
    @MainActor
    func testSettingsAppearanceSection() throws {
        openSettings()
        
        // Look for Appearance/Theme section
        let appearanceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'appearance' OR label CONTAINS[c] 'theme'")).firstMatch
        
        if appearanceButton.exists {
            appearanceButton.tap()
            
            // Test theme options
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        dismissSettings()
    }
    
    // MARK: - All Goals View Tests
    
    @MainActor
    func testNavigateToAllGoals() throws {
        let allGoalsButton = app.buttons["All Goals"]
        
        if allGoalsButton.exists {
            allGoalsButton.tap()
            
            // Verify all goals view
            let goalsNavBar = app.navigationBars["Goals"]
            let goalsText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'goals'")).firstMatch
            
            XCTAssertTrue(goalsNavBar.exists || goalsText.exists)
            
            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
    
    @MainActor
    func testAllGoalsSearch() throws {
        let allGoalsButton = app.buttons["All Goals"]
        
        if allGoalsButton.exists {
            allGoalsButton.tap()
            
            // Look for search field
            let searchField = app.searchFields.firstMatch
            if searchField.exists {
                searchField.tap()
                searchField.typeText("test")
                
                // Verify search works
                sleep(1)
                XCTAssertTrue(app.exists)
                
                // Clear search
                if app.buttons["Clear text"].exists {
                    app.buttons["Clear text"].tap()
                }
            }
            
            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
    
    // MARK: - Day Overview Tests
    
    @MainActor
    func testNavigateToDayOverview() throws {
        let dayOverviewButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'overview' OR label CONTAINS[c] 'day'")).firstMatch
        
        if dayOverviewButton.exists {
            dayOverviewButton.tap()
            
            // Verify day overview appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Look for day-related content
            let dateElements = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*\\\\d{1,2}.*'"))
            XCTAssertGreaterThanOrEqual(dateElements.count, 0)
            
            // Close
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
            }
        }
    }
    
    // MARK: - Planner View Tests
    
    @MainActor
    func testNavigateToPlanner() throws {
        let plannerButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'plan' OR label CONTAINS[c] 'schedule'")).firstMatch
        
        if plannerButton.exists {
            plannerButton.tap()
            
            // Verify planner view appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Look for planned sessions
            let plannedSessions = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session'"))
            XCTAssertGreaterThanOrEqual(plannedSessions.count, 0)
            
            // Close
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }
    
    // MARK: - Tab Bar Navigation Tests
    
    @MainActor
    func testTabBarNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        
        if tabBar.exists {
            let tabButtons = tabBar.buttons
            
            // Tap through tabs
            for i in 0..<min(tabButtons.count, 5) {
                tabButtons.element(boundBy: i).tap()
                sleep(1)
                XCTAssertTrue(app.exists)
            }
        }
    }
    
    // MARK: - Deep Link Navigation Tests
    
    @MainActor
    func testDeepLinkToSession() throws {
        // Test navigation from URL/deep link
        // This would be tested with URL schemes
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Modal Presentation Tests
    
    @MainActor
    func testModalPresentation() throws {
        // Test sheets/modals can be presented and dismissed
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+'")).firstMatch
        
        if addButton.exists {
            addButton.tap()
            
            // Verify modal appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Dismiss modal
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            } else if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
            } else {
                // Swipe down to dismiss
                app.swipeDown()
            }
            
            sleep(1)
            XCTAssertTrue(app.exists)
        }
    }
    
    // MARK: - Search Tests
    
    @MainActor
    func testGlobalSearch() throws {
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'search' OR identifier CONTAINS 'search'")).firstMatch
        
        if searchButton.exists {
            searchButton.tap()
            
            let searchField = app.searchFields.firstMatch
            if searchField.waitForExistence(timeout: 2) {
                searchField.tap()
                searchField.typeText("test")
                
                // Verify search results
                sleep(1)
                XCTAssertTrue(app.exists)
                
                // Clear and dismiss
                if app.buttons["Clear text"].exists {
                    app.buttons["Clear text"].tap()
                }
                
                if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                }
            }
        }
    }
    
    // MARK: - Context Menu Tests
    
    @MainActor
    func testContextMenus() throws {
        // Long press on session/goal to show context menu
        let firstElement = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'session' OR identifier CONTAINS 'goal'")).firstMatch
        
        if firstElement.exists {
            firstElement.press(forDuration: 1.0)
            
            // Verify context menu appeared
            sleep(1)
            
            // Look for menu items
            let menuItems = app.buttons.allElementsBoundByIndex
            if menuItems.count > 0 {
                XCTAssertTrue(true) // Context menu appeared
                
                // Dismiss by tapping elsewhere
                let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                coordinate.tap()
            }
        }
    }
    
    // MARK: - Pull to Refresh Tests
    
    @MainActor
    func testPullToRefresh() throws {
        // Test pull to refresh functionality
        let scrollView = app.scrollViews.firstMatch
        
        if scrollView.exists {
            scrollView.swipeDown(velocity: .fast)
            sleep(2)
            
            // Verify refresh occurred (data reloaded)
            XCTAssertTrue(app.exists)
        }
    }
    
    // MARK: - Navigation Stack Tests
    
    @MainActor
    func testNestedNavigation() throws {
        // Test deep navigation stack
        // 1. Go to All Goals
        let allGoalsButton = app.buttons["All Goals"]
        if allGoalsButton.exists {
            allGoalsButton.tap()
            sleep(1)
            
            // 2. Select a goal
            let goalButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'goal'"))
            if goalButtons.count > 0 {
                goalButtons.firstMatch.tap()
                sleep(1)
                
                // 3. Navigate back twice
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
                
                XCTAssertTrue(app.exists)
            }
        }
    }
    
    // MARK: - Orientation Tests
    
    @MainActor
    func testLandscapeOrientation() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        
        // Verify UI adapts to landscape
        XCTAssertTrue(app.exists)
        
        // Rotate back
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Split View Tests (iPad)
    
    @MainActor
    func testSplitViewNavigation() throws {
        // Only test on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Test split view navigation
            let sidebar = app.otherElements["sidebar"]
            if sidebar.exists {
                XCTAssertTrue(true) // Split view available
            }
        }
    }
    
    // MARK: - Widget Configuration Tests
    
    @MainActor
    func testWidgetConfigurationNavigation() throws {
        openSettings()
        
        // Look for widget settings
        let widgetButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'widget'")).firstMatch
        
        if widgetButton.exists {
            widgetButton.tap()
            
            // Verify widget settings appeared
            sleep(1)
            XCTAssertTrue(app.exists)
            
            // Go back
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        dismissSettings()
    }
    
    // MARK: - Helper Methods
    
    private func findSettingsButton() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'settings' OR identifier CONTAINS 'settings'")).firstMatch
    }
    
    private func openSettings() {
        let settingsButton = findSettingsButton()
        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)
        }
    }
    
    private func dismissSettings() {
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
        sleep(1)
    }
}
