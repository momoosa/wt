# Animated Session Planning & Configurable Limits

## Overview

The AI planner now features beautiful animations when revealing planned sessions one by one, and users can configure the maximum number of sessions through Settings.

## New Features

### 1. Sequential Animation of Planned Sessions

When the planner completes, sessions are revealed one by one with:
- **Automatic filter switch** to "Planned" view
- **Staggered reveal** with decreasing delays (400ms → 150ms)
- **Shimmer effect** on new sessions
- **Light haptic feedback** for each reveal
- **Spring animations** for smooth transitions

#### Animation Flow
1. Planning completes
2. View switches to "Planned" filter (300ms transition)
3. Each session reveals sequentially:
   - Priority badge scales in
   - Start time appears
   - Shimmer overlay plays
   - Light haptic tick
4. After all reveals, shimmer effects fade out

#### Technical Details
```swift
// State tracking
@State private var revealedSessionIDs: Set<UUID> = []

// Animation function
private func animatePlannedSessions(_ plan: DailyPlan) async {
    // Switch to planned filter
    activeFilter = .planned
    
    // Reveal each session with decreasing delays
    for (index, session) in plan.sessions.enumerated() {
        revealedSessionIDs.insert(session.id)
        
        let delay = max(150, 400 - (index * 30))
        await Task.sleep(for: .milliseconds(delay))
    }
}
```

### 2. Configurable Session Limits

Users can now control how many sessions the AI suggests:

#### Settings Screen
- **New "Settings" button** in toolbar (gear icon)
- **AI Planning section** with two options:
  - **Unlimited Sessions toggle** - Allow any number of suggestions
  - **Max Sessions stepper** - Choose 1-20 sessions (default: 5)

#### Settings Implementation
```swift
@AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
@AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
```

Settings are persisted using `@AppStorage` and automatically sync across the app.

#### How It Works
When generating a plan:
```swift
var preferences = plannerPreferences
if !unlimitedPlannedSessions {
    preferences.maxSessionsPerDay = maxPlannedSessions
} else {
    preferences.maxSessionsPerDay = 100 // Effectively unlimited
}
```

### 3. Visual Enhancements

#### Shimmer Effect
New `ShimmerEffect` view that creates a smooth gradient sweep:
- Purple gradient overlay
- 1.5-second linear animation
- Loops continuously until revealed
- Non-interactive (doesn't block taps)

```swift
struct ShimmerEffect: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                .clear,
                Color.purple.opacity(0.3),
                .clear
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
```

#### Enhanced Transitions
- Priority badges: `.scale.combined(with: .opacity)`
- Start times: `.scale.combined(with: .opacity)`
- Reasoning text: `.move(edge: .top).combined(with: .opacity)`
- Session taps: `.spring(response: 0.3)`

### 4. Improved Haptic Feedback

Three types of haptics during planning:
1. **Success notification** - When planning starts
2. **Light impact** - For each session reveal
3. **Error notification** - If planning fails

## User Experience

### Planning Flow
1. User taps "Plan Day" button (sparkles icon)
2. Button shows progress indicator
3. AI generates plan (respecting session limit)
4. View smoothly switches to "Planned" filter
5. Sessions appear one by one with shimmer
6. Each reveal triggers a subtle haptic tick
7. After all sessions appear, shimmers fade
8. Alert shows completion summary

### Customization Flow
1. User taps "Settings" button (gear icon)
2. Settings sheet appears
3. User toggles "Unlimited Sessions" or adjusts stepper
4. Changes save automatically
5. Next plan respects new limits

## Files Modified

### ContentView.swift
- Added `revealedSessionIDs` state
- Added `maxPlannedSessions` and `unlimitedPlannedSessions` @AppStorage
- Added `showSettings` state
- Updated `generateDailyPlan()` to respect limits and trigger animation
- Added `animatePlannedSessions()` for sequential reveal
- Enhanced session rows with transitions and shimmer overlay
- Added settings button to toolbar
- Added settings sheet

### New Files

#### SettingsView.swift
New dedicated settings screen with:
- AI Planning section
- Unlimited toggle
- Max sessions stepper
- Helpful descriptions
- About section (version info)

#### ShimmerEffect.swift (embedded in ContentView)
Reusable shimmer effect component for highlighting new content.

## Configuration Options

### Max Planned Sessions
- **Default:** 5 sessions
- **Range:** 1-20 sessions
- **Unlimited:** Available via toggle
- **Storage:** `@AppStorage("maxPlannedSessions")`

### Unlimited Planned Sessions
- **Default:** `false` (limited)
- **When enabled:** Sets max to 100 (effectively unlimited)
- **Storage:** `@AppStorage("unlimitedPlannedSessions")`

## Benefits

1. **Visual Delight** - Animations make planning feel magical and engaging
2. **Clear Feedback** - Users see exactly what was planned
3. **Configurable** - Users control their experience
4. **Performance** - Staggered delays prevent UI overload
5. **Accessibility** - Haptics provide non-visual feedback
6. **Persistence** - Settings survive app restarts

## Animation Timing

- **Filter switch:** 400ms spring
- **First reveal:** 400ms delay
- **Each subsequent reveal:** -30ms (minimum 150ms)
- **Session transition:** 500ms spring (response: 0.5, damping: 0.7)
- **Shimmer duration:** 1.5s linear loop
- **Final cleanup:** 1000ms delay before removing shimmer

## Example Timeline

For 5 planned sessions:
```
0ms:     Planning completes
0ms:     Switch to Planned filter
300ms:   First session reveals with shimmer
700ms:   Second session reveals (400 - 30 = 370ms delay)
1040ms:  Third session reveals (370 - 30 = 340ms delay)
1350ms:  Fourth session reveals (340 - 30 = 310ms delay)
1630ms:  Fifth session reveals (310 - 30 = 280ms delay)
2630ms:  All shimmers fade out
2630ms:  Completion alert appears
```

## Future Enhancements

Potential improvements:
- Custom animation speeds in settings
- Different reveal patterns (top-to-bottom, priority-first, etc.)
- Sound effects option
- Preview animation in settings
- Confetti effect on completion
- Session count animation in alert
