# ContentView Refactoring Implementation Guide

This guide provides a complete roadmap for refactoring ContentView.swift from 2,322 lines to ~300 lines.

## Status

- ✅ **NavigationState.swift** - Created (57 lines)
- ✅ **ModelContextExtensions.swift** - Created (45 lines) 
- ✅ **Error handling** - Fixed across 8 files
- ⏳ **HealthKitIntegration** - Ready to extract (305 lines)
- ⏳ **PlanningIntegration** - Ready to extract (350 lines)
- ⏳ **DailyProgressCardView** - Ready to extract (150 lines)
- ⏳ **Remaining 9 components** - Documented below

## Current ContentView Structure

**Total Lines:** 2,322  
**Target Lines:** ~300  
**Reduction:** 87%

---

## Phase 1: Extract HealthKit Integration (Lines 1590-1894)

### File: `ContentView/Integration/HealthKitIntegration.swift`

**Size:** ~305 lines  
**Dependencies:**
- HealthKitManager
- ModelContext
- GoalSession array
- Day object

**Methods to Extract:**
```swift
class HealthKitIntegration {
    private let healthKitManager: HealthKitManager
    private var healthKitObservers: [HKObserverQuery] = []
    var isSyncing = false
    
    // Lines 1592-1741
    func syncHealthKitData(
        userInitiated: Bool,
        goals: [Goal],
        sessions: [GoalSession],
        day: Day,
        modelContext: ModelContext,
        onComplete: @escaping (ToastConfig?) -> Void
    )
    
    // Lines 1745-1794
    private func syncHistoricalSessions(
        from samples: [HealthKitSample],
        for goal: Goal,
        in session: GoalSession,
        day: Day,
        modelContext: ModelContext
    )
    
    // Lines 1799-1832
    private func mergeSamples(_ samples: [HealthKitSample]) -> [HealthKitSample]
    
    // Lines 1835-1862
    private func createMergedSample(from samples: [HealthKitSample]) -> HealthKitSample
    
    // Lines 1865-1885
    func startHealthKitObservers(goals: [Goal])
    
    // Lines 1888-1893
    func stopHealthKitObservers()
}
```

**ContentView Changes:**
```swift
// Add property
@State private var healthKitIntegration: HealthKitIntegration

// Replace all calls
healthKitIntegration.syncHealthKitData(...)
healthKitIntegration.startHealthKitObservers(goals: goals)
healthKitIntegration.stopHealthKitObservers()
```

---

## Phase 2: Extract Planning Integration (Lines 1896-2187)

### File: `ContentView/Integration/PlanningIntegration.swift`

**Size:** ~350 lines  
**Dependencies:**
- PlanningViewModel
- GoalSession array
- Day object
- ModelContext

**Methods to Extract:**
```swift
class PlanningIntegration {
    private let planningViewModel: PlanningViewModel
    
    // Lines 1896-2109
    func generateDailyPlan(
        for goals: [Goal],
        sessions: [GoalSession],
        day: Day,
        modelContext: ModelContext,
        maxSessions: Int,
        unlimitedSessions: Bool
    ) async throws
    
    // Lines 2112-2144
    private func analyzeUsagePattern(
        for goal: Goal,
        session: GoalSession,
        currentHour: Int
    ) -> UsagePattern
    
    // Lines 2147-2187
    func calculateRecommendationReasons(
        for session: GoalSession,
        goal: Goal
    ) -> [String]
    
    // Lines 2074-2086
    private func parseTimeString(_ timeString: String, for date: Date) -> Date?
    
    // Lines 2023-2062
    private func animatePlannedSessions(_ plan: DailyPlan)
}
```

**ContentView Changes:**
```swift
@State private var planningIntegration: PlanningIntegration

// Replace calls
await planningIntegration.generateDailyPlan(...)
let reasons = planningIntegration.calculateRecommendationReasons(for: session, goal: goal)
```

---

## Phase 3: Extract Daily Progress Card (Lines 690-896)

### File: `ContentView/Components/DailyProgressCardView.swift`

**Size:** ~150 lines

```swift
struct DailyProgressCardView: View {
    let sessions: [GoalSession]
    let day: Day
    @Binding var showProgressTile: Bool
    @Binding var showWeatherTile: Bool
    @Binding var showCalendarTile: Bool
    @State private var nextCalendarEvent: EKEvent?
    
    var body: some View {
        // Lines 690-809 - Progress card UI
    }
    
    private func weatherSymbol(for condition: String) -> String {
        // Lines 811-847
    }
    
    private var freeTimeText: String {
        // Lines 850-866
    }
    
    private func fetchNextCalendarEvent() {
        // Lines 869-896
    }
}
```

---

## Phase 4: Additional Components to Extract

### 4.1 Session Management (`SessionManagement.swift` - 150 lines)

```swift
class SessionManagement {
    func refreshGoals(...)  // Lines 1293-1327
    func syncChecklistToSessions(for goal: Goal, ...)  // Lines 1329-1388
    func skip(session: GoalSession, ...)  // Lines 1390-1408
    func isGoalValid(_ goal: Goal) -> Bool  // Lines 1411-1428
}
```

### 4.2 Session List Section (`SessionListSection.swift` - 350 lines)

```swift
struct SessionListSection: View {
    let sessions: [GoalSession]
    @Binding var expandedSections: Set<ContextualSection.SectionType>
    let onSessionTap: (GoalSession) -> Void
    
    var body: some View {
        // Lines 265-638 - ScrollViewReader + List
    }
}
```

### 4.3 Toolbar Builder (`ToolbarBuilder.swift` - 100 lines)

```swift
struct ContentViewToolbar: ToolbarContent {
    @Binding var navigationState: NavigationState
    let onSync: () -> Void
    let onAddGoal: () -> Void
    
    var body: some ToolbarContent {
        // Lines 898-1004
    }
}
```

### 4.4 Focus Banner (`FocusBannerView.swift` - 30 lines)

```swift
struct FocusBannerView: View {
    let focusFilter: FocusFilter
    let onClear: () -> Void
    
    var body: some View {
        // Lines 242-263
    }
}
```

### 4.5 Session Interaction Handlers (`SessionInteractionHandlers.swift` - 80 lines)

```swift
class SessionInteractionHandlers {
    func handleTimerToggle(for session: GoalSession, ...)  // Lines 1501-1516
    func handleStartTimeAdjustment(...)  // Lines 1519-1530
    func handleDailyGoalAdjustment(...)  // Lines 1533-1570
    func handle(event: SessionTimerEvent)  // Lines 1573-1587
}
```

### 4.6 Planner Setup Helpers (`PlannerSetupHelpers.swift` - 100 lines)

```swift
class PlannerSetupHelpers {
    func setupOnAppear(...)  // Lines 1006-1049
    func rescheduleGoalNotifications(...)  // Lines 1053-1071
    func checkAndRunAutoPlan(...)  // Lines 1074-1109
    func updateExistingSessionReasons()  // Lines 1112-1121
    func handleGoalsChange(old: [Goal], new: [Goal])  // Lines 1123-1149
}
```

### 4.7 Filter Service Extensions (`SessionFilterService+Extensions.swift` - 80 lines)

```swift
extension SessionFilterService {
    var availableGoalThemes: [GoalTag]  // Lines 1241-1246
    var availableFilters: [Filter]  // Lines 1249-1262
    var sessionCountsForFilters: [Filter: Int]  // Lines 1265-1271
    var focusFilteredSessions: [GoalSession]  // Lines 1273-1279
}
```

### 4.8 Scroll Helpers (`ScrollAndFilterHelpers.swift` - 50 lines)

```swift
class ScrollAndFilterHelpers {
    func scrollToFilterSection(_ section: ContextualSection.SectionType, ...)  // Lines 1430-1466
    func getRecommendedSessions() -> [GoalSession]  // Lines 1468-1480
}
```

### 4.9 Deep Link Handler (`DeepLinkHandler.swift` - 20 lines)

```swift
class DeepLinkHandler {
    func handleDeepLink(sessionID: String?, ...)  // Lines 2282-2295
}
```

---

## Implementation Steps

### Step 1: Update ContentView to use NavigationState

Replace all individual @State variables with:
```swift
@State private var navigation = NavigationState()
```

Update all references:
- `showPlannerSheet` → `navigation.showPlannerSheet`
- `selectedSession` → `navigation.selectedSession`
- etc.

### Step 2: Extract HealthKitIntegration

1. Create `ContentView/Integration/HealthKitIntegration.swift`
2. Move methods (lines 1590-1894)
3. Update ContentView to use `healthKitIntegration.syncHealthKitData(...)`
4. Build and test

### Step 3: Extract PlanningIntegration

1. Create `ContentView/Integration/PlanningIntegration.swift`
2. Move methods (lines 1896-2187)
3. Update ContentView
4. Build and test

### Step 4: Extract Remaining Components

Continue with remaining 9 components in order of complexity.

---

## Testing Strategy

After each extraction:
1. ✅ Build succeeds
2. ✅ All existing tests pass
3. ✅ Manual smoke test of affected features
4. ✅ No regressions in functionality

---

## Expected Final Result

### New ContentView.swift (~300 lines):
```swift
struct ContentView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query private var sessions: [GoalSession]
    
    // MARK: - State
    @State private var navigation = NavigationState()
    @State private var timerManager: SessionTimerManager?
    @State private var healthKitIntegration: HealthKitIntegration
    @State private var planningIntegration: PlanningIntegration
    // ... other managers
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigation.navigationPath) {
            SessionListSection(...)
                .overlay(alignment: .top) {
                    FocusBannerView(...)
                }
                .searchable(...)
                .toolbar {
                    ContentViewToolbar(...)
                }
        }
        .sheet(isPresented: $navigation.showPlannerSheet) { ... }
        .sheet(isPresented: $navigation.showAllGoals) { ... }
        // ... other sheets
        .task {
            await setupOnAppear()
        }
    }
    
    // MARK: - Computed Properties
    private var availableFilters: [Filter] { ... }
    
    // MARK: - Setup
    private func setupOnAppear() async { ... }
}
```

---

## File Structure

```
Momentum/
└── ContentView/
    ├── ContentView.swift (~300 lines)
    ├── NavigationState.swift (57 lines) ✅
    ├── Components/
    │   ├── DailyProgressCardView.swift (150 lines)
    │   ├── SessionListSection.swift (350 lines)
    │   ├── FocusBannerView.swift (30 lines)
    │   └── ToolbarBuilder.swift (100 lines)
    ├── Integration/
    │   ├── HealthKitIntegration.swift (305 lines)
    │   ├── PlanningIntegration.swift (350 lines)
    │   └── PlannerSetupHelpers.swift (100 lines)
    ├── Handlers/
    │   ├── SessionManagement.swift (150 lines)
    │   ├── SessionInteractionHandlers.swift (80 lines)
    │   └── DeepLinkHandler.swift (20 lines)
    └── Services/
        ├── SessionFilterService+Extensions.swift (80 lines)
        └── ScrollAndFilterHelpers.swift (50 lines)
```

---

## Benefits After Refactoring

- ✅ **Maintainability**: Each file has single responsibility
- ✅ **Testability**: Extracted classes can be unit tested
- ✅ **Reusability**: Components can be used elsewhere
- ✅ **Readability**: 300-line files vs 2,322-line monolith
- ✅ **Performance**: Clearer what triggers re-renders
- ✅ **Team Collaboration**: Multiple developers can work on different files

---

## Estimated Time

- Phase 1 (HealthKit): 1-2 hours
- Phase 2 (Planning): 1-2 hours
- Phase 3 (UI Components): 2-3 hours
- Phase 4 (Remaining): 2-3 hours

**Total**: 6-10 hours for experienced SwiftUI developer

---

## Notes

- Keep this guide updated as you refactor
- Test thoroughly after each phase
- Consider creating feature branches for each phase
- Update this document with any issues encountered
