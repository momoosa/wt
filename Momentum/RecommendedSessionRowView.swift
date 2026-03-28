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
        let themePreset = session.themePreset
        let useOutline = useGradientOutline && colorScheme == .dark
        
        return VStack(alignment: .leading, spacing: 12) {
            // Main session row
            SessionRowView(
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
            
            // Recommendation reasons - always show if we have any
            let reasons = Array(session.recommendationReasons.prefix(3))
            if !reasons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(reasons, id: \.self) { reason in
                        HStack(spacing: 4) {
                            Image(systemName: iconForReason(reason))
                                .font(.caption2)
                            Text(reason.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(useOutline ? Color.primary : Color.white.opacity(0.9))
                    }
                }
            } else {
                // If no reasons, show a default indicator
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("Recommended")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(useOutline ? Color.primary : Color.white.opacity(0.9))
            }
        }
        .padding()
        .foregroundStyle(useOutline ? .primary : themePreset.foregroundColor(for: colorScheme))
        .listRowInsets(EdgeInsets())
        .listRowBackground(
            Group {
                if useOutline {
                    // Gradient outline style
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(themePreset.gradient, lineWidth: 5)
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
    
    private func iconForReason(_ reason: RecommendationReason) -> String {
        switch reason {
        case .weeklyProgress: return "chart.line.uptrend.xyaxis"
        case .userPriority: return "star.fill"
        case .weather: return "sun.max.fill"
        case .availableTime: return "clock.fill"
        case .plannedTheme: return "calendar"
        case .quickFinish: return "flag.checkered"
        case .preferredTime: return "heart.fill"
        case .energyLevel: return "bolt.fill"
        case .usualTime: return "clock.arrow.circlepath"
        case .constrained: return "hourglass"
        }
    }
}
