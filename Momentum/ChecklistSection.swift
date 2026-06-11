import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChecklistSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color
    @State private var showPastedCount: Int?
    
    var body: some View {
        Section(header: checklistHeader) {
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
                        .lineLimit(2...20)
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
    
    private var checklistHeader: some View {
        HStack {
            Text("Checklist")
            Spacer()
            if let count = showPastedCount {
                Text("\(count) item\(count == 1 ? "" : "s") added")
                    .font(.caption)
                    .foregroundStyle(activeThemeColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            Button {
                pasteListFromClipboard()
            } label: {
                Label("Paste List", systemImage: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(activeThemeColor)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func pasteListFromClipboard() {
        #if canImport(UIKit)
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        #else
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        #endif
        
        let countBefore = viewModel.checklistItems.count
        withAnimation(AnimationPresets.quickSpring) {
            viewModel.importChecklistFromText(text)
        }
        let added = viewModel.checklistItems.count - countBefore
        
        if added > 0 {
            HapticFeedbackManager.trigger(.success)
            withAnimation {
                showPastedCount = added
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showPastedCount = nil
                }
            }
        }
    }
}
