import SwiftUI

struct ChecklistSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color
    
    var body: some View {
        Section(header: Text("Checklist")) {
            ForEach($viewModel.checklistItems) { $item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                        TextField("Title", text: $item.title)
                        Spacer()
                        Button {
                            if let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) {
                                viewModel.checklistItems.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    
                    TextField("Notes (optional)", text: $item.notes, axis: .vertical)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2...4)
                        .padding(.leading, 28)
                }
            }
            
            // Add new item
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                    TextField("Add checklist item...", text: $viewModel.newChecklistItemTitle)
                        .onSubmit {
                            if !viewModel.newChecklistItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                viewModel.checklistItems.append(ChecklistItemData(
                                    title: viewModel.newChecklistItemTitle,
                                    notes: viewModel.newChecklistItemNotes
                                ))
                                viewModel.newChecklistItemTitle = ""
                                viewModel.newChecklistItemNotes = ""
                            }
                        }
                    
                    if !viewModel.newChecklistItemTitle.isEmpty {
                        Button {
                            if !viewModel.newChecklistItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                viewModel.checklistItems.append(ChecklistItemData(
                                    title: viewModel.newChecklistItemTitle,
                                    notes: viewModel.newChecklistItemNotes
                                ))
                                viewModel.newChecklistItemTitle = ""
                                viewModel.newChecklistItemNotes = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(activeThemeColor)
                        }
                    }
                }
                
                TextField("Notes for new item (optional)", text: $viewModel.newChecklistItemNotes, axis: .vertical)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2...4)
                    .padding(.leading, 28)
            }
        }
    }
}
