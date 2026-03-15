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
    @AppStorage("useGradientOutline") private var useGradientOutline: Bool = false
    
    var body: some View {
        let themePreset = session.goal?.primaryTag?.themePreset ?? themePresets[0]
        let useOutline = useGradientOutline && colorScheme == .dark
        
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
            isRecommended: true,
            useGradientAccents: useOutline
        )
        .padding()
        .foregroundStyle(useOutline ? .primary : themePreset.textColor(for: colorScheme))
        .listRowInsets(EdgeInsets())
        .listRowBackground(
            Group {
                if useOutline {
                    // Gradient outline style
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(
                            themePreset.gradient,
                            lineWidth: 5
                        )
                        .background(
                            Color(.systemBackground)
                                .opacity(0.5)
                                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        )
                } else {
                    // Filled gradient style
                    themePreset.gradient
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                }
            }
        )
    }
}
