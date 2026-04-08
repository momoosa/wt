import SwiftUI
import MomentumKit

struct ScheduleDaysListSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    @FocusState.Binding var focusedField: GoalEditorView.Field?
    @Binding var expandedDay: Int?
    let activeThemeColor: Color
    let onToggleTime: (Int, TimeOfDay) -> Void

    private let weekdays = WeekdayConstants.weekdays

    var body: some View {
        VStack(spacing: 8) {
            ForEach(weekdays, id: \.0) { weekday, name in
                ExpandableDayRow(
                    weekday: weekday,
                    name: name,
                    isActive: viewModel.isDayActive(weekday),
                    minutes: viewModel.dailyTargets[weekday] ?? 30,
                    selectedTimes: viewModel.dayTimePreferences[weekday] ?? [],
                    themeColor: activeThemeColor,
                    isExpanded: expandedDay == weekday,
                    showMinutes: viewModel.selectedGoalType == .time,
                    focusedField: $focusedField,
                    onToggleDay: { viewModel.toggleActiveDay(weekday) },
                    onUpdateMinutes: { viewModel.updateDailyTarget(for: weekday, minutes: $0) },
                    onToggleTime: { onToggleTime(weekday, $0) },
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedDay = (expandedDay == weekday) ? nil : weekday
                        }
                    }
                )

                if weekday != weekdays.last?.0 {
                    Divider()
                }
            }
        }
    }
}
