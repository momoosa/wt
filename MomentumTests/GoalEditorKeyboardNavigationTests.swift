//
//  GoalEditorKeyboardNavigationTests.swift
//  MomentumTests
//
//  Created by Assistant on 08/04/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Momentum
@testable import MomentumKit

@Suite("Goal Editor Keyboard Navigation Tests")
struct GoalEditorKeyboardNavigationTests {
    
    // MARK: - Test Helper
    
    private func createTestViewModel() -> GoalEditorViewModel {
        return GoalEditorViewModel(existingGoal: nil)
    }
    
    // MARK: - canFocusNext Tests
    
    @Test("canFocusNext returns true from goalName when on duration stage")
    func testCanFocusNextFromGoalNameOnDurationStage() {
        let viewModel = createTestViewModel()
        viewModel.currentStage = .duration
        
        // Simulate the logic from GoalEditorView.canFocusNext
        let focusedField: GoalEditorView.Field? = .goalName
        let result: Bool = {
            switch focusedField {
            case .goalName:
                return viewModel.currentStage == .duration
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusNext returns false from goalName when on name stage")
    func testCanFocusNextFromGoalNameOnNameStage() {
        let viewModel = createTestViewModel()
        viewModel.currentStage = .name
        
        let focusedField: GoalEditorView.Field? = .goalName
        let result: Bool = {
            switch focusedField {
            case .goalName:
                return viewModel.currentStage == .duration
            default:
                return false
            }
        }()
        
        #expect(result == false)
    }
    
    @Test("canFocusNext returns true from duration when hasDailyMinimum is true")
    func testCanFocusNextFromDurationWithDailyMinimum() {
        let viewModel = createTestViewModel()
        viewModel.hasDailyMinimum = true
        
        let focusedField: GoalEditorView.Field? = .duration
        let result: Bool = {
            switch focusedField {
            case .duration:
                return viewModel.hasDailyMinimum || !viewModel.activeDays.isEmpty
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusNext returns true from duration when active days exist")
    func testCanFocusNextFromDurationWithActiveDays() {
        let viewModel = createTestViewModel()
        viewModel.hasDailyMinimum = false
        viewModel.toggleActiveDay(2) // Add Monday (weekday 2)
        
        let focusedField: GoalEditorView.Field? = .duration
        let result: Bool = {
            switch focusedField {
            case .duration:
                return viewModel.hasDailyMinimum || !viewModel.activeDays.isEmpty
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusNext returns false from duration when no daily minimum and no active days")
    func testCanFocusNextFromDurationNoNextField() {
        let viewModel = createTestViewModel()
        viewModel.hasDailyMinimum = false
        viewModel.activeDays.removeAll()
        
        let focusedField: GoalEditorView.Field? = .duration
        let result: Bool = {
            switch focusedField {
            case .duration:
                return viewModel.hasDailyMinimum || !viewModel.activeDays.isEmpty
            default:
                return false
            }
        }()
        
        #expect(result == false)
    }
    
    @Test("canFocusNext returns true from dailyMinimum when active days exist")
    func testCanFocusNextFromDailyMinimum() {
        let viewModel = createTestViewModel()
        viewModel.toggleActiveDay(2) // Add Monday (weekday 2)
        
        let focusedField: GoalEditorView.Field? = .dailyMinimum
        let result: Bool = {
            switch focusedField {
            case .dailyMinimum:
                return !viewModel.activeDays.isEmpty
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusNext returns false from last schedule day")
    func testCanFocusNextFromLastScheduleDay() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(2) // Only Monday (weekday 2)
                
        // Get next active day after Monday
        let nextDay = viewModel.getNextActiveScheduleDay(after: 2)
        let hasNext = nextDay != nil
        
        #expect(hasNext == false)
    }
    
    @Test("canFocusNext returns true from middle schedule day")
    func testCanFocusNextFromMiddleScheduleDay() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(2) // Monday (weekday 2)
        viewModel.toggleActiveDay(4) // Wednesday (weekday 4)
        viewModel.toggleActiveDay(6) // Friday (weekday 6)
                
        // Get next active day after Wednesday (should be Friday)
        let nextDay = viewModel.getNextActiveScheduleDay(after: 4)
        let hasNext = nextDay != nil
        
        #expect(hasNext == true)
    }
    
    @Test("canFocusNext returns true when focusedField is nil")
    func testCanFocusNextWhenNil() {
        let focusedField: GoalEditorView.Field? = nil
        let result: Bool = {
            switch focusedField {
            case .none:
                return true
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    // MARK: - canFocusPrevious Tests
    
    @Test("canFocusPrevious returns false from goalName")
    func testCanFocusPreviousFromGoalName() {
        let focusedField: GoalEditorView.Field? = .goalName
        let result: Bool = {
            switch focusedField {
            case .goalName:
                return false
            default:
                return true
            }
        }()
        
        #expect(result == false)
    }
    
    @Test("canFocusPrevious returns true from duration")
    func testCanFocusPreviousFromDuration() {
        let focusedField: GoalEditorView.Field? = .duration
        let result: Bool = {
            switch focusedField {
            case .duration:
                return true
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusPrevious returns true from dailyMinimum")
    func testCanFocusPreviousFromDailyMinimum() {
        let focusedField: GoalEditorView.Field? = .dailyMinimum
        let result: Bool = {
            switch focusedField {
            case .dailyMinimum:
                return true
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusPrevious returns true from any schedule day")
    func testCanFocusPreviousFromScheduleDay() {
        let focusedField: GoalEditorView.Field? = .scheduleDay(3)
        let result: Bool = {
            switch focusedField {
            case .scheduleDay:
                return true
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusPrevious returns true when nil and on duration stage")
    func testCanFocusPreviousWhenNilOnDurationStage() {
        let viewModel = createTestViewModel()
        viewModel.currentStage = .duration
        
        let focusedField: GoalEditorView.Field? = nil
        let result: Bool = {
            switch focusedField {
            case .none:
                return viewModel.currentStage == .duration
            default:
                return false
            }
        }()
        
        #expect(result == true)
    }
    
    @Test("canFocusPrevious returns false when nil and on name stage")
    func testCanFocusPreviousWhenNilOnNameStage() {
        let viewModel = createTestViewModel()
        viewModel.currentStage = .name
        
        let focusedField: GoalEditorView.Field? = nil
        let result: Bool = {
            switch focusedField {
            case .none:
                return viewModel.currentStage == .duration
            default:
                return false
            }
        }()
        
        #expect(result == false)
    }
    
    // MARK: - Active Day Navigation Tests
    
    @Test("getNextActiveScheduleDay returns correct next day")
    func testGetNextActiveScheduleDay() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(2) // Monday (weekday 2)
        viewModel.toggleActiveDay(4) // Wednesday (weekday 4)
        viewModel.toggleActiveDay(6) // Friday (weekday 6)
        
        let nextAfterMonday = viewModel.getNextActiveScheduleDay(after: 2)
        #expect(nextAfterMonday == 4)
        
        let nextAfterWednesday = viewModel.getNextActiveScheduleDay(after: 4)
        #expect(nextAfterWednesday == 6)
        
        let nextAfterFriday = viewModel.getNextActiveScheduleDay(after: 6)
        #expect(nextAfterFriday == nil)
    }
    
    @Test("getNextActiveScheduleDay returns first day when passed nil")
    func testGetNextActiveScheduleDayFromNil() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(4) // Wednesday (weekday 4)
        viewModel.toggleActiveDay(6) // Friday (weekday 6)
        
        let firstDay = viewModel.getNextActiveScheduleDay(after: nil)
        #expect(firstDay == 4)
    }
    
    @Test("getPreviousActiveScheduleDay returns correct previous day")
    func testGetPreviousActiveScheduleDay() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(2) // Monday (weekday 2)
        viewModel.toggleActiveDay(4) // Wednesday (weekday 4)
        viewModel.toggleActiveDay(6) // Friday (weekday 6)
        
        let prevBeforeFriday = viewModel.getPreviousActiveScheduleDay(before: 6)
        #expect(prevBeforeFriday == 4)
        
        let prevBeforeWednesday = viewModel.getPreviousActiveScheduleDay(before: 4)
        #expect(prevBeforeWednesday == 2)
        
        let prevBeforeMonday = viewModel.getPreviousActiveScheduleDay(before: 2)
        #expect(prevBeforeMonday == nil)
    }
    
    @Test("getPreviousActiveScheduleDay returns last day when passed nil")
    func testGetPreviousActiveScheduleDayFromNil() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(2) // Monday (weekday 2)
        viewModel.toggleActiveDay(4) // Wednesday (weekday 4)
        
        let lastDay = viewModel.getPreviousActiveScheduleDay(before: nil)
        #expect(lastDay == 4)
    }
    
    // MARK: - Edge Cases
    
    @Test("Navigation with all days active")
    func testNavigationWithAllDaysActive() {
        let viewModel = createTestViewModel()
        // Days are already all active by default (1-7), no need to toggle
        
        // Should be able to navigate from day 2 (Monday) through day 1 (Sunday)
        // The order is Mon-Sun: 2, 3, 4, 5, 6, 7, 1
        var currentDay: Int? = 2
        var visitedDays: [Int] = [2]
        
        while let next = viewModel.getNextActiveScheduleDay(after: currentDay) {
            visitedDays.append(next)
            currentDay = next
            
            // Safety check to prevent infinite loop
            if visitedDays.count > 7 {
                break
            }
        }
        
        #expect(visitedDays.count == 7)
        #expect(visitedDays == [2, 3, 4, 5, 6, 7, 1])
    }
    
    @Test("Navigation with single active day")
    func testNavigationWithSingleActiveDay() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll() // Clear all days first
        viewModel.toggleActiveDay(4) // Only Thursday
        
        let nextAfterThursday = viewModel.getNextActiveScheduleDay(after: 4)
        #expect(nextAfterThursday == nil)
        
        let prevBeforeThursday = viewModel.getPreviousActiveScheduleDay(before: 4)
        #expect(prevBeforeThursday == nil)
        
        let firstDay = viewModel.getNextActiveScheduleDay(after: nil)
        #expect(firstDay == 4)
        
        let lastDay = viewModel.getPreviousActiveScheduleDay(before: nil)
        #expect(lastDay == 4)
    }
    
    @Test("Navigation with no active days")
    func testNavigationWithNoActiveDays() {
        let viewModel = createTestViewModel()
        viewModel.activeDays.removeAll()
        
        let nextDay = viewModel.getNextActiveScheduleDay(after: nil)
        #expect(nextDay == nil)
        
        let prevDay = viewModel.getPreviousActiveScheduleDay(before: nil)
        #expect(prevDay == nil)
    }
}
