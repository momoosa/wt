import SwiftUI
import SwiftData
import WeektimeKit

struct ChecklistDetailView: View {
    var session: GoalSession
    @Environment(\.editMode) private var editMode
    @Environment(\.modelContext) private var modelContext
    var animation: Namespace.ID

    var body: some View {
            List(session.checklist, id: \.id) { item in
                ChecklistRow(item: item)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        item.isCompleted.toggle()
                    }
                }
            }

            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Checklist Item") {
                        addChecklistItem(to: session)
                    }
                }
                }
            
        .navigationTransition(.zoom(sourceID: session.id, in: animation))
        .onDisappear {
            let emptyItems = session.checklist.filter { $0.checklistItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for item in emptyItems {
                if let index = session.checklist.firstIndex(where: { $0.id == item.id }) {
                    session.checklist.remove(at: index)
                }
                modelContext.delete(item)
                modelContext.delete(item.checklistItem)
            }
        }
    }

    private func addChecklistItem(to session: GoalSession) {
        let item = ChecklistItem(title: "")
        let checklistSession = ChecklistItemSession(checklistItem: item, isCompleted: false, session: session)
        session.checklist.append(checklistSession)
        modelContext.insert(checklistSession)
    }
}
