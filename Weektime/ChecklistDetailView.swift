import SwiftUI
import SwiftData
import WeektimeKit

struct ChecklistDetailView: View {
    var session: GoalSession
    @Environment(\.editMode) private var editMode
    @Environment(\.modelContext) private var context
    var animation: Namespace.ID
    let historicalSessionLimit = 3
    var body: some View {
        List {
   
            Section {
                if !session.historicalSessions.isEmpty {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { session in
                        HistoricalSessionRow(session: session, showsRelativeTimeInsteadOfTitle: true)
                            .foregroundStyle(.primary)
                            .swipeActions {
                                Button {
                                    withAnimation {
                                        
                                        // TODO:
                                        //                                        session.day.delete(historicalSessionIDs: [session.id])
                                        
                                        context.delete(session)
                                        Task {
                                            try context.save()
                                        }
                                    }
                                } label: {
                                    Label {
                                                   Text("Delete")
                                               } icon: {
                                                   Image(systemName: "xmark.bin")
                                               }
                                               
                                           }
                                           .tint(.red)
                                           
                                       }
                               }
                           } else {
                               ContentUnavailableView {
                                   Text("No progress for this goal today.")
                               } description: {
                                   
                               } actions: {
                                   Button {
                                       
                                   } label: {
                                       Text("Add manual entry")
                                   }
                               }

                           }
                       } header: {
                           HStack {
                               Text("History")
                               Text("\(session.historicalSessions.count)")
                                   .font(.caption2)
                                   .foregroundStyle(Color(.systemBackground))
                                   .padding(4)
                                   .frame(minWidth: 20)
                                   .background(Capsule()
                                    .fill(session.goal.primaryTheme.theme.dark))
                               Spacer()
                               Button {
           //                      TODO:  dayToEdit = day
                               } label: {
                                   Image(systemName: "plus.circle.fill")
                                       .symbolRenderingMode(.hierarchical)
                               }
                           }
                       } footer: {
                           if session.historicalSessions.count > historicalSessionLimit {
                               HStack {
                                   Spacer()
                                   Button {
                                       //                            dayToEdit = day
                                   } label: {
                                           Text("View all")
                                   }
           //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
                                   Spacer()
                               }
                           }
                       }

                   

            Section {
                ForEach(session.checklist, id: \.id) { item in
                    ChecklistRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                item.isCompleted.toggle()
                            }
                        }
                }
            } header: {
                HStack {
                    Text("To do")
                    Text("\(session.checklist.filter { $0.isCompleted }.count)/\(session.checklist.count)")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(4)
                        .background(Capsule()
                            .fill(session.goal.primaryTheme.theme.dark))
                        Spacer()
                    Button {
                        addChecklistItem(to: session)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            } footer: {
                if session.historicalSessions.count > historicalSessionLimit {
                    HStack {
                        Spacer()
                        Button {
                            //                            dayToEdit = day
                        } label: {
                                Text("View all")
                        }
//                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
                        Spacer()
                    }
                }
            }
        }
        
            .scrollContentBackground(.hidden)
            .background(session.goal.primaryTheme.theme.dark.opacity(0.1))
            .navigationTitle(session.goal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        
                        Button {
                            withAnimation {
                                session.goal.status = .archived
                            }
                        } label: {
                            if session.goal.status == .archived {
                                Text("Unarchive")
                            } else {
                                Text("Archive")
                            }
                        }
                    } label: {

                        Image(systemName: "ellipsis.circle.fill")
                            .symbolRenderingMode(.hierarchical)

                    }

                
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
//                                        self.goalToEdit = goal
                                        
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .symbolRenderingMode(.hierarchical)

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
                context.delete(item)
                context.delete(item.checklistItem)
            }
        }
    }

    private func addChecklistItem(to session: GoalSession) {
        let item = ChecklistItem(title: "")
        let checklistSession = ChecklistItemSession(checklistItem: item, isCompleted: false, session: session)
        session.checklist.append(checklistSession)
        context.insert(checklistSession)
    }
}
