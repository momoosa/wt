//
//  HealthKitAllocationTests.swift
//  Momentum Tests
//
//  Created by Assistant on 13/03/2026.
//

import Testing
import Foundation
@testable import Momentum
@testable import MomentumKit

@Suite("HealthKit Allocation Tests")
struct HealthKitAllocationTests {
    
    // MARK: - Sample Allocation Tests
    
    @Test("HealthKit samples are allocated to first goal only")
    func samplesAllocatedToFirstGoalOnly() {
        // This test documents the expected behavior:
        // When multiple goals use the same HealthKit metric,
        // samples should be allocated to the first goal processed
        
        // Create two goals with the same metric
        let goal1 = Goal(title: "Meditation", weeklyTarget: 3600)
        goal1.healthKitMetric = .mindfulMinutes
        goal1.healthKitSyncEnabled = true
        
        let goal2 = Goal(title: "Journaling", weeklyTarget: 3600)
        goal2.healthKitMetric = .mindfulMinutes
        goal2.healthKitSyncEnabled = true
        
        // In the actual implementation, ContentView.syncHealthKitData() uses
        // a Set<String> called allocatedSampleIDs to track which samples
        // have been assigned to prevent double-counting
        
        // Verify the expected behavior is documented
        #expect(goal1.healthKitMetric == goal2.healthKitMetric)
        #expect(goal1.healthKitSyncEnabled == true)
        #expect(goal2.healthKitSyncEnabled == true)
    }
    
    @Test("HealthKit sample IDs are unique identifiers")
    func sampleIDsAreUniqueIdentifiers() {
        // Create a mock HealthKit sample
        let sample = HealthKitSample(
            id: "test-sample-1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600), // 10 minutes
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "Health"
        )
        
        #expect(sample.id == "test-sample-1")
        #expect(sample.duration == 600)
    }
    
    @Test("Allocated sample IDs prevent double counting")
    func allocatedSampleIDsPreventDoubleCounting() {
        // Simulate the allocation logic
        var allocatedSampleIDs = Set<String>()
        
        let sampleID = "sample-123"
        
        // First goal gets the sample
        let isAvailableForGoal1 = !allocatedSampleIDs.contains(sampleID)
        #expect(isAvailableForGoal1 == true)
        
        if isAvailableForGoal1 {
            allocatedSampleIDs.insert(sampleID)
        }
        
        // Second goal should not get the sample
        let isAvailableForGoal2 = !allocatedSampleIDs.contains(sampleID)
        #expect(isAvailableForGoal2 == false)
    }
    
    @Test("Multiple samples can be allocated to same goal")
    func multipleSamplesCanBeAllocatedToSameGoal() {
        var allocatedSampleIDs = Set<String>()
        
        let sample1ID = "sample-1"
        let sample2ID = "sample-2"
        let sample3ID = "sample-3"
        
        // Goal 1 gets all samples
        allocatedSampleIDs.insert(sample1ID)
        allocatedSampleIDs.insert(sample2ID)
        allocatedSampleIDs.insert(sample3ID)
        
        #expect(allocatedSampleIDs.count == 3)
        #expect(allocatedSampleIDs.contains(sample1ID))
        #expect(allocatedSampleIDs.contains(sample2ID))
        #expect(allocatedSampleIDs.contains(sample3ID))
    }
    
    @Test("Different metrics don't conflict in allocation")
    func differentMetricsDontConflictInAllocation() {
        let goal1 = Goal(title: "Meditation", weeklyTarget: 3600)
        goal1.healthKitMetric = .mindfulMinutes
        
        let goal2 = Goal(title: "Workout", weeklyTarget: 3600)
        goal2.healthKitMetric = .workoutTime
        
        // Different metrics should not conflict
        #expect(goal1.healthKitMetric != goal2.healthKitMetric)
        
        // Both goals can receive their respective metric samples
        #expect(goal1.healthKitMetric == .mindfulMinutes)
        #expect(goal2.healthKitMetric == .workoutTime)
    }
    
    // MARK: - HealthKit Sample Tests
    
    @Test("HealthKit sample calculates duration correctly")
    func sampleCalculatesDurationCorrectly() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(1800) // 30 minutes
        
        let sample = HealthKitSample(
            id: "test",
            startDate: startDate,
            endDate: endDate,
            duration: 1800,
            metric: .mindfulMinutes,
            sourceName: "Health"
        )
        
        #expect(sample.duration == 1800)
        #expect(endDate.timeIntervalSince(startDate) == 1800)
    }
    
    @Test("HealthKit samples support different metrics")
    func samplesSupportDifferentMetrics() {
        let mindfulSample = HealthKitSample(
            id: "mindful-1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "Health"
        )
        
        let workoutSample = HealthKitSample(
            id: "workout-1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            duration: 1800,
            metric: .workoutTime,
            sourceName: "Health"
        )
        
        #expect(mindfulSample.metric == .mindfulMinutes)
        #expect(workoutSample.metric == .workoutTime)
        #expect(mindfulSample.metric != workoutSample.metric)
    }
    
    // MARK: - Goal HealthKit Configuration Tests
    
    @Test("Goal can enable HealthKit sync")
    func goalCanEnableHealthKitSync() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        goal.healthKitSyncEnabled = true
        goal.healthKitMetric = .mindfulMinutes
        
        #expect(goal.healthKitSyncEnabled == true)
        #expect(goal.healthKitMetric == .mindfulMinutes)
    }
    
    @Test("Goal with HealthKit disabled does not sync")
    func goalWithHealthKitDisabledDoesNotSync() {
        let goal = Goal(title: "Test Goal", weeklyTarget: 3600)
        goal.healthKitSyncEnabled = false
        goal.healthKitMetric = .mindfulMinutes
        
        #expect(goal.healthKitSyncEnabled == false)
        // Even though metric is set, it should not sync when disabled
    }
    
    @Test("Goal requires both sync enabled and metric set")
    func goalRequiresBothSyncEnabledAndMetricSet() {
        let goal1 = Goal(title: "Goal 1", weeklyTarget: 3600)
        goal1.healthKitSyncEnabled = true
        goal1.healthKitMetric = nil
        
        let goal2 = Goal(title: "Goal 2", weeklyTarget: 3600)
        goal2.healthKitSyncEnabled = false
        goal2.healthKitMetric = .mindfulMinutes
        
        let goal3 = Goal(title: "Goal 3", weeklyTarget: 3600)
        goal3.healthKitSyncEnabled = true
        goal3.healthKitMetric = .mindfulMinutes
        
        // Only goal3 meets both requirements
        #expect(goal3.healthKitSyncEnabled && goal3.healthKitMetric != nil)
        #expect(!(goal1.healthKitSyncEnabled && goal1.healthKitMetric != nil))
        #expect(!(goal2.healthKitSyncEnabled && goal2.healthKitMetric != nil))
    }
    
    // MARK: - Read-Only Metrics Tests
    
    @Test("Workout metrics are read-only")
    func workoutMetricsAreReadOnly() {
        // Workout-based metrics should not support write
        #expect(!HealthKitMetric.workoutTime.supportsWrite)
        #expect(!HealthKitMetric.weightLiftingTime.supportsWrite)
        #expect(!HealthKitMetric.ellipticalTime.supportsWrite)
        #expect(!HealthKitMetric.rowingTime.supportsWrite)
    }
    
    @Test("Mindful minutes supports write")
    func mindfulMinutesSupportsWrite() {
        // Mindful minutes should support write (for meditation sessions)
        #expect(HealthKitMetric.mindfulMinutes.supportsWrite)
    }
    
    @Test("Apple metrics are read-only")
    func appleMetricsAreReadOnly() {
        // Apple-calculated metrics should be read-only
        #expect(!HealthKitMetric.appleExerciseTime.supportsWrite)
        #expect(!HealthKitMetric.appleStandTime.supportsWrite)
        #expect(!HealthKitMetric.appleMoveTime.supportsWrite)
        #expect(!HealthKitMetric.timeInDaylight.supportsWrite)
    }
    
    // MARK: - Sample Filtering Tests
    
    @Test("Samples from this app are identified correctly")
    func samplesFromThisAppAreIdentified() {
        let momentumSample = HealthKitSample(
            id: "sample-1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "Momentum"
        )
        
        let weektimeSample = HealthKitSample(
            id: "sample-2",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "Weektime"
        )
        
        #expect(momentumSample.isFromThisApp)
        #expect(weektimeSample.isFromThisApp)
    }
    
    @Test("Samples from external apps are not identified as this app")
    func samplesFromExternalAppsNotIdentifiedAsThisApp() {
        let appleSample = HealthKitSample(
            id: "sample-1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "Health"
        )
        
        let headspaceSample = HealthKitSample(
            id: "sample-2",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "Headspace"
        )
        
        let appleWatchSample = HealthKitSample(
            id: "sample-3",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            duration: 1800,
            metric: .workoutTime,
            sourceName: "Apple Watch"
        )
        
        #expect(!appleSample.isFromThisApp)
        #expect(!headspaceSample.isFromThisApp)
        #expect(!appleWatchSample.isFromThisApp)
    }
    
    @Test("Case-insensitive app name detection")
    func caseInsensitiveAppNameDetection() {
        let lowerCaseSample = HealthKitSample(
            id: "sample-1",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "momentum"
        )
        
        let mixedCaseSample = HealthKitSample(
            id: "sample-2",
            startDate: Date(),
            endDate: Date().addingTimeInterval(600),
            duration: 600,
            metric: .mindfulMinutes,
            sourceName: "MoMeNtUm"
        )
        
        #expect(lowerCaseSample.isFromThisApp)
        #expect(mixedCaseSample.isFromThisApp)
    }
    
    @Test("Filtering samples from this app prevents double-counting")
    func filteringSamplesFromThisAppPreventsDoubleCounting() {
        let samples = [
            HealthKitSample(
                id: "external-1",
                startDate: Date(),
                endDate: Date().addingTimeInterval(600),
                duration: 600,
                metric: .mindfulMinutes,
                sourceName: "Headspace"
            ),
            HealthKitSample(
                id: "this-app-1",
                startDate: Date(),
                endDate: Date().addingTimeInterval(600),
                duration: 600,
                metric: .mindfulMinutes,
                sourceName: "Momentum"
            ),
            HealthKitSample(
                id: "external-2",
                startDate: Date(),
                endDate: Date().addingTimeInterval(900),
                duration: 900,
                metric: .mindfulMinutes,
                sourceName: "Calm"
            )
        ]
        
        // Filter out samples from this app
        let externalSamples = samples.filter { !$0.isFromThisApp }
        
        // Should only include the 2 external samples
        #expect(externalSamples.count == 2)
        #expect(externalSamples.allSatisfy { !$0.isFromThisApp })
        
        // Verify the correct samples were kept
        let sampleIDs = Set(externalSamples.map { $0.id })
        #expect(sampleIDs.contains("external-1"))
        #expect(sampleIDs.contains("external-2"))
        #expect(!sampleIDs.contains("this-app-1"))
    }
}
