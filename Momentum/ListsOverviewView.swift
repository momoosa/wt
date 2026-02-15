import SwiftUI
import SwiftData
import MomentumKit

struct ListsOverviewView: View {
    @Bindable var session: GoalSession
    @Binding var selectedListID: String?
    let tintColor: Color
    let timerManager: SessionTimerManager
    
    // Interval playback state
    @State private var activeIntervalID: String? = nil
    @State private var intervalStartDate: Date? = nil
    @State private var intervalElapsed: TimeInterval = 0
    @State private var uiTimer: Timer? = nil

    var body: some View {
        VStack {
            IntervalListSelector(lists: session.intervalLists, selectedListID: $selectedListID, tintColor: tintColor)
            TabView(selection: $selectedListID) {
                
                ForEach(session.intervalLists) { listSession in
                    List {
                        IntervalListView(listSession: listSession, activeIntervalID: $activeIntervalID, intervalStartDate: $intervalStartDate, intervalElapsed: $intervalElapsed, uiTimer: $uiTimer, timerManager: timerManager, goalSession: session)
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
