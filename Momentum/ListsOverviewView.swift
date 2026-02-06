import SwiftUI
import SwiftData
import MomentumKit

struct ListsOverviewView: View {
    @Bindable var session: GoalSession
    @Binding var selectedListID: String?
    let tintColor: Color

    var body: some View {
        VStack {
            IntervalListSelector(lists: session.intervalLists, selectedListID: $selectedListID, tintColor: tintColor)
            TabView(selection: $selectedListID) {
                
                ForEach(session.intervalLists) { listSession in
                    List {
                        IntervalListView(listSession: listSession, activeIntervalID: .constant(nil), intervalStartDate: .constant(nil), intervalElapsed: .constant(10), uiTimer: .constant(nil))
                    }
                    .tag(listSession.id)
                }
            }
            .tabViewStyle(.page)
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.inline)
    }

}

/*
#Preview {
    // Replace the below with appropriate mock models as needed
    // struct MockGoalSession: GoalSession { ... }
    // @State static var selectedListID: PersistentIdentifier? = nil
    // ListsOverviewView(session: mockSession, selectedListID: $selectedListID, tintColor: .blue)
    Text("Preview not available")
}
*/
