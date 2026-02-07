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
        VStack(alignment: .leading, spacing: 0) {
            // Session row card
            SessionRowView(
                session: session,
                day: day,
                timerManager: timerManager,
                animation: animation,
                selectedSession: $selectedSession,
                sessionToLogManually: $sessionToLogManually,
                onSkip: onSkip
            )
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 20.0)
                    .fill(Color(colorScheme == .dark ? .secondarySystemGroupedBackground : .tertiarySystemGroupedBackground))
            )
            .padding(8)

            // Reasoning badges (only show if we have recommendation reasons)
            if !session.recommendationReasons.isEmpty {
                reasoningBadgesView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
 
        .listRowInsets(EdgeInsets())
        .listRowBackground(            Color(colorScheme == .dark ? .tertiarySystemGroupedBackground : .secondarySystemGroupedBackground))
    }
    
    @ViewBuilder
    private func reasoningBadgesView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(session.recommendationReasons, id: \.rawValue) { reason in
                    reasoningBadge(reason: reason)
                }
            }
        }
    }
    
    private func reasoningBadge(reason: RecommendationReason) -> some View {
        HStack(spacing: 4) {
            Image(systemName: reason.icon)
                .font(.caption2)
            Text(reason.displayName)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.secondarySystemFill))
        )
    }
}
