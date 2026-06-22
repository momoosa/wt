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
    let onStopTapped: () -> Void
    let onAdjustStartTime: ((TimeInterval) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAdjustments = false
    @State private var lastWeekProgress: Double?
    
    var foregroundColor: Color {
        session.theme.foregroundColor(for: colorScheme)
    }
    // Optional interval information
    let currentIntervalName: String?
    let intervalProgress: Double?
    let intervalTimeRemaining: TimeInterval?
    
    init(session: GoalSession, activeSessionDetails: ActiveSessionDetails, currentIntervalName: String? = nil, intervalProgress: Double? = nil, intervalTimeRemaining: TimeInterval? = nil, onStopTapped: @escaping () -> Void, onAdjustStartTime: ((TimeInterval) -> Void)? = nil) {
        self.session = session
        self.activeSessionDetails = activeSessionDetails
        self.currentIntervalName = currentIntervalName
        self.intervalProgress = intervalProgress
        self.intervalTimeRemaining = intervalTimeRemaining
        self.onStopTapped = onStopTapped
        self.onAdjustStartTime = onAdjustStartTime
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
        let elapsed = activeSessionDetails.elapsedTime + Date().timeIntervalSince(activeSessionDetails.startDate)
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
    
    var body: some View {
        ZStack {
            // Background gradient
            session.theme.gradient(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar: dismiss button + category label
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
                    
                    // Invisible spacer to balance the layout
                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Goal title + target
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
                
                Spacer()
                    .frame(height: 32)
                
                // Progress ring + timer
                ZStack {
                    let progress = activeSessionDetails.progress
                    let completedLaps = Int(progress)
                    let ringSize: CGFloat = 280
                    let lineWidth: CGFloat = 14
                    
                    // Background ring
                    Circle()
                        .stroke(
                            foregroundColor.opacity(0.15),
                            lineWidth: lineWidth
                        )
                        .frame(width: ringSize, height: ringSize)
                    
                    if progress < 1.0 {
                        // Under 100%: simple arc
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                foregroundColor.opacity(0.8),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6), value: progress)
                    } else {
                        // Over 100%: Apple Watch-style overlapping ring
                        let overflowFraction = progress.truncatingRemainder(dividingBy: 1.0)
                        let displayFraction = overflowFraction == 0 ? 1.0 : overflowFraction
                        
                        // Full completed ring at full opacity
                        Circle()
                            .stroke(
                                foregroundColor.opacity(0.8),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                        
                        // Overflow arc with shadow at the leading edge
                        Circle()
                            .trim(from: 0, to: displayFraction)
                            .stroke(
                                foregroundColor.opacity(0.8),
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
                            .fill(foregroundColor.opacity(0.5))
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
                
                // Current interval display (if active)
                if let currentIntervalName, let intervalTimeRemaining, let intervalProgress {
                    VStack(spacing: 10) {
                        Text(currentIntervalName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(foregroundColor)
                        
                        Text(intervalTimeRemaining.formatted(style: .hmmss))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(foregroundColor.opacity(0.9))
                            .contentTransition(.numericText())
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(foregroundColor.opacity(0.15))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(foregroundColor.opacity(0.6))
                                    .frame(width: geometry.size.width * intervalProgress, height: 4)
                                    .animation(.linear(duration: 0.5), value: intervalProgress)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(foregroundColor.opacity(0.08))
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
                }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 40) {
                    // Stop button
                    Button {
                        HapticFeedbackManager.trigger(.medium)
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
                    
                    // Pause/Resume button (large center)
                    Button {
                        HapticFeedbackManager.trigger(.medium)
                        onStopTapped()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(session.theme.gradient(for: colorScheme))
                            .frame(width: 72, height: 72)
                            .background(
                                Circle()
                                    .fill(foregroundColor)
                                    .shadow(color: foregroundColor.opacity(0.3), radius: 12, x: 0, y: 4)
                            )
                    }
                    
                    // Adjustments button
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
                
                // Checklist card
                if let checklistItems = session.checklist, !checklistItems.isEmpty {
                    nowPlayingChecklist(items: checklistItems)
                }
                
                Spacer()
                    .frame(height: 32)
               
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
        .preferredColorScheme(.dark)
        .task {
            lastWeekProgress = computeLastWeekProgress()
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
}

// MARK: - Now Playing Checklist

extension NowPlayingView {
    func nowPlayingChecklist(items: [ChecklistItemSession]) -> some View {
        ScrollView {
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
        }
        .frame(maxHeight: 160)
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
    
    NowPlayingView(
        session: session,
        activeSessionDetails: details,
        currentIntervalName: "Heel Stretch 2/4",
        intervalProgress: 0.6,
        intervalTimeRemaining: 12
    ) {
        print("Stop tapped")
    }
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
    
    NowPlayingView(
        session: session,
        activeSessionDetails: details
    ) {
        print("Stop tapped")
    }
}
