//
//  NowPlayingView.swift
//  Momentum
//
//  Created by Mo Moosa on 20/01/2026.
//

import SwiftUI
import MomentumKit

struct NowPlayingView: View {
    let session: GoalSession
    let activeSessionDetails: ActiveSessionDetails
    let onStopTapped: () -> Void
    let onAdjustStartTime: ((TimeInterval) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAdjustments = false
    
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
                    let currentLap = progress - Double(completedLaps)
                    let ringSize: CGFloat = 280
                    let lineWidth: CGFloat = 14
                    
                    // Background ring
                    Circle()
                        .stroke(
                            foregroundColor.opacity(0.15),
                            lineWidth: lineWidth
                        )
                        .frame(width: ringSize, height: ringSize)
                    
                    // Completed lap rings
                    ForEach(0..<min(completedLaps, 5), id: \.self) { lap in
                        Circle()
                            .stroke(
                                foregroundColor.opacity(0.2 + Double(lap) * 0.05),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                    }
                    
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: progress >= 1.0 ? currentLap : progress)
                        .stroke(
                            foregroundColor.opacity(0.8),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: progress)
                    
               
                    
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
                        dismiss()
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
                        dismiss()
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
