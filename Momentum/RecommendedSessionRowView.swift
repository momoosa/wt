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
        SessionRowView(
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
       
        .foregroundStyle(session.goal.primaryTag.themePreset.textColor)
        .listRowInsets(EdgeInsets())
        .listRowBackground(session.goal.primaryTag.themePreset.gradient)
    }
}
