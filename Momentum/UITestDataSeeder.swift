//
//  UITestDataSeeder.swift
//  Momentum
//
//  Created by Assistant on 07/03/2026.
//

import Foundation
import SwiftData
import MomentumKit

/// Handles seeding test data when app is launched in UI testing mode
class UITestDataSeeder {
    
    static let shared = UITestDataSeeder()
    
    private init() {}
    
    /// Check if app is running in UI test mode
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing")
    }
    
    /// Check if should reset data
    static var shouldResetData: Bool {
        ProcessInfo.processInfo.arguments.contains("RESET-DATA")
    }
    
    /// Check if should seed sample data
    static var shouldSeedSampleData: Bool {
        ProcessInfo.processInfo.arguments.contains("SAMPLE-DATA")
    }
    
    /// Setup test data based on launch arguments
    func setupTestData(modelContext: ModelContext) {
        guard UITestDataSeeder.isUITesting else {
            return
        }
        
        if UITestDataSeeder.shouldResetData {
            resetAllData(modelContext: modelContext)
        }
        
        if UITestDataSeeder.shouldSeedSampleData {
            seedSampleData(modelContext: modelContext)
        }
    }
    
    // MARK: - Data Reset
    
    private func resetAllData(modelContext: ModelContext) {
        do {
            // Delete all goals
            try modelContext.delete(model: Goal.self)
            
            // Delete all goal sessions
            try modelContext.delete(model: GoalSession.self)
            
            // Delete all days
            try modelContext.delete(model: Day.self)
            
            // Delete all tags
            try modelContext.delete(model: GoalTag.self)
            
            try modelContext.save()
            
            print("✅ UI Test: Reset all data")
        } catch {
            print("❌ UI Test: Failed to reset data - \(error)")
        }
    }
    
    // MARK: - Sample Data
    
    func seedSampleData(modelContext: ModelContext) {
        do {
            // Create sample goals with different states
            let readingGoal = createReadingGoal()
            let exerciseGoal = createExerciseGoal()
            let meditationGoal = createMeditationGoal()
            let codingGoal = createCodingGoal()
            
            modelContext.insert(readingGoal)
            modelContext.insert(exerciseGoal)
            modelContext.insert(meditationGoal)
            modelContext.insert(codingGoal)
            
            // Create today's day
            let calendar = Calendar.current
            let today = Date()
            let startOfDay = calendar.startOfDay(for: today)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let day = Day(start: startOfDay, end: endOfDay, calendar: calendar)
            modelContext.insert(day)
            
            // Create sessions for today
            let readingSession = GoalSession(title: readingGoal.title, goal: readingGoal, day: day)
            let exerciseSession = GoalSession(title: exerciseGoal.title, goal: exerciseGoal, day: day)
            let meditationSession = GoalSession(title: meditationGoal.title, goal: meditationGoal, day: day)
            
            modelContext.insert(readingSession)
            modelContext.insert(exerciseSession)
            modelContext.insert(meditationSession)
            
            // Add some historical data to reading goal
            let historicalSession = HistoricalSession(
                title: "Reading Session",
                start: startOfDay.addingTimeInterval(3600),
                end: startOfDay.addingTimeInterval(5400),
                needsHealthKitRecord: false
            )
            historicalSession.goalIDs = [readingSession.goalID]
            day.add(historicalSession: historicalSession)
            
            try modelContext.save()
            
            print("✅ UI Test: Seeded sample data")
            print("   - 4 goals created")
            print("   - 3 sessions created")
            print("   - 1 historical session added")
        } catch {
            print("❌ UI Test: Failed to seed sample data - \(error)")
        }
    }
    
    // MARK: - Sample Goal Factories
    
    private func createReadingGoal() -> Goal {
        let goal = Goal(title: "Reading", weeklyTarget: 3600 * 7) // 7 hours per week
        goal.iconName = "book.fill"
        return goal
    }
    
    private func createExerciseGoal() -> Goal {
        let goal = Goal(title: "Exercise", weeklyTarget: 3600 * 5) // 5 hours per week
        goal.iconName = "figure.run"
        return goal
    }
    
    private func createMeditationGoal() -> Goal {
        let goal = Goal(title: "Meditation", weeklyTarget: 1800 * 7) // 30 min per day
        goal.iconName = "sparkles"
        return goal
    }
    
    private func createCodingGoal() -> Goal {
        let goal = Goal(title: "Coding Practice", weeklyTarget: 7200 * 5) // 2 hours per weekday
        goal.iconName = "chevron.left.forwardslash.chevron.right"
        return goal
    }
    
    // MARK: - Advanced Sample Data
    
    /// Seed data with completed sessions (for testing history)
    func seedCompletedSessionsData(modelContext: ModelContext) {
        do {
            let goal = createReadingGoal()
            modelContext.insert(goal)
            
            let calendar = Calendar.current
            let today = Date()
            
            // Create sessions for last 7 days
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let day = Day(start: startOfDay, end: endOfDay, calendar: calendar)
                modelContext.insert(day)
                
                let session = GoalSession(title: goal.title, goal: goal, day: day)
                modelContext.insert(session)
                
                // Add completed time
                let historicalSession = HistoricalSession(
                    title: "Reading",
                    start: startOfDay.addingTimeInterval(3600),
                    end: startOfDay.addingTimeInterval(3600 + Double.random(in: 1800...5400)),
                    needsHealthKitRecord: false
                )
                historicalSession.goalIDs = [session.goalID]
                day.add(historicalSession: historicalSession)
            }
            
            try modelContext.save()
            
            print("✅ UI Test: Seeded completed sessions data (7 days)")
        } catch {
            print("❌ UI Test: Failed to seed completed sessions - \(error)")
        }
    }
    
    /// Seed data with goals that have tags
    func seedGoalsWithTags(modelContext: ModelContext) {
        do {
            // Create tags
            let fitnessTag = GoalTag(
                title: "Fitness",
                themeID: "red",
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 10...30,
                timeOfDayPreferences: [.morning, .afternoon]
            )
            
            let learningTag = GoalTag(
                title: "Learning",
                themeID: "blue",
                timeOfDayPreferences: [.evening, .night]
            )
            
            modelContext.insert(fitnessTag)
            modelContext.insert(learningTag)
            
            // Create goals with tags
            let runningGoal = Goal(title: "Running", weeklyTarget: 3600 * 3)
            runningGoal.primaryTag = fitnessTag
            
            let studyGoal = Goal(title: "Study", weeklyTarget: 7200 * 5)
            studyGoal.primaryTag = learningTag
            
            modelContext.insert(runningGoal)
            modelContext.insert(studyGoal)
            
            try modelContext.save()
            
            print("✅ UI Test: Seeded goals with tags")
        } catch {
            print("❌ UI Test: Failed to seed goals with tags - \(error)")
        }
    }
}

// MARK: - App Extension

extension UITestDataSeeder {
    
    /// Configure app for UI testing
    static func configureForUITesting(modelContext: ModelContext) {
        guard isUITesting else {
            return
        }
        
        print("🧪 Running in UI Test mode")
        
        // Setup test data
        shared.setupTestData(modelContext: modelContext)
    }
}
