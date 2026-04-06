# GoalEditorView ViewModel Refactoring Plan

## Current Status

The `GoalEditorViewModel` is fully implemented and ready to use, but `GoalEditorView` (3000+ lines) still uses direct `@State` properties instead of the ViewModel.

## Why Refactor?

1. **Separation of Concerns** - Move business logic out of the view
2. **Testability** - ViewModel can be unit tested independently
3. **Readability** - Reduce the massive view file to just UI code
4. **Maintainability** - Easier to find and modify specific logic
5. **Reusability** - Logic can be shared or reused elsewhere

## ViewModel Features

The `GoalEditorViewModel` already includes:

✅ All core state properties (userInput, duration, stages, etc.)
✅ Goal type support (.time, .count, .calories)
✅ Primary metric targets for count/calorie goals
✅ Checklist items with notes support (ChecklistItemData)
✅ Daily targets per weekday
✅ HealthKit integration
✅ Weather triggers
✅ Scheduling (day/time preferences, active days)
✅ Theme and icon selection
✅ Validation with user-friendly messages
✅ Helper methods (calculateWeeklyTarget, validatePrimaryMetricTarget, etc.)
✅ Template application
✅ Load from existing goal

## Refactoring Steps

### Phase 1: Preparation
- [x] Update ViewModel with all new properties
- [x] Add ChecklistItemData struct support
- [x] Add goal type and metric properties
- [x] Add validation and helper methods
- [x] Build and verify ViewModel compiles

### Phase 2: Integration (TODO)
1. Add `@State private var viewModel: GoalEditorViewModel` to GoalEditorView
2. Create initializer:
   ```swift
   init(existingGoal: Goal? = nil) {
       self.existingGoal = existingGoal
       _viewModel = State(initialValue: GoalEditorViewModel(existingGoal: existingGoal))
   }
   ```
3. Replace all @State properties with viewModel properties:
   - `userInput` → `viewModel.userInput`
   - `selectedGoalType` → `viewModel.selectedGoalType`
   - `primaryMetricTarget` → `viewModel.primaryMetricTarget`
   - `checklistItems` → `viewModel.checklistItems`
   - etc. (50+ properties to migrate)

### Phase 3: Logic Migration (TODO)
1. Move computed properties to ViewModel:
   - `goalTypeUnit` → ViewModel
   - `calculatedWeeklyTarget` → ViewModel (already done)
   - `hasUnsavedChanges` → ViewModel (already done)
   
2. Move validation functions to ViewModel:
   - `validatePrimaryMetricTarget()` → ViewModel (already done)
   - Other validation logic
   
3. Move business logic functions to ViewModel:
   - `applyTemplate()` → ViewModel (already done)
   - `loadGoalData()` → ViewModel's `loadFromExistingGoal()` (already done)
   - Theme/icon inference logic → ViewModel helpers (already done)

### Phase 4: Testing (TODO)
1. Build and fix any compilation errors
2. Test all user flows:
   - Creating new goals
   - Editing existing goals
   - Template application
   - Goal type switching
   - Checklist management
   - Validation scenarios
3. Add unit tests for ViewModel

## Migration Complexity

- **File Size**: 3,279 lines
- **State Properties**: ~50 @State variables to migrate
- **Functions**: ~30 functions to review and possibly migrate
- **Risk**: High - many interconnected UI bindings
- **Time Estimate**: 4-6 hours of careful refactoring

## Recommendation

**IMPORTANT**: Automated refactoring was attempted and reverted due to complexity.

This refactoring should be done:
1. **Manually** - The file is too complex for safe automated refactoring
2. **In a separate branch** to allow thorough testing
3. **Incrementally** - migrate one section at a time (e.g., start with just goal type properties)
4. **With comprehensive testing** after each migration step
5. **During a low-priority period** when breaking changes can be tolerated

## Why Manual Refactoring is Needed

- 3,276 lines with complex nested SwiftUI views
- 50+ @State properties with hundreds of references
- Complex bindings ($property syntax) throughout
- Computed properties and functions that reference state
- Risk of breaking UI bindings if not done carefully

## Alternative Approach: Hybrid Model

Since full migration is too risky, consider this pragmatic approach:

### Option 1: Keep Both (Recommended for Safety)
- Keep existing @State properties in GoalEditorView (working code)
- Use ViewModel only for NEW features going forward
- Gradually migrate sections when touching that code anyway
- No risk of breaking existing functionality

### Option 2: Extract Sections Into Separate Views
Instead of migrating the monolithic view, break it into smaller views:
- `GoalTypeSection` - uses its own ViewModel
- `ChecklistSection` - uses its own ViewModel  
- `ScheduleSection` - uses its own ViewModel
- Each section is independently testable
- Much safer than all-at-once migration

### Option 3: Delete the ViewModel
If it's not going to be used, remove it to reduce maintenance burden.

## Current Workaround

The ViewModel is ready and waiting. For now:
- GoalEditorView continues to work with direct @State
- Helper classes (GoalEditorHelpers.swift) are available
- ViewModel can be used for new features
- When time allows, complete the migration (or use hybrid approach)

## Benefits of Completing Migration

Once complete, adding new features becomes much easier:
- New validation rules: just update ViewModel
- New goal types: update ViewModel enum and logic
- Testing business logic: no UI needed
- Sharing logic: import ViewModel elsewhere
