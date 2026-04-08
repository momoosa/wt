import SwiftUI
import MomentumKit

struct CompletionBehaviorsSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color

    var body: some View {
        Section(header: Text("When Daily Goal Completes")) {
            ForEach(Goal.CompletionBehavior.allCases) { behavior in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedCompletionBehaviors.contains(behavior) },
                    set: { isOn in
                        if isOn {
                            viewModel.selectedCompletionBehaviors.insert(behavior)
                        } else {
                            viewModel.selectedCompletionBehaviors.remove(behavior)
                        }
                        HapticFeedbackManager.trigger(.light)
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: behavior.icon)
                            .font(.body)
                            .foregroundStyle(viewModel.selectedCompletionBehaviors.contains(behavior) ? activeThemeColor : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(behavior.displayName)
                                .font(.subheadline)
                            Text(behavior.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(activeThemeColor)
            }
        }
    }
}
