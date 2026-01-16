//
//  IntervalListView.swift
//  Weektime
//
//  Created by Mo Moosa on 28/11/2025.
//

import SwiftUI
import WeektimeKit

struct IntervalListView: View {
    @Binding var activeIntervalID: String?
    @Binding private var intervalStartDate: Date?
    @Binding private var intervalElapsed: TimeInterval
    @Binding private var uiTimer: Timer?
    let limit: Int?

    let listSession: IntervalListSession
    
    var body: some View {
        let intervals: [IntervalSession]
        
        if let limit {
            intervals = Array(listSession.intervals.prefix(limit))
        }  else {
            intervals = listSession.intervals
        }
        return LazyVStack {
        Section {
     
                
                ForEach(intervals.sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex })) { item in
                    let filteredSorted = listSession.intervals
                    // TODO:
                    //                    .filter { $0.interval.kind == item.interval.kind && $0.interval.name == item.interval.name }
                        .sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex })
                    let totalCount = filteredSorted.count
                    let currentIndex = (filteredSorted.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
                    
                    let duration = TimeInterval(item.interval.durationSeconds)
                    let isActive = activeIntervalID == item.id
                    let elapsed = isActive ? intervalElapsed : 0
                    let progress = min(max(elapsed / max(duration, 0.001), 0), 1)
                    ZStack(alignment: .leading) {
                        // Background progress bar filling full row height
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                let isCompleted = item.isCompleted
                                let displayElapsed: TimeInterval = {
                                    if isCompleted { return TimeInterval(item.interval.durationSeconds) }
                                    return isActive ? min(elapsed, duration) : 0
                                }()
                                let total = TimeInterval(item.interval.durationSeconds)
                                
                                Text("\(item.interval.name) \(currentIndex)/\(totalCount)")
                                    .fontWeight(.semibold)
                                    .strikethrough(isCompleted, pattern: .solid, color: .primary)
                                    .opacity(isCompleted ? 0.6 : 1)
                                
                                if isCompleted {
                                    Text("\(Duration.seconds(displayElapsed).formatted(.time(pattern: .minuteSecond)))/\(Duration.seconds(total).formatted(.time(pattern: .minuteSecond)))")
                                        .font(.caption)
                                        .opacity(0.7)
                                } else {
                                    let remaining = max(total - displayElapsed, 0)
                                    Text("\(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond))) remaining")
                                        .font(.caption)
                                        .opacity(0.7)
                                }
                            }
                            Spacer()
                            Button {
                                toggleIntervalPlayback(for: item)
                            } label: {
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
                                    let width = geo.size.width * progress
                                    Rectangle()
                                        .fill(listSession.list.goal?.primaryTheme.theme.light.opacity(0.25) ?? .blue.opacity(0.25))
                                        .frame(width: width)
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
        } footer: {
            if let limit, self.listSession.list.intervals.count - limit > 0 {
                let count = self.listSession.list.intervals.count - limit
                Text("And \(count) more")
            }
        }
            }
    }
    
    public init(listSession: IntervalListSession, activeIntervalID: Binding<String?>, intervalStartDate: Binding<Date?>, intervalElapsed: Binding<TimeInterval>, uiTimer: Binding<Timer?>, limit: Int? = nil) {
        self._activeIntervalID = activeIntervalID
        self._intervalStartDate = intervalStartDate
        self._intervalElapsed = intervalElapsed
        self._uiTimer = uiTimer
        self.listSession = listSession
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
                let duration = TimeInterval(item.interval.durationSeconds)
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
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            tickCurrentInterval()
        }
        RunLoop.current.add(uiTimer!, forMode: .common)
        // TODO:
//        cancelAllIntervalNotifications(for: session)
//        scheduleNotifications(from: item, in: session, startingIn: remainingOffset)
    }

    private func tickCurrentInterval() {
        guard let activeIntervalID, let start = intervalStartDate else {
            return
        }
        guard let current = listSession.intervals.first(where: { $0.id == activeIntervalID }) else {
            return
        }
        let duration = TimeInterval(current.interval.durationSeconds)
        intervalElapsed = Date().timeIntervalSince(start)
        if intervalElapsed >= duration {
            // mark completed
            current.isCompleted = true
            intervalElapsed = TimeInterval(current.interval.durationSeconds)
            // advance to next
            advanceToNextInterval(after: current)
        }
    }

    private func advanceToNextInterval(after current: IntervalSession) {
        stopUITimer()
        let sorted = listSession.intervals.sorted { $0.interval.orderIndex < $1.interval.orderIndex }
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
//  TODO:       cancelAllIntervalNotifications(for: listSession)
    }
    

}
