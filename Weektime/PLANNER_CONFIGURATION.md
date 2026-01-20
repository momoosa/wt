# Interactive Planner Configuration Sheet

## Overview

The planner button now expands into a beautiful bottom sheet with theme selection and time input, featuring matched geometry animations and an intuitive tag cloud interface.

## Features

### 1. Matched Geometry Animation

The sparkles icon from the toolbar button smoothly transitions to the sheet header:

```swift
// Button
.matchedTransitionSource(id: "plannerButton", in: animation)

// Sheet header
.matchedTransitionSource(id: "plannerButton", in: animation)
```

This creates a fluid expansion effect where the button appears to "open up" into the sheet.

### 2. Theme Selection via Tag Cloud

**Tag Cloud Features:**
- **Auto-flowing layout** - Tags wrap naturally based on available width
- **Color-coded** - Each theme shows its unique color
- **Interactive** - Tap to toggle selection
- **Visual feedback**:
  - Unselected: Light background with border
  - Selected: Solid gradient background, white text
- **Haptic feedback** - Light tap on each selection

**Theme Tags Include:**
- Small colored circle indicator
- Theme name
- Smooth spring animations on selection

### 3. Available Time Configuration

**Two Input Methods:**

#### Quick Time Buttons
Pre-set durations in horizontal scroll:
- 30 minutes
- 1 hour
- 1.5 hours
- 2 hours
- 3 hours
- 4 hours

Selected button shows purple gradient, others show light purple tint.

#### Custom Slider
- Range: 15 minutes to 8 hours
- Step: 15-minute increments
- Shows formatted time (e.g., "2h 30m")
- Expandable section with smooth animation

### 4. Sheet Presentation

**Modern iOS Presentation:**
```swift
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)
.presentationCornerRadius(20)
.presentationBackground(.thinMaterial)
```

- **Two sizes**: Medium (default) and Large (if needed)
- **Drag indicator**: Shows users they can swipe to dismiss
- **Rounded corners**: Modern 20pt corner radius
- **Material background**: Translucent blur effect

### 5. Confirm Button

Sticky bottom button with:
- Purple gradient background
- Sparkles icon + "Generate Plan" text
- Success haptic on tap
- Safe area inset positioning
- Thin material background

## User Flow

### 1. Open Sheet
```
User taps "Plan Day" button
  ↓
Matched geometry animation
  ↓
Sheet slides up from bottom
  ↓
Sparkles icon transitions from button to sheet header
```

### 2. Configure Options
```
User selects themes:
  • Tap tags to toggle selection
  • Selected tags highlight with gradient
  • Light haptic feedback per tap
  • "Clear All" button appears when themes selected

User sets time:
  • Tap quick time button (instant selection)
  • OR expand custom picker
  • Use slider for precise control
  • Time display updates in real-time
```

### 3. Generate Plan
```
User taps "Generate Plan" button
  ↓
Success haptic feedback
  ↓
Sheet dismisses
  ↓
Planning begins with selected parameters
  ↓
List updates with filtered, time-limited sessions
```

## Technical Implementation

### State Management

```swift
@State private var showPlannerSheet = false
@State private var selectedThemes: Set<String> = [] // Theme IDs
@State private var availableTimeMinutes: Int = 120 // Default 2 hours
```

### Theme Extraction

```swift
private var availableGoalThemes: [GoalTheme] {
    let activeGoals = goals.filter { $0.status == .active }
    var uniqueThemes: [GoalTheme] = []
    var seenIDs: Set<String> = []
    
    for goal in activeGoals {
        let themeID = goal.primaryTheme.theme.id
        if !seenIDs.contains(themeID) {
            uniqueThemes.append(goal.primaryTheme)
            seenIDs.insert(themeID)
        }
    }
    
    return uniqueThemes
}
```

### Planning Logic

When generating the plan:
1. **Filter by themes** (if any selected)
2. **Calculate time-based limit**: `availableTimeMinutes / 30` (avg 30min per session)
3. **Apply minimum** of configured limit and time-based limit
4. **Generate optimized plan**

```swift
if !selectedThemes.isEmpty {
    activeGoals = activeGoals.filter { goal in
        selectedThemes.contains(goal.primaryTheme.theme.id)
    }
}

let timeBasedMaxSessions = availableTimeMinutes / 30
preferences.maxSessionsPerDay = min(preferences.maxSessionsPerDay, max(1, timeBasedMaxSessions))
```

### Flow Layout

Custom `Layout` protocol implementation for tag cloud:
- Automatically wraps items to new lines
- Maintains consistent spacing
- Calculates optimal size
- Handles dynamic content

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ())
}
```

## UI Components

### PlannerConfigurationSheet
Main sheet view containing:
- Header with animated sparkles icon
- Available time picker section
- Theme selection tag cloud
- Confirm button in safe area inset

### ThemeTag
Individual theme button showing:
- Colored circle indicator
- Theme name
- Selection state (gradient vs outline)
- Tap handler

### FlowLayout
Custom layout for wrapping tag cloud:
- Flows left to right
- Wraps to new lines as needed
- Uniform spacing between items

## Visual Design

### Colors
- **Primary**: Purple gradient for buttons and selections
- **Theme colors**: Each goal theme's unique color
- **Backgrounds**: System adaptive (light/dark mode)
- **Materials**: Translucent blur effects

### Typography
- **Title**: Title 2, Bold 
- **Headers**: Headline, Purple
- **Tags**: Subheadline, Medium
- **Body**: Subheadline, Secondary
- **Time**: Title 3, Semibold

### Spacing
- **Section spacing**: 24pt
- **Tag spacing**: 8pt
- **Padding**: 16pt horizontal, variable vertical
- **Corner radius**: 12pt (sections), 16pt (button)

## Animations

### Transitions
- **Sheet presentation**: Spring with 0.4s response
- **Theme selection**: Spring with 0.3s response
- **Time picker expansion**: Move + opacity combined
- **Matched geometry**: Automatic smooth transition

### Haptics
- **Light impact**: Theme tag selection
- **Success notification**: Confirm button tap

## Accessibility

- Clear labels for all interactive elements
- Sufficient contrast ratios
- Haptic feedback for important actions
- VoiceOver-friendly structure
- Large tap targets (44pt minimum)

## Empty States

**No Active Goals:**
```
"No active goals with themes"
Shown in gray rounded rectangle
```

**No Themes Selected:**
```
"All themes will be considered"
Shown as caption text
```

## Examples

### Default State
- Available time: 2 hours
- Selected themes: None (all included)
- Result: Up to 4 sessions from all active goals

### Focused State
- Available time: 1 hour
- Selected themes: Health, Wellness
- Result: Up to 2 sessions from health/wellness goals only

### Extended State
- Available time: 4 hours
- Selected themes: All available
- Result: Up to 8 sessions from all themes

## Future Enhancements

Potential improvements:
- Save favorite configurations
- Suggest optimal time based on goals
- Show estimated completion percentage
- Add focus mode presets (Morning, Afternoon, Evening)
- Integration with Calendar for accurate free time
- Theme priority ordering
- Visual preview of planned sessions before confirming
