import SwiftUI
import MomentumKit

struct ScheduleSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    @FocusState.Binding var focusedField: GoalEditorView.Field?
    @Binding var expandedDay: Int?
    let activeThemeColor: Color
    let onToggleTime: (Int, TimeOfDay) -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Goal type picker section (extracted component)
                GoalTypeSection(
                    selectedType: $viewModel.selectedGoalType,
                    primaryMetricTarget: $viewModel.primaryMetricTarget,
                    calculatedWeeklyTarget: viewModel.calculatedWeeklyTarget,
                    activeThemeColor: activeThemeColor,
                    goalTypeUnit: viewModel.goalTypeUnit,
                    targetSuggestions: viewModel.targetSuggestions,
                    onTypeChange: viewModel.handleGoalTypeChange
                )

                Divider()

                // Schedule configuration
                ScheduleDaysListSection(
                    viewModel: viewModel,
                    focusedField: $focusedField,
                    expandedDay: $expandedDay,
                    activeThemeColor: activeThemeColor,
                    onToggleTime: onToggleTime
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text(viewModel.selectedGoalType == .time ? "Weekly Goal" : "Goal & Schedule")
        } footer: {
            if viewModel.selectedGoalType != .time {
                Text("Select which days and times you want to be reminded about this goal. Your daily target of \(Int(viewModel.primaryMetricTarget)) \(viewModel.goalTypeUnit) applies to all selected days.")
            }
        }
    }
}
