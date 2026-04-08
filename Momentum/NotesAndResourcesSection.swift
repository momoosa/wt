import SwiftUI

struct NotesAndResourcesSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color

    var body: some View {
        Section(header: Text("Notes & Resources")) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Add any notes about this goal...", text: $viewModel.goalNotes, axis: .vertical)
                    .lineLimit(3...6)

                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                    TextField("Add a link here...", text: $viewModel.goalLink)
                        .keyboardType(.URL)
                        .autocapitalization(.none)

                    if !viewModel.goalLink.isEmpty, let url = URL(string: viewModel.goalLink), UIApplication.shared.canOpenURL(url) {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open Link")
                            }
                            .font(.caption)
                            .foregroundStyle(activeThemeColor)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
