import SwiftUI
import SwiftData
import MomentumKit

struct RecommendedSessionRowView: View {
    let session: GoalSession
    let day: Day
    let index: Int
    let timerManager: SessionTimerManager?
    let animation: Namespace.ID
    @Binding var selectedSession: GoalSession?
    @Binding var sessionToLogManually: GoalSession?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sessionActions) private var sessionActions
    @Environment(GoalStore.self) private var goalStore
    
    private var themePreset: ThemePreset { session.theme }
    private var foreground: Color { themePreset.foregroundColor(for: colorScheme) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Number + Category + TOP PICK badge
            HStack {
                Text(session.title)
                    .font(.title2.bold())
                    .foregroundStyle(foreground)

                Spacer()
                
                Text("\(Self.ordinalFormatter.string(from: index as NSNumber) ?? "\(index)") PICK".uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(foreground.opacity(0.15), in: Capsule())
            }
            .foregroundStyle(foreground.opacity(0.8))
            
            // Row 2: Title
            
            // Row 3: Reason chips
            let reasons = Array(session.recommendationReasons.prefix(3))
            if !reasons.isEmpty {
                HStack(spacing: 6) {
                    ForEach(reasons, id: \.self) { reason in
                        HStack(spacing: 3) {
                            Image(systemName: iconForReason(reason))
                                .font(.system(size: 8))
                            Text(reason.displayName.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.3)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(foreground.opacity(0.15), in: Capsule())
                    }
                }
                .foregroundStyle(foreground.opacity(0.9))
            }
            
            // Row 4: Explanation text
            if let reasoning = session.plannedReasoning {
                Text(reasoning)
                    .font(.caption)
                    .foregroundStyle(foreground.opacity(0.7))
                    .lineLimit(2)
            }
            
            // Row 5: SESSION label + duration + play button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION")
                        .font(.caption2.weight(.medium))
                        .tracking(0.5)
                        .foregroundStyle(foreground.opacity(0.6))
                    
                    Text(formattedTargetDuration)
                        .font(.title.bold())
                        .foregroundStyle(foreground)
                }
                
                Spacer()
                
                Button {
                    timerManager?.toggleTimer(for: session, in: day)
                } label: {
                    let isActive = timerManager?.activeSession?.id == session.id
                    Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(foreground)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .listRowInsets(EdgeInsets())
        .listRowBackground(
            themePreset.gradient(for: colorScheme)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        )
        .onTapGesture {
            HapticFeedbackManager.trigger(.light)
            withAnimation(AnimationPresets.quickSpring) {
                selectedSession = session
            }
        }
        .matchedTransitionSource(id: session.id, in: animation)
        .swipeActions {
            Button {
                HapticFeedbackManager.trigger(.medium)
                sessionActions.onSkip(session)
            } label: {
                Label(session.status == .skipped ? "Reactivate" : "Skip", systemImage: "xmark.circle.fill")
            }
            .tint(.orange)
        }
    }
    
    // MARK: - Helpers
    
    private static let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()
    
    private var formattedTargetDuration: String {
        let totalSeconds = session.unifiedTargetValue
        let minutes = Int(totalSeconds / 60)
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
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
