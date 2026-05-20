# Performance Optimizations 1-3: Implementation Plan

## Overview
Three targeted performance improvements to reduce unnecessary computation and view invalidation.

---

## 1. Cache `GoalSession.historicalSessions`

**Problem:** `historicalSessions` is a computed property that runs `day?.historicalSessions?.filter({ $0.goalIDs.contains(goalID)}) ?? []` on every access. It cascades into `elapsedTime` → `progress` → `hasMetDailyTarget` → `formattedTime`, meaning a single session row can trigger this O(n) filter 3-4 times per render.

**Solution:** Store the filtered result in a `@Transient` cached property, invalidated when the backing data changes.

**File:** `GoalSession.swift`

**Changes:**
- Add a `@Transient` private var `_cachedHistoricalSessions: [HistoricalSession]?` (transient = not persisted)
- Add a `@Transient` private var `_historicalSessionsCacheKey: String?` to track staleness (based on day's historicalSessions count + goalID)
- Modify `historicalSessions` to check the cache first, compute + store on miss
- Add `invalidateHistoricalSessionsCache()` public method for callers that mutate HistoricalSession data (e.g., HealthKit sync)

**Why @Transient:** SwiftData `@Transient` properties are not persisted to the store, making them ideal for in-memory caches. They survive for the lifetime of the model object in memory.

**Cache invalidation approach:** Simple — compare a lightweight key (count of day's historicalSessions + goalID) to detect when recomputation is needed. The cache also naturally resets when the model object is re-faulted by SwiftData.

---

## 2. Add Predicates to `@Query var _sessions` in ContentView

**Problem:** `@Query var _sessions: [GoalSession]` fetches ALL GoalSession objects from the entire database with no predicate. The computed `sessions` property then filters to `session.day?.id == day.id` in memory. As sessions accumulate over weeks/months, this loads increasingly more data than needed.

**Solution:** Initialize `_sessions` with a predicate scoped to the current day's sessions.

**File:** `ContentView.swift`

**Changes:**
- Modify the `init(day:viewModel:)` to configure `_sessions` with a `#Predicate` filtering by `day.id`
- The predicate will use `GoalSession`'s `day` relationship: `#Predicate<GoalSession> { $0.day?.id == dayID }`
- Keep the deduplication logic in the computed `sessions` property (can't easily express that in a predicate)
- This scopes the SwiftData fetch to only today's sessions at the SQL level

**Note:** SwiftData `@Query` can accept an initial value via `_sessions = Query(filter:sort:)` in the init.

---

## 3. Remove `withAnimation` from Timer Tick

**Problem:** In `ActiveSessionDetails.startUITimer()`, the timer callback wraps ALL state mutations in `withAnimation { ... }`. This fires every 1 second and causes SwiftUI to create an animation transaction for every property change. Since `@Observable` notifies all readers, every `SessionRowView` in the list gets invalidated with an animation transaction — even rows that aren't the active session.

**Solution:** Remove the `withAnimation` wrapper. The `Text.contentTransition(.numericText())` modifier on the time text in `SessionRowView` already handles smooth number transitions independently — it doesn't require the source mutation to be wrapped in `withAnimation`.

**File:** `ActiveSessionDetails.swift`

**Changes:**
- Remove the `withAnimation { }` wrapper from the timer callback
- Keep all the state mutations (tickCount, timeText, currentTime, target check, onTick) — just unwrap them from the animation block
- The `.contentTransition(.numericText())` in SessionRowView will continue to animate text changes smoothly without needing `withAnimation` at the source

**Why this works:** `contentTransition(.numericText())` uses its own built-in animation that activates whenever the text content changes — it doesn't depend on being inside a `withAnimation` transaction. Removing the wrapper means non-active session rows won't receive unnecessary animation transactions on every tick.

---

## Execution Order
1. **Timer fix** (smallest change, biggest immediate impact on per-second overhead)
2. **@Query predicate** (moderate change, reduces data loaded)
3. **historicalSessions cache** (most complex, reduces per-render computation)

## Testing
- Run full test suite after all changes
- Build to verify compilation
