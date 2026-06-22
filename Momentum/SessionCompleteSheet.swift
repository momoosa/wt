//
//  SessionCompleteSheet.swift
//  Momentum
//
//  Celebration sheet shown when a session meets its daily target.
//

import SwiftUI
import MomentumKit

struct SessionCompleteSheet: View {
    let celebrationData: CelebrationData
    let onStartSuggested: (GoalSession) -> Void
    let onTakeBreak: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var themeColor: Color {
        celebrationData.theme.color(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header: checkmark + TARGET MET
            headerSection
            
            // Big stats: duration + goal title
            bigStatsSection
            
            // Three metric columns
            metricsCard
            
            // What's next?
            if let suggested = celebrationData.suggestedNextSession {
                whatsNextSection(session: suggested)
            }
            
            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(themeColor)
            
            Text("TARGET MET")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(themeColor)
        }
    }
    
    // MARK: - Big Stats
    
    private var bigStatsSection: some View {
        VStack(spacing: 4) {
            Text(formattedSessionDuration)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(celebrationData.goalTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Metrics Card
    
    private var metricsCard: some View {
        HStack(spacing: 0) {
            // Session duration
            metricColumn(
                value: "+\(formattedShortDuration)",
                label: "SESSION"
            )
            
            // Today done
            metricColumn(
                value: "\(celebrationData.todayDoneCount)✓",
                label: "TODAY · DONE"
            )
            
            // Streak
            metricColumn(
                value: "\(celebrationData.streak)",
                label: "\(celebrationData.streak)-DAY STREAK"
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }
    
    private func metricColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - What's Next
    
    private func whatsNextSection(session: GoalSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S NEXT?")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUGGESTED NEXT · LATER TODAY")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(session.theme.foregroundColor(for: colorScheme).opacity(0.7))
                    
                    Text(session.goal?.title ?? session.title)
                        .font(.headline)
                        .foregroundStyle(session.theme.foregroundColor(for: colorScheme))
                }
                
                Spacer()
                
                Button {
                    onStartSuggested(session)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(session.theme.foregroundColor(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(session.theme.gradient(for: colorScheme))
            )
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onTakeBreak()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer")
                        .font(.caption.weight(.semibold))
                    Text("5 min break")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
            
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("I'm done for now")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Formatting
    
    private var formattedSessionDuration: String {
        let totalSeconds = Int(celebrationData.sessionDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
        return "\(max(1, minutes)) min"
    }
    
    private var formattedShortDuration: String {
        let totalSeconds = Int(celebrationData.sessionDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }
}
