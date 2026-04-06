# Composition-Based Refactoring Guide

## The Safe Way to Refactor GoalEditorView

Instead of trying to migrate everything at once, we can incrementally extract sections as reusable components while keeping the existing @State properties.

## Strategy

1. **Keep existing @State** - Don't remove anything that works
2. **Extract UI sections** - Pull out view code into separate structs
3. **Use bindings** - Pass `$property` bindings to child views
4. **ViewModel is optional** - Can coexist with @State during migration

## Example: Extract Goal Type Section

### Current Code (in GoalEditorView.swift, around line 156)

```swift
// Inside GoalEditorView body
@ViewBuilder
private var scheduleSection: some View {
    Section {
        VStack(alignment: .leading, spacing: 16) {
            // Goal type picker at the top
            VStack(alignment: .leading, spacing: 12) {
                Picker("Goal Type", selection: $selectedGoalType) {
                    ForEach(Goal.GoalType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedGoalType) { _, newType in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        handleGoalTypeChange(newType)
                    }
                }

                // Animated target field that morphs between weekly and daily
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedGoalType == .time ? "Weekly Target" : "Daily Target")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if selectedGoalType == .time {
                                Text("\(calculatedWeeklyTarget)")
                                    .foregroundStyle(activeThemeColor)
                                    // ...
                            } else {
                                TextField("Target", value: $primaryMetricTarget, format: .number)
                                    .keyboardType(.numberPad)
                                    // ...
                            }
                            
                            Text(selectedGoalType == .time ? "min" : goalTypeUnit)
                                .foregroundStyle(activeThemeColor)
                        }
                    }
                }
            }
            // ... more code
        }
    }
}
```

### Refactored: Extract as Component

**Step 1: Create the extracted component**

```swift
// New file: GoalTypeSection.swift
struct GoalTypeSection: View {
    // Bindings to parent state
    @Binding var selectedType: Goal.GoalType
    @Binding var primaryMetricTarget: Double
    
    let calculatedWeeklyTarget: Int
    let activeThemeColor: Color
    let goalTypeUnit: String
    let targetSuggestions: [Int]
    let onTypeChange: (Goal.GoalType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Goal Type", selection: $selectedType) {
                ForEach(Goal.GoalType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedType) { _, newType in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    onTypeChange(newType)
                }
            }

            // Animated target field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(selectedType == .time ? "Weekly Target" : "Daily Target")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if selectedType == .time {
                            Text("\(calculatedWeeklyTarget)")
                                .foregroundStyle(activeThemeColor)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 100, alignment: .trailing)
                        } else {
                            TextField("Target", value: $primaryMetricTarget, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text(selectedType == .time ? "min" : goalTypeUnit)
                            .foregroundStyle(activeThemeColor)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedType)
            }
            
            // Quick suggestion buttons
            if selectedType != .time {
                HStack(spacing: 8) {
                    Text("Common:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(targetSuggestions, id: \.self) { suggestion in
                        Button {
                            primaryMetricTarget = Double(suggestion)
                        } label: {
                            Text("\(suggestion.formatted())")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(activeThemeColor.opacity(0.1))
                                .foregroundStyle(activeThemeColor)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
}
```

**Step 2: Use it in GoalEditorView**

```swift
struct GoalEditorView: View {
    // ... existing @State properties ...
    
    @ViewBuilder
    private var scheduleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Use the extracted component
                GoalTypeSection(
                    selectedType: $selectedGoalType,
                    primaryMetricTarget: $primaryMetricTarget,
                    calculatedWeeklyTarget: calculatedWeeklyTarget,
                    activeThemeColor: activeThemeColor,
                    goalTypeUnit: goalTypeUnit,
                    targetSuggestions: targetSuggestions,
                    onTypeChange: handleGoalTypeChange
                )
                
                // Rest of schedule section...
            }
        }
    }
}
```

## Benefits of This Approach

1. **No breaking changes** - Existing code continues to work
2. **Incremental** - Extract one section at a time
3. **Testable** - Each extracted component can be tested in isolation
4. **Reusable** - Components can be used elsewhere
5. **Reduces file size** - Main view gets smaller over time
6. **Low risk** - If extraction fails, just revert that one component

## Other Sections to Extract

Once goal type works, extract these sections:

### 1. Checklist Section
```swift
struct ChecklistSection: View {
    @Binding var items: [ChecklistItemData]
    var onAdd: () -> Void
    var onRemove: (UUID) -> Void
}
```

### 2. Weather Triggers Section
```swift
struct WeatherTriggersSection: View {
    @Binding var weatherEnabled: Bool
    @Binding var selectedConditions: Set<WeatherCondition>
    @Binding var hasMinTemp: Bool
    @Binding var minTemp: Double
    @Binding var hasMaxTemp: Bool
    @Binding var maxTemp: Double
}
```

### 3. Schedule Section
```swift
struct ScheduleSection: View {
    @Binding var activeDays: Set<Int>
    @Binding var dayTimePreferences: [Int: Set<TimeOfDay>]
    let weekdays: [String]
}
```

### 4. Theme Selection Section
```swift
struct ThemeSelectionSection: View {
    @Binding var selectedTheme: GoalTag?
    @Binding var selectedTags: [GoalTag]
    let allTags: [GoalTag]
    var onShowColorPicker: () -> Void
    var onShowIconPicker: () -> Void
}
```

## Migration Path

1. **Phase 1**: Extract 2-3 sections as components
2. **Phase 2**: Test thoroughly
3. **Phase 3**: Extract remaining sections
4. **Phase 4** (optional): Introduce ViewModel for new sections
5. **Phase 5** (optional): Gradually migrate @State to ViewModel

## Key Principles

- **Pure views** - Components should only handle UI, no business logic
- **Bindings only** - Pass `@Binding` for two-way data flow
- **Computed properties** - Pass pre-computed values (don't recompute in child)
- **Callbacks for actions** - Use closures like `onTypeChange: (Type) -> Void`
- **Keep it simple** - Don't over-engineer, just extract the view code

## When to Stop

You don't have to extract everything! Stop when:
- The main view is a manageable size (~500-1000 lines)
- Each section is independently testable
- Code is easier to navigate and understand

The goal isn't perfection - it's making the codebase more maintainable.
