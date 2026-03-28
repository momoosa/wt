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
    
    @State private var showingAdjustments = false
    
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
            LinearGradient(
                gradient: Gradient(colors: [
                    session.themeLight,
                    session.themeDark
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                        .fill(.white.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    // Down chevron button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
                            )
                    }
                }
                
                Spacer()
                
                // Goal title
                VStack(spacing: 8) {
                    Text(session.goal?.title ?? "Goal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(session.goal?.primaryTag?.title ?? "")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Circular progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            Color.white.opacity(0.3),
                            lineWidth: LayoutConstants.ProgressCircle.largeLineWidth
                        )
                        .frame(width: LayoutConstants.ProgressCircle.largeDiameter, height: LayoutConstants.ProgressCircle.largeDiameter)
                    
                    // Progress circle with gradient
                    Circle()
                        .trim(from: 0, to: min(activeSessionDetails.progress, 1.0))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .white,
                                    session.themeNeon,
                                    .white
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: LayoutConstants.ProgressCircle.largeLineWidth, lineCap: .round)
                        )
                        .frame(width: LayoutConstants.ProgressCircle.largeDiameter, height: LayoutConstants.ProgressCircle.largeDiameter)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: activeSessionDetails.progress)
                    
                    // Time display in center
                    VStack(spacing: 12) {
                        if let timeText = activeSessionDetails.timeText {
                            Text(timeText)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                        
                        // Progress percentage
                        Text("\(Int(activeSessionDetails.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        // Daily target info
                        Text("of \(activeSessionDetails.dailyTarget.formatted(style: .hourMinute))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
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
                        Text(Duration.seconds(intervalTimeRemaining).formatted(.time(pattern: .minuteSecond)))
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
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
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
                            .foregroundStyle(session.themeDark)
                            .frame(width: LayoutConstants.ProgressCircle.standardDiameter, height: LayoutConstants.ProgressCircle.standardDiameter)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            )
                    }
                    
                    // Adjustments button
                    Button {
                        showingAdjustments = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
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

#Preview {
    
    let theme = GoalTag(title: "Wellness", themeID: "purple")
    let goal = Goal(title: "Meditation", primaryTag: theme, weeklyTarget: 3600)
    let day = Day(start: Date(), end: Date())
    let session = GoalSession(title: "Meditation", goal: goal, day: day)
    let details = ActiveSessionDetails(id: session.id, startDate: Date().addingTimeInterval(-600), elapsedTime: 600, dailyTarget: 1200)
    
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
