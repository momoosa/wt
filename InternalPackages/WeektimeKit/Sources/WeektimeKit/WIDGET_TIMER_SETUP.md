# Widget Timer Control Setup Guide

This guide explains how to enable starting and stopping session timers directly from your home screen widgets.

## Overview

The widget timer control feature allows users to:
- View their top recommended goal sessions in a widget
- Start tracking time for a session with a tap
- Stop the timer and save the session
- See live timer state across both app and widget

## Files Added/Modified

### New Files
1. **SessionTimerIntents.swift** - App Intents for timer control
   - `ToggleTimerIntent` - Toggles timer on/off
   - `StartTimerIntent` - Starts a timer
   - `StopTimerIntent` - Stops a timer

### Modified Files
1. **MomentumWidget.swift** 
   - Added `dayID` and `isTimerActive` to `RecommendedSession`
   - Updated widget views with interactive play/stop buttons
   - Added timer state detection from shared UserDefaults
   
2. **SessionTimerManager.swift**
   - Updated to use App Group UserDefaults for widget communication
   - Automatically reloads widgets when timer state changes

3. **Theme.swift**
   - Removed `@MainActor` from `themePresets` to allow access from intents

4. **GoalTag.swift**
   - Changed from storing Theme relationship to storing `themeID` string
   - Added `themePreset` computed property for lightweight lookups

## Setup Instructions

### 1. Configure App Groups

You need to enable App Groups to share data between your app and widget:

#### In Xcode:
1. Select your project in the navigator
2. Select your **main app target**
3. Go to **Signing & Capabilities**
4. Click **+ Capability** and add **App Groups**
5. Click **+** and add: `group.com.moosa.ios.momentum`
6. Repeat steps 2-5 for your **widget extension target**

> **Note:** Make sure both targets use the exact same App Group identifier.

### 2. Update ModelContainer Configuration

Ensure your main app uses the App Group container for SwiftData:

```swift
// In your App struct or wherever you set up ModelContainer
let appGroupIdentifier = "group.com.moosa.ios.momentum"
guard let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: appGroupIdentifier
) else {
    fatalError("Failed to get App Group container")
}

let storeURL = containerURL.appendingPathComponent("default.store")
let modelConfiguration = ModelConfiguration(url: storeURL)
let container = try ModelContainer(
    for: Goal.self, GoalTag.self, Day.self, /* ... */,
    configurations: [modelConfiguration]
)
```

### 3. Add Intent to Widget Bundle

Make sure your `MomentumWidgetBundle.swift` includes the necessary intents:

```swift
import WidgetKit
import SwiftUI

@main
struct MomentumWidgetBundle: WidgetBundle {
    var body: some Widget {
        MomentumWidget()
        // Add other widgets here if needed
    }
}
```

### 4. Build and Run

1. Build and run your main app first to create data
2. Add the widget to your home screen
3. Tap the play button on any session to start tracking
4. The button changes to a stop button with "Recording" indicator
5. Tap again to stop and save the session

## How It Works

### Data Flow

1. **Starting Timer (from widget)**:
   - User taps play button → `ToggleTimerIntent` executes
   - Intent writes timer state to App Group UserDefaults
   - Intent reloads all widgets
   - Widget displays "Recording" state
   - Main app automatically loads timer state on next launch

2. **Stopping Timer (from widget)**:
   - User taps stop button → `ToggleTimerIntent` executes
   - Intent calculates duration and creates `HistoricalSession`
   - Intent clears timer state from UserDefaults
   - Intent saves to SwiftData and reloads widgets
   - Main app sees updated session data

3. **Timer Synchronization**:
   - App and widget share data via App Group UserDefaults
   - Both read from the same SwiftData store
   - Widgets reload automatically when timer state changes

### UserDefaults Keys

The following keys are used for timer synchronization:
- `ActiveSessionIDV1` - UUID string of active session
- `ActiveSessionStartDateV1` - Timestamp when timer started
- `ActiveSessionElapsedTimeV1` - Previously elapsed time

## Widget Sizes

### Small Widget
- Shows top recommended session
- No interactive buttons (too small)
- Tapping opens app

### Medium Widget
- Shows top 2 sessions with play/stop buttons
- Interactive buttons for starting/stopping timers
- "Recording" indicator when timer is active

### Large Widget
- Shows top 3 sessions with large play/stop buttons
- Most prominent interactive experience
- Clear visual feedback for timer state

## Design Details

### Visual Indicators
- **Play button**: Circular button with theme light color
- **Stop button**: Circular button with theme dark color
- **Recording state**: Red dot + "Recording" text
- **Progress ring**: Shows progress toward daily target

### Color Theming
- Each session uses its goal's theme colors
- Active timers use darker theme colors
- Inactive sessions use lighter theme colors

## Troubleshooting

### Widget Not Updating
- Verify App Group is correctly configured in both targets
- Check that both targets use the same App Group identifier
- Rebuild both app and widget extension

### Timer State Not Syncing
- Ensure `SessionTimerManager` uses `sharedDefaults`
- Verify UserDefaults keys match exactly
- Check that WidgetCenter.shared.reloadAllTimelines() is called

### Intent Errors
- Check Xcode console for error messages
- Verify SwiftData schema includes all models
- Ensure App Group container URL is accessible

### Data Not Persisting
- Confirm ModelContainer uses App Group URL
- Check file permissions for App Group container
- Verify both app and widget have access to App Group

## Performance Considerations

1. **Theme Lookups**: Using `themePreset` instead of `theme` avoids creating SwiftData model instances
2. **Widget Updates**: Widgets refresh every 15 minutes plus on-demand when timer state changes
3. **Intent Execution**: Intents run in a separate process with their own ModelContext

## Privacy & Security

- All data stays on device
- App Groups are sandboxed to your app and widgets only
- No network requests are made
- Timer state is stored locally in UserDefaults

## Future Enhancements

Possible improvements:
- Live Activity support for running timers
- Complications for Apple Watch
- Interactive notifications
- Siri shortcuts integration
- Lock screen widgets (iOS 16+)

## Support

If you encounter issues:
1. Check Xcode console for error messages
2. Verify App Group setup in both targets
3. Ensure all files are included in correct targets
4. Clean build folder and rebuild

---

**Created:** February 2, 2026  
**Last Updated:** February 2, 2026
