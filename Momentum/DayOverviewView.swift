import SwiftUI
import SwiftData
import MomentumKit

struct DayOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let day: Day
    let sessions: [GoalSession]
    let goals: [Goal]

    private var dailyProgress: Double {
        guard totalDailyTarget > 0 else { return 0 }
        return min(Double(totalDailyMinutes) / Double(totalDailyTarget), 1.0)
    }

    private var totalDailyMinutes: Int {
        Int(sessions.reduce(0.0) { $0 + $1.elapsedTime } / 60)
    }

    private var totalDailyTarget: Int {
        var total = 0
        for session in sessions {
            // Skip if session or goal has been deleted
            guard session.status != .skipped else { continue }

            // Skip archived goals
            guard session.goal.status != .archived else { continue }

            // Use cached daily target (already calculated from weekly target / 7 if needed)
            total += Int(session.dailyTarget / 60)
        }
        return total
    }

    private var completedGoalsCount: Int {
        sessions.filter { session in
            guard session.status != .skipped else { return false }
            // Skip archived goals
            guard session.goal.status != .archived else { return false }
            return session.hasMetDailyTarget
        }.count
    }

    private var totalActiveGoals: Int {
        sessions.filter { session in
            guard session.status != .skipped else { return false }
            // Skip archived goals
            guard session.goal.status != .archived else { return false }
            return true
        }.count
    }

    // Get all historical sessions from all goals, grouped by hour with time ranges
    private var groupedHistoricalSessions: [(startHour: Int, endHour: Int, sessions: [HistoricalSession])] {
        let allHistoricalSessions = sessions.flatMap { $0.historicalSessions }
        let calendar = Calendar.current

        // Group by hour
        let grouped = Dictionary(grouping: allHistoricalSessions) { session -> Int in
            calendar.component(.hour, from: session.startDate)
        }

        // Sort by hour (numerically) and calculate time ranges
        return grouped.sorted { $0.key < $1.key }
            .map { hour, sessions in
                let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
                
                // Find the earliest start and latest end time in this hour group
                let startHour = hour
                let latestEndDate = sortedSessions.map { $0.endDate }.max() ?? Date()
                let endHour = calendar.component(.hour, from: latestEndDate)
                
                return (startHour: startHour, endHour: endHour, sessions: sortedSessions)
            }
    }
    
    // Helper to get goal title for a historical session
    private func goalTitle(for historicalSession: HistoricalSession) -> String? {
        // Get the first goal ID from the session
        guard let firstGoalID = historicalSession.goalIDs.first,
              let uuid = UUID(uuidString: firstGoalID),
              let goal = goals.first(where: { $0.id == uuid }) else {
            return nil
        }
        return goal.title
    }

    var body: some View {
        NavigationStack {
            List {
                // Progress Summary Card
                Section {
                    progressSummaryCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listSectionSpacing(.compact)

                // Historical Sessions by Hour
                if !groupedHistoricalSessions.isEmpty {
                    ForEach(groupedHistoricalSessions, id: \.startHour) { group in
                        Section {
                            ForEach(group.sessions) { historicalSession in
                                HistoricalSessionRow(
                                    session: historicalSession,
                                    showsTimeSummaryInsteadOfTitle: false,
                                    allSessions: group.sessions,
                                    goalTitle: goalTitle(for: historicalSession)
                                )
                            }
                        } header: {
                            Text(formatTimeRange(startHour: group.startHour, endHour: group.endHour))
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView {
                            Label("No Activity Yet", systemImage: "clock")
                        } description: {
                            Text("Start tracking your goals to see your progress here")
                        }
                    }
                }
            }
            .navigationTitle("Today's Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var progressSummaryCard: some View {
        VStack(spacing: 20) {
            // Large circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: dailyProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dailyProgress)

                VStack(spacing: 4) {
                    Text("\(Int(dailyProgress * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("\(totalDailyMinutes)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(completedGoalsCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Goals Done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(totalActiveGoals)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Total Goals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatTimeRange(startHour: Int, endHour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        
        let calendar = Calendar.current
        let startDate = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: Date()) ?? Date()
        
        // If end hour is the same as start hour, just show single hour
        if startHour == endHour {
            return formatter.string(from: startDate)
        }
        
        // Show range
        let endDate = calendar.date(bySettingHour: endHour, minute: 59, second: 59, of: Date()) ?? Date()
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        return "\(startString) - \(endString)"
    }

}
