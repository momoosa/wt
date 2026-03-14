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
    let onSyncHealthKit: (() -> Void)?
    let isSyncingHealthKit: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let themePreset = session.goal?.primaryTag?.themePreset ?? themePresets[0]
        
        return SessionRowView(
            session: session,
            day: day,
            timerManager: timerManager,
            animation: animation,
            selectedSession: $selectedSession,
            sessionToLogManually: $sessionToLogManually,
            onSkip: onSkip,
            onSyncHealthKit: onSyncHealthKit,
            isSyncingHealthKit: isSyncingHealthKit,
            isRecommended: true
        )
        .padding()
       
        .foregroundStyle(themePreset.textColor)
        .listRowInsets(EdgeInsets())
        .listRowBackground(
            themePreset.gradient
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        )
    }
}
