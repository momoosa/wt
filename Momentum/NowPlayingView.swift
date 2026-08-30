//
//  NowPlayingView.swift
//  Momentum
//
//  Created by Mo Moosa on 20/01/2026.
//

import SwiftUI
import SwiftData
import MomentumKit

struct NowPlayingView: View {
    let session: GoalSession
    let activeSessionDetails: ActiveSessionDetails
    let intervalTimer: IntervalTimerManager
    let onStopTapped: () -> Void
    var onPauseTapped: (() -> Void)? = nil
    var onAdjustStartTime: ((TimeInterval) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAdjustments = false
    @State private var lastWeekProgress: Double?
    @State private var selectedPage = 0
    @State private var intervalsLoaded = false
    
    
    var foregroundColor: Color {
        session.theme.foregroundColor(for: colorScheme)
    }
    
    /// Theme accent color for the progress ring (vibrant hue instead of plain white)
    private var ringColor: Color {
        session.theme.color(for: colorScheme)
    }
    
    /// Active interval name from the shared timer
    private var currentIntervalName: String? {
        if intervalTimer.isActive || intervalTimer.phase == .completed {
            return intervalTimer.currentIntervalName
        }
        return nil
    }
    
    /// Active interval progress from the shared timer
    private var intervalProgress: Double? {
        if intervalTimer.isActive {
            return intervalTimer.currentIntervalProgress
        }
        return nil
    }
    
    private var isTimeBased: Bool {
        activeSessionDetails.targetUnit.isTimeBased
    }
    
    private var targetLabel: String {
        if isTimeBased {
            let target = activeSessionDetails.dailyTarget
            if target > 0 {
                return "TARGET \(target.formatted(style: .hourMinute))".uppercased()
            }
            return ""
        } else {
            let target = Int(activeSessionDetails.unifiedTargetValue)
            guard target > 0 else { return "" }
            let unitLabel = activeSessionDetails.targetUnit == .steps ? "STEPS" : "KCAL"
            return "TARGET \(target.formatted()) \(unitLabel)"
        }
    }
    
    private var elapsedFormatted: String {
        let liveComponent = activeSessionDetails.isPaused ? 0 : Date().timeIntervalSince(activeSessionDetails.startDate)
        let elapsed = activeSessionDetails.elapsedTime + liveComponent
        let totalSeconds = Int(max(elapsed, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var metricFormatted: String {
        let current = Int(activeSessionDetails.metricValue)
        let target = Int(activeSessionDetails.unifiedTargetValue)
        let unitLabel = activeSessionDetails.targetUnit == .steps ? "steps" : "kcal"
        if target > 0 {
            return "\(current.formatted())/\(target.formatted()) \(unitLabel)"
        }
        return "\(current.formatted()) \(unitLabel)"
    }
    
    private var hasChecklist: Bool {
        guard let items = session.checklist else { return false }
        return !items.isEmpty
    }
    
    /// Whether there's scrollable content below the header (intervals or checklist)
    private var hasScrollableContent: Bool {
        hasIntervals || hasChecklist
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            session.theme.gradient(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // FIXED: Top bar
                topBarView
                
                if hasScrollableContent {
                    // Segmented control (if both intervals and checklist exist)
                    if hasIntervals && hasChecklist {
                        segmentedControl
                            .padding(.top, 8)
                    }
                    
                    // Sticky header + scrollable content
                    nowPlayingScrollablePage
                } else {
                    // No intervals or checklist — original static layout
                    nowPlayingStaticPage
                }
            }
        }
        .task {
            lastWeekProgress = computeLastWeekProgress()
            loadIntervalsIfNeeded()
        }
        .sheet(isPresented: $showingAdjustments) {
            SessionAdjustmentsSheet(
                activeSessionDetails: activeSessionDetails,
                onAdjustStartTime: onAdjustStartTime
            )
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
        }
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        let checklistItems = session.checklist ?? []
        let completed = checklistItems.filter(\.isCompleted).count
        let total = checklistItems.count
        
        return HStack(spacing: 0) {
            segmentButton(title: "Intervals", icon: "list.bullet", page: 0)
            segmentButton(title: "\(completed)/\(total)", icon: "checklist", page: 1)
        }
        .background(foregroundColor.opacity(0.1), in: Capsule())
        .padding(.horizontal, 40)
    }
    
    private func segmentButton(title: String, icon: String, page: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPage = page
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedPage == page ? AnyShapeStyle(session.theme.gradient(for: colorScheme)) : AnyShapeStyle(foregroundColor.opacity(0.5)))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(selectedPage == page ? foregroundColor : .clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Now Playing Content
    
    /// Sorted work intervals from the goal's first interval list
    private var goalIntervals: [Interval] {
        guard let lists = session.goal?.intervalLists, let first = lists.sorted(by: { $0.orderIndex < $1.orderIndex }).first,
              let intervals = first.intervals else { return [] }
        return intervals.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private var hasIntervals: Bool {
        !goalIntervals.isEmpty || currentIntervalName != nil
    }
    
    /// Whether the local interval timer is actively driving playback
    private var isLocalIntervalActive: Bool {
        intervalTimer.isActive || intervalTimer.phase == .completed
    }
    
    /// Elapsed seconds for the current interval (counts up)
    private var currentIntervalElapsed: Int {
        let duration = intervalTimer.currentIntervalSession?.interval?.durationSeconds ?? 0
        return duration - intervalTimer.secondsRemaining
    }
    
    /// The first IntervalListSession from the goal session
    private var firstIntervalListSession: IntervalListSession? {
        session.intervalLists?.sorted(by: { $0.orderIndex < $1.orderIndex }).first
    }
    
    private func loadIntervalsIfNeeded() {
        guard !intervalsLoaded, let listSession = firstIntervalListSession else { return }
        intervalsLoaded = true
        intervalTimer.load(from: listSession)
    }
    
    
    // MARK: - Static Page (no scrollable content)
    
    private var nowPlayingStaticPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 6) {
                Text(session.goal?.title ?? "Goal")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
                
                Text(targetLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1.5)
                    .foregroundStyle(foregroundColor.opacity(0.6))
            }
            
            Spacer().frame(height: 32)
            
            progressRingView
            
            Spacer()
            
            controlButtonsView
            
            Spacer()
        }
    }
    
    // MARK: - Scrollable Page (intervals and/or checklist)
    
    private var nowPlayingScrollablePage: some View {
        VStack(spacing: 0) {
            // Compact header — always shown when there's a list
            compactHeader
            
            // Scrollable list content
            ScrollView {
                VStack(spacing: 0) {
                    if hasIntervals && hasChecklist {
                        if selectedPage == 0 {
                            intervalListContent
                        } else {
                            checklistContent
                        }
                    } else if hasIntervals {
                        intervalListContent
                    } else if hasChecklist {
                        checklistContent
                    }
                }
            }
        }
    }
    
    // MARK: - Compact Header (horizontal layout)
    
    private var compactHeader: some View {
        HStack(spacing: 14) {
            // Small progress ring on the left (no inner text — too small to read)
            compactProgressRing
            
            // Title, subtitle, and controls to the right
            VStack(alignment: .leading, spacing: 6) {
                // Title row
                Text(session.goal?.title ?? "Goal")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                
                // Subtitle: interval info or elapsed time
                if intervalTimer.isActive, let name = intervalTimer.currentIntervalName {
                    HStack(spacing: 4) {
                        Text(name)
                        if intervalTimer.phase != .transition {
                            Text("·")
                            Text(formatCountdown(currentIntervalElapsed))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(foregroundColor.opacity(0.7))
                    .lineLimit(1)
                } else if let currentIntervalName {
                    Text(currentIntervalName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(foregroundColor.opacity(0.7))
                        .lineLimit(1)
                } else if isTimeBased {
                    Text(elapsedFormatted)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(foregroundColor.opacity(0.7))
                }
                
                // Controls row — below the title
                HStack(spacing: 12) {
                    Button {
                        HapticFeedbackManager.trigger(.medium)
                        intervalTimer.stop()
                        onStopTapped()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(foregroundColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(foregroundColor.opacity(0.15)))
                    }
                    
                    Button {
                        HapticFeedbackManager.trigger(.medium)
                        onPauseTapped?()
                    } label: {
                        Image(systemName: activeSessionDetails.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(session.theme.gradient(for: colorScheme))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(foregroundColor)
                            )
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    /// A compact version of the progress ring without inner text
    private var compactProgressRing: some View {
        let progress = activeSessionDetails.progress
        let completedLaps = Int(progress)
        let ringSize: CGFloat = 80
        let lineWidth: CGFloat = 8
        
        return ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)
            
            if progress < 1.0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)
            } else {
                let overflowFraction = progress.truncatingRemainder(dividingBy: 1.0)
                let displayFraction = overflowFraction == 0 ? 1.0 : overflowFraction
                
                Circle()
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: ringSize, height: ringSize)
                
                Circle()
                    .trim(from: 0, to: displayFraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 0)
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .clipShape(Circle().stroke(lineWidth: lineWidth + 8))
                    .animation(.spring(response: 0.6), value: progress)
            }
            
            // Compact center content: just percentage
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
                
                if completedLaps > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 7))
                        Text("\(completedLaps)×")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(foregroundColor.opacity(0.6))
                }
            }
        }
    }
    
    private func intervalBadge(name: String) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foregroundColor)
            
            if let intervalProgress {
                Text("\(Int(intervalProgress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(foregroundColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(foregroundColor.opacity(0.1), in: Capsule())
    }
    
    // MARK: - Interval List Content
    
    private var intervalListContent: some View {
        VStack(spacing: 0) {
            // Playback controls
            if intervalsLoaded && !intervalTimer.intervalSessions.isEmpty {
                intervalPlaybackControls
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            
            // Interval rows
            if isLocalIntervalActive, !intervalTimer.intervalSessions.isEmpty {
                // Playback-aware rows from the interval timer
                playbackIntervalList
                    .transition(.opacity)
            } else {
                // Static rows from goal intervals
                staticIntervalList
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    private var staticIntervalList: some View {
        VStack(spacing: 0) {
            ForEach(Array(goalIntervals.enumerated()), id: \.element.id) { index, interval in
                nowPlayingIntervalRow(interval, index: index)
                
                if index < goalIntervals.count - 1 {
                    Divider()
                        .foregroundStyle(foregroundColor.opacity(0.1))
                        .padding(.leading, 56)
                }
            }
        }
        .padding(.vertical, 4)
        .background(foregroundColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var playbackIntervalList: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ForEach(Array(intervalTimer.intervalSessions.enumerated()), id: \.element.id) { index, intervalSession in
                    playbackIntervalRow(intervalSession, index: index)
                        .id(intervalSession.id)
                    
                    if index < intervalTimer.intervalSessions.count - 1 {
                        Divider()
                            .foregroundStyle(foregroundColor.opacity(0.1))
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(foregroundColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .animation(.easeInOut(duration: 0.3), value: intervalTimer.currentIntervalIndex)
            .onChange(of: intervalTimer.currentIntervalIndex) { _, newIndex in
                if newIndex < intervalTimer.intervalSessions.count {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(intervalTimer.intervalSessions[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Interval Playback Controls
    
    private var intervalPlaybackControls: some View {
        HStack(spacing: 0) {
            // Interval counter / status
            VStack(alignment: .leading, spacing: 2) {
                if intervalTimer.isActive {
                    Text(intervalTimer.currentIntervalName ?? "Interval")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("\(intervalTimer.currentIntervalIndex + 1) of \(intervalTimer.totalIntervals)")
                            .font(.caption2.weight(.medium))
                        
                        if intervalTimer.phase == .transition {
                            Text("· Next in \(intervalTimer.transitionSecondsRemaining)s")
                                .font(.caption2.weight(.medium))
                        } else if intervalTimer.phase != .idle {
                            Text("· \(formatCountdown(currentIntervalElapsed))")
                                .font(.caption2.weight(.medium).monospacedDigit())
                        }
                    }
                    .foregroundStyle(foregroundColor.opacity(0.5))
                } else if intervalTimer.phase == .completed {
                    Text("All intervals complete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(foregroundColor)
                } else {
                    Text("\(goalIntervals.count) intervals")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(foregroundColor.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 16) {
                if intervalTimer.isActive {
                    // Previous
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            intervalTimer.skipToPrevious()
                        }
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(foregroundColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(foregroundColor.opacity(0.12)))
                    }
                    
                    // Play/Pause
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            intervalTimer.togglePause()
                        }
                    } label: {
                        Image(systemName: intervalTimer.phase == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(session.theme.gradient(for: colorScheme))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle().fill(foregroundColor)
                            )
                    }
                    
                    // Next
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            intervalTimer.skipToNext()
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(foregroundColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(foregroundColor.opacity(0.12)))
                    }
                } else if intervalTimer.phase == .completed {
                    // Restart button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if let listSession = firstIntervalListSession {
                                intervalTimer.load(from: listSession)
                                intervalTimer.start()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption.weight(.semibold))
                            Text("Repeat")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(foregroundColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(foregroundColor.opacity(0.15)))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.3), value: intervalTimer.phase)
    }
    
    private func playbackIntervalRow(_ intervalSession: IntervalSession, index: Int) -> some View {
        let isCurrent = index == intervalTimer.currentIntervalIndex && intervalTimer.isActive
        let isPaused = isCurrent && intervalTimer.phase == .paused
        let isCompleted = intervalSession.isCompleted
        let interval = intervalSession.interval
        
        // Progress fraction for the background bar
        let progress: Double = {
            if isCompleted { return 1.0 }
            if isCurrent { return intervalTimer.currentIntervalProgress }
            return 0
        }()
        
        return HStack(spacing: 12) {
            // Numbered circle / checkmark
            ZStack {
                Circle()
                    .fill(isCurrent ? foregroundColor : foregroundColor.opacity(isCompleted ? 0.1 : 0.08))
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(foregroundColor.opacity(0.5))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isCurrent
                                ? AnyShapeStyle(session.theme.gradient(for: colorScheme))
                                : AnyShapeStyle(foregroundColor.opacity(0.6))
                        )
                }
            }
            
            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(interval?.name ?? "Interval \(index + 1)")
                    .font(.subheadline.weight(isCurrent ? .semibold : .medium))
                    .foregroundStyle(
                        isCurrent ? foregroundColor : foregroundColor.opacity(isCompleted ? 0.4 : 0.8)
                    )
                    .lineLimit(1)
                
                if isCurrent, let kind = interval?.kind {
                    Text(kind == .work ? "In progress" : "Rest")
                        .font(.caption2)
                        .foregroundStyle(foregroundColor.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Elapsed time or duration
            if isCurrent {
                Text(formatCountdown(currentIntervalElapsed))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(foregroundColor)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: currentIntervalElapsed)
            } else if let duration = interval?.durationSeconds {
                Text(formatIntervalDuration(duration))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(foregroundColor.opacity(isCompleted ? 0.3 : 0.5))
            }
            
            // Per-row play/pause button
            if !isCompleted {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if isCurrent {
                            intervalTimer.togglePause()
                        } else {
                            intervalTimer.skipTo(index: index)
                        }
                    }
                } label: {
                    Image(systemName: (isCurrent && !isPaused) ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(foregroundColor.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(foregroundColor.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            GeometryReader { geo in
                foregroundColor.opacity(0.12)
                    .frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 1), value: progress)
            }
        )
    }
    
    private func nowPlayingIntervalRow(_ interval: Interval, index: Int) -> some View {
        let isCurrent = currentIntervalName?.contains(interval.name) == true
        
        return HStack(spacing: 12) {
            // Numbered circle
            ZStack {
                Circle()
                    .fill(isCurrent ? foregroundColor : foregroundColor.opacity(0.08))
                    .frame(width: 32, height: 32)
                
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isCurrent
                            ? AnyShapeStyle(session.theme.gradient(for: colorScheme))
                            : AnyShapeStyle(foregroundColor.opacity(0.6))
                    )
            }
            
            // Name
            Text(interval.name.isEmpty ? "Interval \(index + 1)" : interval.name)
                .font(.subheadline.weight(isCurrent ? .semibold : .medium))
                .foregroundStyle(foregroundColor.opacity(isCurrent ? 1 : 0.8))
                .lineLimit(1)
            
            Spacer()
            
            // Duration
            Text(formatIntervalDuration(interval.durationSeconds))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(foregroundColor.opacity(isCurrent ? 0.8 : 0.5))
            
            // Play button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    intervalTimer.skipTo(index: index)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(foregroundColor.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(foregroundColor.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isCurrent ? foregroundColor.opacity(0.12) : Color.clear
        )
    }
    
    private func formatIntervalDuration(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        if min > 0 && sec > 0 {
            return "\(min)m \(sec)s"
        } else if min > 0 {
            return "\(min)m"
        } else {
            return "\(sec)s"
        }
    }
    
    private func formatCountdown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return String(format: "0:%02d", secs)
    }
    
    // MARK: - Checklist Content
    
    private var checklistContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let items = session.checklist, !items.isEmpty {
                let completed = items.filter(\.isCompleted).count
                let total = items.count
                
                HStack {
                    Text("Checklist")
                        .font(.headline)
                        .foregroundStyle(foregroundColor)
                    
                    Spacer()
                    
                    Text("\(completed)/\(total)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(foregroundColor.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                nowPlayingChecklist(items: items)
                    .padding(.bottom, 40)
            }
        }
    }
    // MARK: - Top Bar
    
    private var topBarView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "minus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(foregroundColor.opacity(0.15))
                    )
            }
            
            Spacer()
            
            Text(session.goal?.primaryTag?.title.uppercased() ?? "")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(foregroundColor.opacity(0.7))
            
            Spacer()
            
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
    }
    
    // MARK: - Progress Ring
    
    private var progressRingView: some View {
        ZStack {
            let progress = activeSessionDetails.progress
            let completedLaps = Int(progress)
            let ringSize: CGFloat = 280
            let lineWidth: CGFloat = 14
            
            // Background ring
            Circle()
                .stroke(
                    ringColor.opacity(0.2),
                    lineWidth: lineWidth
                )
                .frame(width: ringSize, height: ringSize)
            
            if progress < 1.0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)
            } else {
                let overflowFraction = progress.truncatingRemainder(dividingBy: 1.0)
                let displayFraction = overflowFraction == 0 ? 1.0 : overflowFraction
                
                Circle()
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                
                Circle()
                    .trim(from: 0, to: displayFraction)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 0)
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .clipShape(Circle().stroke(lineWidth: lineWidth + 12))
                    .animation(.spring(response: 0.6), value: progress)
            }
            
            // Last week's progress triangle marker
            if let lwProgress = lastWeekProgress, lwProgress > 0 {
                let clampedProgress = min(lwProgress, 1.0)
                let angle = Angle.degrees(clampedProgress * 360 - 90)
                let radius = (ringSize / 2) + lineWidth / 2 + 8
                
                Triangle()
                    .fill(ringColor.opacity(0.5))
                    .frame(width: 10, height: 8)
                    .rotationEffect(.degrees(90) + angle)
                    .offset(
                        x: radius * cos(angle.radians),
                        y: radius * sin(angle.radians)
                    )
                    .transition(.opacity)
            }
            
            // Center content: time or metric + percentage + edit
            VStack(spacing: 8) {
                if isTimeBased {
                    if let timeText = activeSessionDetails.timeText {
                        Text(timeText)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(foregroundColor)
                            .contentTransition(.numericText())
                    } else {
                        Text(elapsedFormatted)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(foregroundColor)
                    }
                } else {
                    Text(metricFormatted)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(foregroundColor)
                        .contentTransition(.numericText())
                }
                
                HStack(spacing: 6) {
                    Text("\(Int(progress * 100))% COMPLETE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundStyle(foregroundColor.opacity(0.6))
                    
                    if completedLaps > 0 {
                        Text("·")
                            .foregroundStyle(foregroundColor.opacity(0.4))
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.caption2)
                            Text("\(completedLaps)×")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(foregroundColor.opacity(0.6))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                if isTimeBased {
                    Button {
                        showingAdjustments = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption2.weight(.semibold))
                            Text("Edit Time")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(foregroundColor.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(foregroundColor.opacity(0.1))
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtonsView: some View {
        HStack(spacing: 40) {
            Button {
                HapticFeedbackManager.trigger(.medium)
                intervalTimer.stop()
                onStopTapped()
            } label: {
                Image(systemName: "square.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(foregroundColor.opacity(0.15))
                    )
            }
            
            Button {
                HapticFeedbackManager.trigger(.medium)
                onPauseTapped?()
            } label: {
                Image(systemName: activeSessionDetails.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(session.theme.gradient(for: colorScheme))
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(foregroundColor)
                            .shadow(color: foregroundColor.opacity(0.3), radius: 12, x: 0, y: 4)
                    )
            }
            
            Button {
                showingAdjustments = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(foregroundColor.opacity(0.15))
                    )
            }
        }
    }
}

// MARK: - Now Playing Checklist

extension NowPlayingView {
    func nowPlayingChecklist(items: [ChecklistItemSession]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items, id: \.id) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        item.isCompleted.toggle()
                    }
                    HapticFeedbackManager.trigger(.light)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .contentTransition(.symbolEffect(.replace))
                            .foregroundStyle(item.isCompleted ? foregroundColor : foregroundColor.opacity(0.4))
                            .font(.body)
                        
                        Text(item.checklistItem?.title ?? "")
                            .font(.subheadline)
                            .foregroundStyle(foregroundColor.opacity(item.isCompleted ? 0.4 : 0.9))
                            .strikethrough(item.isCompleted, color: foregroundColor.opacity(0.3))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                
                if item.id != items.last?.id {
                    Divider()
                        .background(foregroundColor.opacity(0.1))
                        .padding(.leading, 42)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(foregroundColor.opacity(0.08))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Last Week Progress

extension NowPlayingView {
    /// Computes last week's progress for this goal at the same time of day
    func computeLastWeekProgress() -> Double? {
        guard let goal = session.goal else { return nil }
        let target = activeSessionDetails.unifiedTargetValue
        guard target > 0 else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        guard let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return nil }
        let dayID = lastWeekDate.yearMonthDayID(with: calendar)
        let goalIDString = goal.id.uuidString
        
        do {
            let days = try modelContext.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.id == dayID }))
            guard let day = days.first, let historicalSessions = day.historicalSessions else { return nil }
            
            // Sum up all time spent on this goal last week same day
            let totalSeconds = historicalSessions
                .filter { $0.goalIDs.contains(goalIDString) }
                .reduce(0.0) { $0 + $1.duration }
            
            guard totalSeconds > 0 else { return nil }
            return totalSeconds / target
        } catch {
            return nil
        }
    }
}

struct SessionAdjustmentsSheet: View {
    let activeSessionDetails: ActiveSessionDetails
    let onAdjustStartTime: ((TimeInterval) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var startTime: Date
    
    init(activeSessionDetails: ActiveSessionDetails, onAdjustStartTime: ((TimeInterval) -> Void)?) {
        self.activeSessionDetails = activeSessionDetails
        self.onAdjustStartTime = onAdjustStartTime
        _startTime = State(initialValue: activeSessionDetails.startDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Adjust Start Time")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            // Date picker
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Started at", selection: $startTime, in: ...Date(), displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                    .onChange(of: startTime) { oldValue, newValue in
                        let adjustment = newValue.timeIntervalSince(oldValue)
                        onAdjustStartTime?(adjustment)
                        HapticFeedbackManager.trigger(.light)
                    }
                
                Text("Original: \(activeSessionDetails.startDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview("In Progress") {
    let theme = GoalTag(title: "Wellness", themeID: "bee")
    let goal = Goal(title: "Meditation", primaryTag: theme)
    let day = Day(start: Date(), end: Date())
    let session = GoalSession(title: "Meditation", goal: goal, day: day)
    // startDate 10 min ago, 0 prior elapsed, 20 min target → ~50% progress
    let details: ActiveSessionDetails = {
        let d = ActiveSessionDetails(id: session.id, startDate: Date().addingTimeInterval(-600), elapsedTime: 0, dailyTarget: 1200)
        d.unifiedTargetValue = 1200
        return d
    }()
    
    let previewTimer = IntervalTimerManager()
    NowPlayingView(
        session: session,
        activeSessionDetails: details,
        intervalTimer: previewTimer,
        onStopTapped: {
            print("Stop tapped")
        }
    )
}

#Preview("Over 100%") {
    let theme = GoalTag(title: "Fitness", themeID: "coral")
    let goal = Goal(title: "Running", primaryTag: theme)
    let day = Day(start: Date(), end: Date())
    let session = GoalSession(title: "Running", goal: goal, day: day)
    // startDate 5 min ago, 25 min prior elapsed, 10 min target → ~300% (3 laps)
    let details: ActiveSessionDetails = {
        let d = ActiveSessionDetails(id: session.id, startDate: Date().addingTimeInterval(-300), elapsedTime: 2500, dailyTarget: 600)
        d.unifiedTargetValue = 600
        return d
    }()
    
    let previewTimer = IntervalTimerManager()
    NowPlayingView(
        session: session,
        activeSessionDetails: details,
        intervalTimer: previewTimer,
        onStopTapped: {
            print("Stop tapped")
        }
    )
}
