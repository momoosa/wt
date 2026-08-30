# Reminders List Sync Feature - Implementation Plan

## Overview
Link an Apple Reminders list to a Goal's checklist. When linked, the Reminders list items become the Goal's checklist items with two-way sync — checking off in the app completes in Reminders and vice versa. Pro feature.

## Model Changes

### 1. `Goal.swift` (MomentumKit) — Add 2 stored properties
- `linkedRemindersListID: String?` — the `calendarIdentifier` of the linked EKCalendar (Reminders list)
- `linkedRemindersLastSynced: Date?` — timestamp of last successful sync

### 2. `ChecklistItem.swift` (MomentumKit) — Add 1 stored property
- `remindersIdentifier: String?` — the `calendarItemIdentifier` of the linked EKReminder, used to sync completion status back

## New Files

### 3. `RemindersListLinkSheet.swift` — New UI file (~200 lines)
A sheet presented from the `GoalSessionDetailView` checklist section header.

**UI (matching the screenshot):**
- Title: "Link a Reminders list" with checklist icon
- Subtitle explaining sync behavior
- List of all Reminders lists (EKCalendar), each showing:
  - Colored dot (calendar.cgColor)
  - List name (calendar.title)
  - Item count + preview of first 2-3 item titles (truncated)
  - Checkmark if selected
- Bottom: "Link [ListName]" primary button + "Unlink list" text button (if already linked)

**Flow:**
- On "Link": calls `RemindersSyncService.linkList(...)` which replaces goal's checklist items with reminders from the list, then syncs to existing sessions
- On "Unlink": clears `goal.linkedRemindersListID`, keeps existing checklist items as-is (they become standalone)

### 4. `RemindersSyncService.swift` — New sync logic file (~180 lines)
Handles the actual two-way sync between a Goal's checklist and a Reminders list.

**Key methods:**
- `linkList(calendarID:, to goal:, context:)` — Initial link: fetch all incomplete reminders from the list, replace goal's checklist items, set `linkedRemindersListID`
- `syncIfLinked(goal:, session:, context:)` — Two-way sync: pull new/changed reminders, push completion status
- `pushCompletionToReminders(item:, isCompleted:)` — Mark/unmark a single reminder in EventKit when user toggles in the app

**Sync logic (for `syncIfLinked`):**
1. Fetch all reminders (completed + incomplete) from the linked calendar
2. For each reminder in the list:
   - If no matching ChecklistItem exists (by `remindersIdentifier`): create a new ChecklistItem + ChecklistItemSession for today
   - If matching ChecklistItem exists: update title if changed
3. For each ChecklistItem with a `remindersIdentifier`:
   - If no matching reminder exists in the list: delete the ChecklistItem (it was removed in Reminders)
4. Sync completion for today's session:
   - If reminder is completed and today's ChecklistItemSession isn't → mark completed
   - If today's ChecklistItemSession is completed and reminder isn't → mark reminder completed
5. Update `goal.linkedRemindersLastSynced = Date()`

## Modifications to Existing Files

### 5. `RemindersManager.swift` — Add list-level operations
- `fetchAllLists() -> [EKCalendar]` — all reminder-type calendars
- `fetchReminders(in calendarID: String, includeCompleted: Bool) async throws -> [EKReminder]`
- `saveReminder(_ reminder: EKReminder) throws` — persist completion changes
- `calendar(for id: String) -> EKCalendar?` — lookup by identifier

### 6. `GoalSessionDetailView.swift` — Modify checklist section
In `checklistSection`, between the "CHECKLIST" header and the progress bar:
- When `goal.linkedRemindersListID != nil`: show linked list header row:
  - Colored dot(s) + list name + "synced X ago" + "Change" button
- When no list is linked: show a "Link Reminders" button (Pro-gated)
- Add `@State private var showingRemindersLinkSheet = false`
- Add `.sheet` for `RemindersListLinkSheet`
- Add `.task` to trigger `RemindersSyncService.syncIfLinked()` on appear
- Wrap checklist item toggle to also call `pushCompletionToReminders()` for linked items

### 7. `SessionManagement.swift` — Trigger sync on daily refresh
In `refreshGoals()`, after creating sessions: if the goal has a `linkedRemindersListID`, trigger a sync to pick up overnight changes from Reminders.

## Sync Triggers
1. **GoalSessionDetailView appear** — `.task` calls sync
2. **Checklist item toggle** — immediately pushes completion to Reminders
3. **Daily session creation** — syncs to pick up changes since last open
4. **After linking/changing list** — full re-sync

## Pro Gating
- "Link Reminders" button shows lock icon for non-subscribers
- Tapping when not subscribed → `PremiumPaywallSheet`
- Uses existing `SubscriptionManager.shared.isSubscribed`

## File Summary
| File | Action | Est. Lines |
|------|--------|------------|
| `Goal.swift` | Modify — 2 properties | ~5 |
| `ChecklistItem.swift` | Modify — 1 property | ~3 |
| `RemindersManager.swift` | Modify — 4 methods | ~60 |
| `RemindersListLinkSheet.swift` | **New** | ~200 |
| `RemindersSyncService.swift` | **New** | ~180 |
| `GoalSessionDetailView.swift` | Modify — header + sync | ~80 |
| `SessionManagement.swift` | Modify — sync trigger | ~10 |
