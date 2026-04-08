//
//  IntervalListView.swift
//  Momentum
//
//  Created by Mo Moosa on 28/11/2025.
//

import SwiftUI
import MomentumKit

/// Optimized row view for individual intervals
private struct IntervalRow: View {
    let item: IntervalSession
    let index: Int
    let totalCount: Int
    let isActive: Bool
    let elapsed: TimeInterval
    let themeLight: Color
    let onTogglePlayback: () -> Void
    
    private var currentIndex: Int { index + 1 }
    private var duration: TimeInterval { item.durationSeconds }
    private var progress: Double { 
        isActive ? min(max(elapsed / max(duration, 0.001), 0), 1) : 0
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let isCompleted = item.isCompleted
                    let displayElapsed: TimeInterval = {
                        if isCompleted { return duration }
                        return isActive ? min(elapsed, duration) : 0
                    }()
                    
                    Text("\(item.interval?.name ?? "Interval") \(currentIndex)/\(totalCount)")
                        .fontWeight(.semibold)
                        .strikethrough(isCompleted, pattern: .solid, color: .primary)
                        .opacity(isCompleted ? 0.6 : 1)
                    
                    if isCompleted {
                        Text("\(displayElapsed.formatted(style: .components))/\(duration.formatted(style: .components))")
                            .font(.caption)
                            .opacity(0.7)
                    } else {
                        let remaining = max(duration - displayElapsed, 0)
                        Text("\(remaining.formatted(style: .components)) remaining")
                            .font(.caption)
                            .opacity(0.7)
                    }
                }
                Spacer()
                Button(action: onTogglePlayback) {
                    Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(
            Color(.secondarySystemGroupedBackground)
                .overlay {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(themeLight.opacity(0.25))
                            .frame(width: geo.size.width * progress)
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }
                    .allowsHitTesting(false)
                }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                item.isCompleted.toggle()
            }
        }
    }
}

struct IntervalListView: View {
    @Binding var activeIntervalID: String?
    @Binding private var intervalStartDate: Date?
    @Binding private var intervalElapsed: TimeInterval
    @Binding private var uiTimer: Timer?
    let limit: Int?

    let listSession: IntervalListSession
    let timerManager: SessionTimerManager?
    let goalSession: GoalSession?
    
    // Pre-compute sorted intervals to avoid recomputing on every update
    private var sortedIntervals: [IntervalSession] {
        let allIntervals = (listSession.intervals ?? []).sorted(by: { ($0.interval?.orderIndex ?? 0) < ($1.interval?.orderIndex ?? 0) })
        if let limit {
            return Array(allIntervals.prefix(limit))
        }
        return allIntervals
    }
    
    // Cache whether all intervals are completed
    private var allIntervalsCompleted: Bool {
        (listSession.intervals ?? []).allSatisfy({ $0.isCompleted })
    }
    
    // Cache total count
    private var totalIntervalCount: Int {
        sortedIntervals.count
    }
    
    var body: some View {
        LazyVStack {
        Section {
            // Start All button when nothing is active
            if activeIntervalID == nil && !allIntervalsCompleted {
                Button {
                    startAllIntervals()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("Start All Intervals")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .foregroundStyle(listSession.themeNeon)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    listSession.themeNeon.opacity(0.1)
                )
            }
            
            ForEach(Array(sortedIntervals.enumerated()), id: \.element.id) { index, item in
                IntervalRow(
                    item: item,
                    index: index,
                    totalCount: totalIntervalCount,
                    isActive: activeIntervalID == item.id,
                    elapsed: activeIntervalID == item.id ? intervalElapsed : 0,
                    themeLight: listSession.themeLight,
                    onTogglePlayback: { toggleIntervalPlayback(for: item) }
                )
            }
        } footer: {
            if let limit {
                let totalCount = listSession.intervalCount
                let remaining = totalCount - limit
                if remaining > 0 {
                    Text("And \(remaining) more")
                }
            }
        }
            }
    }
    
    public init(listSession: IntervalListSession, activeIntervalID: Binding<String?>, intervalStartDate: Binding<Date?>, intervalElapsed: Binding<TimeInterval>, uiTimer: Binding<Timer?>, timerManager: SessionTimerManager? = nil, goalSession: GoalSession? = nil, limit: Int? = nil) {
        self._activeIntervalID = activeIntervalID
        self._intervalStartDate = intervalStartDate
        self._intervalElapsed = intervalElapsed
        self._uiTimer = uiTimer
        self.listSession = listSession
        self.timerManager = timerManager
        self.goalSession = goalSession
        self.limit = limit
    }
    
    // MARK: - Interval Playback Logic
    private func toggleIntervalPlayback(for item: IntervalSession) {
        if activeIntervalID == item.id {
            // Pause current
            stopUITimer()
        } else {
            // Starting or resuming a specific item
            var remainingOffset: TimeInterval = 0
            if activeIntervalID == nil, let start = intervalStartDate, item.id == activeIntervalID {
                let duration = item.durationSeconds
                let elapsed = Date().timeIntervalSince(start)
                remainingOffset = max(duration - elapsed, 0)
            }
            startInterval(item: item, remainingOffset: remainingOffset)
        }
    }

    private func startInterval(item: IntervalSession, remainingOffset: TimeInterval = 0) {
        stopUITimer() // ensure only one timer
        activeIntervalID = item.id
        intervalStartDate = Date()
        intervalElapsed = 0
        
        // Start the main session timer if we have timerManager and goalSession
        if let timerManager, let goalSession, !timerManager.isActive(goalSession) {
            timerManager.startTimer(for: goalSession)
        }
        
        // Use 1 second timer instead of 0.2 for better performance
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            tickCurrentInterval()
        }
        RunLoop.main.add(timer, forMode: .common)
        uiTimer = timer
        
        // Trigger initial tick
        tickCurrentInterval()
        
        // Note: Interval notifications will be implemented in a future update
        // to provide reminders when intervals are about to complete
    }

    private func tickCurrentInterval() {
        guard let activeIntervalID, let start = intervalStartDate else {
            return
        }
        guard let current = (listSession.intervals ?? []).first(where: { $0.id == activeIntervalID }) else {
            return
        }
        let duration = current.durationSeconds
        let newElapsed = Date().timeIntervalSince(start)
        
        // Update timer manager with current interval info (throttled to reduce CPU usage)
        if let timerManager {
            let newProgress = min(newElapsed / max(duration, 0.001), 1.0)
            let newRemaining = max(duration - newElapsed, 0)
            
            // Only update if:
            // 1. First time (name is nil)
            // 2. Time remaining changed by at least 1 second (reduces updates from every second to meaningful changes)
            let shouldUpdate = timerManager.currentIntervalName == nil ||
                               abs((timerManager.intervalTimeRemaining ?? 0) - newRemaining) >= 1.0
            
            if shouldUpdate {
                // Calculate position only when needed (use cached sorted list)
                let sorted = sortedIntervals
                let currentIndex = sorted.firstIndex(where: { $0.id == activeIntervalID }).map { $0 + 1 } ?? 0
                let totalCount = sorted.count
                
                timerManager.currentIntervalName = "\(current.interval?.name ?? "Interval") \(currentIndex)/\(totalCount)"
                timerManager.intervalProgress = newProgress
                timerManager.intervalTimeRemaining = newRemaining
            }
        }
        
        // Update binding directly (we're already on main thread from Timer)
        intervalElapsed = newElapsed
        
        if newElapsed >= duration {
            // mark completed
            current.isCompleted = true
            intervalElapsed = current.durationSeconds
            // advance to next
            advanceToNextInterval(after: current)
        }
    }

    private func advanceToNextInterval(after current: IntervalSession) {
        stopUITimer()
        let sorted = listSession.sortedIntervals
        guard let idx = sorted.firstIndex(where: { $0.id == current.id }) else { return }
        let nextIndex = sorted.index(after: idx)
        if nextIndex < sorted.endIndex {
            let next = sorted[nextIndex]
            startInterval(item: next)
        } else {
            // finished all intervals
            activeIntervalID = nil
            intervalElapsed = 0
            intervalStartDate = nil
        }
    }

    private func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
        
        // Clear interval info from timer manager
        if let timerManager {
            timerManager.currentIntervalName = nil
            timerManager.intervalProgress = nil
            timerManager.intervalTimeRemaining = nil
        }
        // Note: Interval notification cancellation will be added in future update
    }
    
    private func startAllIntervals() {
        // Reset all intervals to not completed
        for interval in listSession.intervals ?? [] {
            interval.isCompleted = false
        }
        
        // Start the first interval
        let sorted = (listSession.intervals ?? []).sorted { ($0.interval?.orderIndex ?? 0) < ($1.interval?.orderIndex ?? 0) }
        if let first = sorted.first {
            startInterval(item: first)
        }
    }

}

// MARK: - Convenience Extensions

private extension IntervalSession {
    var durationSeconds: TimeInterval {
        TimeInterval(interval?.durationSeconds ?? 0)
    }
    
    var orderIndex: Int {
        interval?.orderIndex ?? 0
    }
}

private extension IntervalListSession {
    var intervalCount: Int {
        intervals?.count ?? 0
    }
    
    var themeNeon: Color {
        list?.goal?.primaryTag?.theme.neon ?? .blue
    }
    
    var themeLight: Color {
        list?.goal?.primaryTag?.theme.light ?? .blue
    }
    
    var sortedIntervals: [IntervalSession] {
        (intervals ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
}

