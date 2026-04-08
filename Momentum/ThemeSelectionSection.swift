import SwiftUI
import MomentumKit

struct ThemeSelectionSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color

    var body: some View {
        Section(header: Text("Theme")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Color picker button
                    Button(action: {
                        viewModel.showingColorPicker = true
                    }) {
                        HStack(spacing: 8) {
                            // Color preview circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            viewModel.selectedColorPreset?.neon ?? activeThemeColor,
                                            viewModel.selectedColorPreset?.dark ?? activeThemeColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 24, height: 24)

                            Text(viewModel.selectedColorPreset?.title ?? "Color")
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    // Icon picker button
                    Button(action: {
                        viewModel.showingIconPicker = true
                    }) {
                        HStack(spacing: 8) {
                            // Icon preview
                            Image(systemName: viewModel.selectedIcon ?? "star.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(activeThemeColor)
                                .frame(width: 24, height: 24)

                            Text("Icon")
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                // Tag cloud with flow layout - show only selected themes
                TagFlowLayout(spacing: 8) {
                    ForEach(viewModel.selectedTags, id: \.title) { goalTheme in
                        ThemeTagButton(
                            goalTheme: goalTheme,
                            isSelected: true,
                            action: {
                                HapticFeedbackManager.trigger(.light)
                            },
                            onRemove: {
                                withAnimation(AnimationPresets.quickSpring) {
                                    viewModel.removeGoalTheme(goalTheme)
                                }
                                #if os(iOS)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.warning)
                                #endif
                            }
                        )
                    }

                    // Add theme button
                    Button(action: {
                        viewModel.showingAddThemeSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add Theme")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .strokeBorder(activeThemeColor, lineWidth: 2, antialiased: true)
                        )
                        .foregroundStyle(activeThemeColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)

                if viewModel.selectedTags.isEmpty {
                    Text("Tap 'Add Theme' to choose a color theme for your goal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
}
