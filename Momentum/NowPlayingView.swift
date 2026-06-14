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
    
    var body: some View {
        ZStack {
            // Background gradient
            
            session.theme.gradient(for: colorScheme)
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        // Swipe down to dismiss
                        if value.translation.height > 100 {
                            dismiss()
                        }
                    }
            )
            
            VStack(spacing: 40) {
                // Dismiss indicator at top
                VStack(spacing: 16) {
                    // Grab handle
                    Spacer()
                        .frame(height: 30)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(foregroundColor.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    // Down chevron button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(foregroundColor)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(foregroundColor.opacity(0.2))
                            )
                    }
                }
                
                Spacer()
                
                // Goal title
                VStack(spacing: 8) {
                    Text(session.goal?.title ?? "Goal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(foregroundColor)
                    
                    Text(session.goal?.primaryTag?.title ?? "")
                        .font(.title3)
                        .foregroundStyle(foregroundColor.opacity(0.8))
                }
                
                // Circular progress indicator
                ZStack {
                    let progress = activeSessionDetails.progress
                    let completedLaps = Int(progress)
                    let currentLap = progress - Double(completedLaps)
                    let lineWidth = LayoutConstants.ProgressCircle.largeLineWidth
                    let diameter = LayoutConstants.ProgressCircle.largeDiameter
                    
                    // Background circle
                    Circle()
                        .stroke(
                            foregroundColor.opacity(0.3),
                            lineWidth: lineWidth
                        )
                        .frame(width: diameter, height: diameter)
                    
                    // Completed lap rings — stacked with decreasing opacity
                    ForEach(0..<min(completedLaps, 5), id: \.self) { lap in
                        Circle()
                            .stroke(
                                foregroundColor.opacity(0.15 + Double(lap) * 0.05),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .frame(width: diameter, height: diameter)
                            .shadow(color: foregroundColor.opacity(0.3), radius: 4)
                    }
                    
                    // Current lap arc
                    Circle()
                        .trim(from: 0, to: progress >= 1.0 ? currentLap : progress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .white,
                                    session.theme.color(for: .dark),
                                    .white
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: diameter, height: diameter)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: foregroundColor.opacity(completedLaps > 0 ? 0.6 : 0), radius: 6)
                        .animation(.spring(response: 0.6), value: progress)
                    
                    // Time display in center
                    VStack(spacing: 12) {
                        if let timeText = activeSessionDetails.timeText {
                            Text(timeText)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(foregroundColor)
                                .contentTransition(.numericText())
                        }
                        
                        // Progress percentage
                        Text("\(Int(progress * 100))%")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(foregroundColor.opacity(0.8))
                        
                        // Daily target info
                        Text("of \(activeSessionDetails.dailyTarget.formatted(style: .hourMinute))")
                            .font(.title2)
                            .foregroundStyle(foregroundColor.opacity(0.6))
                        
                        // Lap indicator
                        if completedLaps > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                    .font(.caption)
                                Text("\(completedLaps)×")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(foregroundColor.opacity(0.6))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .padding(.vertical, 40)
                
                // Current interval display (if active)
                if let currentIntervalName, let intervalTimeRemaining, let intervalProgress {
                    VStack(spacing: 12) {
                        // Interval name
                        Text(currentIntervalName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        // Interval time remaining
                        Text(intervalTimeRemaining.formatted(style: .components))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .contentTransition(.numericText())
                        
                        // Interval progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.2))
                                    .frame(height: 8)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white)
                                    .frame(width: geometry.size.width * intervalProgress, height: 8)
                                    .animation(.linear(duration: 0.5), value: intervalProgress)
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 40)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.15))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 40)
                }
                
                // Control buttons
                HStack(spacing: 60) {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(foregroundColor)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(foregroundColor.opacity(0.2))
                            )
                    }
                    
                    // Stop/Pause button (large)
                    Button {
                        HapticFeedbackManager.trigger(.medium)
                        onStopTapped()
                        dismiss()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(session.theme.color(for: colorScheme))
                            .frame(width: LayoutConstants.ProgressCircle.standardDiameter, height: LayoutConstants.ProgressCircle.standardDiameter)
                            .background(
                                Circle()
                                    .fill(foregroundColor)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            )
                    }
                    
                    // Adjustments button
                    Button {
                        showingAdjustments = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(foregroundColor)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(foregroundColor.opacity(0.2))
                            )
                    }
                }
                .padding(.bottom, 60)
                
                Spacer()
            }
        }
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
