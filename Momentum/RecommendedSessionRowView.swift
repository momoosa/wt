import SwiftUI
import SwiftData
import MomentumKit

struct RecommendedSessionRowView: View {
    let session: GoalSession
    let day: Day
    let timerManager: SessionTimerManager?
    let animation: Namespace.ID
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    let onSkip: (GoalSession) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let primaryTag = session.goal.primaryTag
        
        return SessionRowView(
            session: session,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: $selectedSession,
            sessionToLogManually: $sessionToLogManually,
            onSkip: onSkip,
            isRecommended: true
        )
        .padding()
       
        .foregroundStyle(primaryTag.themePreset.textColor)
        .listRowInsets(EdgeInsets())
        .listRowBackground(primaryTag.themePreset.gradient)
    }
}
