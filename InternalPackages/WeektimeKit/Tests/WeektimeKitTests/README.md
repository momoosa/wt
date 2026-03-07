# WeektimeKit Unit Tests

This directory contains comprehensive unit tests for the WeektimeKit business logic.

## Test Files Created

### 1. GoalScheduleTests.swift
Tests the critical Goal scheduling logic including:
- `dailyTargetFromSchedule()` - Daily target calculation from weekly targets and schedules
- `isScheduled(weekday:time:)` - Schedule validation
- `timesForWeekday()` - Time extraction and parsing
- `hasSchedule` - Schedule existence checks
- `scheduledWeekdays` - Scheduled day enumeration
- `scheduleSummary` - Human-readable schedule formatting
- `hasWeatherTriggers` - Weather-based visibility logic

**Test Coverage**: 20+ test cases covering edge cases like zero targets, empty schedules, and weather conditions.

### 2. SessionProgressTests.swift
Tests session progress calculations including:
- `progress` - Progress ratio calculation (0.0-1.0)
- `remainingTime` - Remaining time to target
- `progressPercentage` - Formatted percentage string
- `progressPercentageInt` - Integer percentage

**Test Coverage**: 15+ test cases covering zero values, exact completion, and overflow scenarios.

### 3. IntervalSequenceTests.swift
Tests Pomodoro-style interval sequence building:
- `buildAlternatingSequence()` - Break/work interval generation
- Order index assignment
- Duration preservation
- Naming conventions
- List associations

**Test Coverage**: 10+ test cases covering empty sequences, alternating patterns, and large repeat counts.

### 4. DateExtensionTests.swift
Tests critical date/time calculations:
- `weekProgress()` - Week completion percentage
- `yearMonthDayID()` - Date identifier formatting
- `startOfWeek()` / `endOfWeek()` - Week boundary calculations
- `overlapPercentage()` - Range overlap calculations

**Test Coverage**: 15+ test cases covering timezone handling, boundary conditions, and overlap scenarios.

## Running the Tests

To run these tests in Xcode:
1. Open the Momentum.xcodeproj
2. Select the WeektimeKit scheme
3. Press Cmd+U to run all tests
4. Or use Cmd+6 to open the Test Navigator and run individual test suites

## Test Coverage Summary

- **Goal Logic**: 20+ tests
- **Progress Calculations**: 15+ tests
- **Interval Management**: 10+ tests  
- **Date/Time Math**: 15+ tests
- **Total**: 60+ comprehensive unit tests

## Next Steps

Additional test files that should be created:
- `TimeIntervalFormattingTests.swift` - Test all 4 formatting styles
- `SessionFilterTests.swift` - Test complex filtering logic
- `WeatherConditionTests.swift` - Test weather validation
- `HealthKitMetricTests.swift` - Test metric type mappings
- `GoalStoreTests.swift` - Test persistence and validation

## Notes

These tests use Swift's Testing framework (`import Testing`) introduced in Xcode 16+. 
All tests are designed to be:
- Fast (no async operations or database calls)
- Isolated (no shared state)
- Deterministic (predictable results)
- Comprehensive (covering edge cases)
