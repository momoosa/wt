import SwiftUI
import SwiftData
import WeektimeKit
import UserNotifications

struct ChecklistDetailView: View {
    var session: GoalSession
    @Environment(\.editMode) private var editMode
    @Environment(\.modelContext) private var context
    @Environment(GoalStore.self) private var goalStore
    var animation: Namespace.ID
    var timerManager: SessionTimerManager
    let historicalSessionLimit = 3
    @State var isShowingEditScreen = false
    @State private var isShowingIntervalsEditor = false
    // Interval playback state
    @State private var activeIntervalID: String? = nil
    @State private var intervalStartDate: Date? = nil
    @State private var intervalElapsed: TimeInterval = 0
    @State private var uiTimer: Timer? = nil

    @State private var selectedListID: String?
    @State private var isShowingListsOverview = false
    
    // Card tilt and shimmer states
    @State private var cardRotationY: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    var tintColor: Color {
        session.goal.primaryTheme.theme.dark
    }
    
    // Weekly progress calculation
    var weeklyProgress: Double {
        let target = session.goal.weeklyTarget
        guard target > 0 else { return 0 }
        return weeklyElapsedTime / target
    }
    
    var weeklyElapsedTime: TimeInterval {
        // Placeholder - would need to sum all sessions in the week
        return session.elapsedTime
    }
    
    var body: some View {
        List {
            // Progress Summary Card
            Section {
                ProgressSummaryCard(
                    goalTitle: session.goal.title,
                    themeName: session.goal.primaryTheme.title,
                    themeColors: session.goal.primaryTheme.theme,
                    dailyProgress: session.progress,
                    dailyElapsed: session.elapsedTime,
                    dailyTarget: session.dailyTarget,
                    weeklyProgress: weeklyProgress,
                    weeklyElapsed: weeklyElapsedTime,
                    weeklyTarget: session.goal.weeklyTarget,
                    cardRotationY: $cardRotationY,
                    shimmerOffset: $shimmerOffset
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Action Buttons
            Section {
                HStack(spacing: 12) {
                    // Mark as Done button
                    Button {
                        markGoalAsDone()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                            Text("Done")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tintColor.opacity(0.15))
                        .foregroundStyle(tintColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    // Start/Stop button
                    Button {
                        timerManager.toggleTimer(for: session, in: session.day)
                    } label: {
                        let isActive = timerManager.isActive(session)
                        VStack(spacing: 4) {
                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                            Text(isActive ? "Pause" : "Start")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(tintColor.opacity(0.15))
                        .foregroundStyle(tintColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    // Skip button
                    Button {
                        skipGoalForToday()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "forward.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                            Text("Skip")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listRowBackground(Color.clear)
            
            // History section remains as-is
            Section {
                if !session.historicalSessions.isEmpty {
                    ForEach(session.historicalSessions.prefix(historicalSessionLimit)) { historicalSession in
                        HistoricalSessionRow(session: historicalSession, showsTimeSummaryInsteadOfTitle: true)
                            .foregroundStyle(.primary)
                            .swipeActions {
                                // Only allow deletion of manual entries, not HealthKit synced ones
                                if historicalSession.healthKitType == nil {
                                    Button {
                                        withAnimation {
                                            context.delete(historicalSession)
                                            Task { try context.save() }
                                        }
                                    } label: {
                                        Label { Text("Delete") } icon: { Image(systemName: "xmark.bin") }
                                    }
                                    .tint(.red)
                                }
                            }
                    }
                } else {
                    ContentUnavailableView {
                        Text("No progress for this goal today.")
                    } description: { } actions: {
                        Button { } label: { Text("Add manual entry") }
                    }
                }
            } header: {
                HStack {
                    Text("History")
                    Text("\(session.historicalSessions.count)")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(4)
                        .frame(minWidth: 20)
                        .background(Capsule().fill(session.goal.primaryTheme.theme.dark))
                    Spacer()
                    Button { } label: { Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical) }
                }
            } footer: {
                if session.historicalSessions.count > historicalSessionLimit {
                    HStack { Spacer(); Button { } label: { Text("View all") }; Spacer() }
                }
            }

            // NEW: Horizontal tabs for lists
            Section {
                TabView(selection: $selectedListID) {
                    ForEach(session.intervalLists) { listSession in
                        IntervalListView(listSession: listSession, activeIntervalID: $activeIntervalID, intervalStartDate: $intervalStartDate, intervalElapsed: $intervalElapsed, uiTimer: $uiTimer, limit: 3)
                            .tag(listSession.id)
                    }
                }
                .tabViewStyle(.page)
                .frame(minHeight: 200)
                .onAppear {
                    if selectedListID == nil {
                        selectedListID = session.intervalLists.first?.id
                    }
                }
            } header: {
                VStack {
                    HStack {
                        Button {
                            isShowingListsOverview = true
                        } label: {
                            Text("Lists") // TODO: Naming
                            Text("\(session.intervalLists.count)")
                                .font(.caption2)
                                .foregroundStyle(Color(.systemBackground))
                                .padding(2)
                                .frame(minWidth: 15)
                                .background(Capsule().fill(tintColor))
                            Image(systemName: "chevron.right")
                                .tint(tintColor)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        Button {
                            isShowingIntervalsEditor = true
                        } label: { Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical) }
                    }
                    
                    IntervalListSelector(lists: session.intervalLists, selectedListID: $selectedListID, tintColor: tintColor)
                }

            }
        }
        .scrollContentBackground(.hidden)
        .background(session.goal.primaryTheme.theme.dark.opacity(0.1))
        .navigationTitle(session.goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    
                    Button {
                        withAnimation {
                            session.goal.status = .archived
                        }
                    } label: {
                        if session.goal.status == .archived {
                            Text("Unarchive")
                        } else {
                            Text("Archive")
                        }
                    }
                } label: {
                    
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                    
                }
                
                
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditScreen.toggle()
                    
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                    
                }
                
            }
            
        }
        .navigationDestination(isPresented: $isShowingListsOverview) {
            ListsOverviewView(session: session, selectedListID: $selectedListID, tintColor: tintColor)
        }
        .navigationTransition(.zoom(sourceID: session.id, in: animation))
        .sheet(isPresented: $isShowingIntervalsEditor) {
            let list = IntervalList(name: "", goal: session.goal)
            IntervalsEditorView(list: list, goalSession: session)
        }
        .onDisappear {
            let emptyItems = session.checklist.filter { $0.checklistItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for item in emptyItems {
                if let index = session.checklist.firstIndex(where: { $0.id == item.id }) {
                    session.checklist.remove(at: index)
                }
                context.delete(item)
                context.delete(item.checklistItem)
            }
//            stopUITimer() // TODO:
        }
    }
  

    
    // TODO:
//    var intervalSection: some View {
//        Section {
//            ForEach(session.intervals.sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex }), id: \.id) { item in
//                let filteredSorted = session.intervals
//                    .filter { $0.interval.kind == item.interval.kind && $0.interval.name == item.interval.name }
//                    .sorted(by: { $0.interval.orderIndex < $1.interval.orderIndex })
//                let totalCount = filteredSorted.count
//                let currentIndex = (filteredSorted.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
//
//                ZStack(alignment: .leading) {
//                    // Background progress bar filling full row height
//                    let duration = TimeInterval(item.interval.durationSeconds)
//                    let isActive = activeIntervalID == item.id
//                    let elapsed = isActive ? intervalElapsed : 0
//                    let progress = min(max(elapsed / max(duration, 0.001), 0), 1)
//
//                    GeometryReader { geo in
//                        let width = geo.size.width * progress
//                        Rectangle()
//                            .fill(session.goal.primaryTheme.theme.light.opacity(0.25))
//                            .frame(width: width)
//                            .animation(.easeInOut(duration: 0.2), value: progress)
//                    }
//                    .allowsHitTesting(false)
//
//                    HStack {
//                        VStack(alignment: .leading, spacing: 4) {
//                            let isCompleted = item.isCompleted
//                            let displayElapsed: TimeInterval = {
//                                if isCompleted { return TimeInterval(item.interval.durationSeconds) }
//                                return isActive ? min(elapsed, duration) : 0
//                            }()
//                            let total = TimeInterval(item.interval.durationSeconds)
//
//                            Text("\(item.interval.name) \(currentIndex)/\(totalCount)")
//                                .fontWeight(.semibold)
//                                .strikethrough(isCompleted, pattern: .solid, color: .primary)
//                                .opacity(isCompleted ? 0.6 : 1)
//
//                            if isCompleted {
//                                Text("\(Duration.seconds(displayElapsed).formatted(.time(pattern: .minuteSecond)))/\(Duration.seconds(total).formatted(.time(pattern: .minuteSecond)))")
//                                    .font(.caption)
//                                    .opacity(0.7)
//                            } else {
//                                let remaining = max(total - displayElapsed, 0)
//                                Text("\(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond))) remaining")
//                                    .font(.caption)
//                                    .opacity(0.7)
//                            }
//                        }
//                        Spacer()
//                        Button {
////                            toggleIntervalPlayback(for: item, in: session)
//                        } label: {
//                            Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
//                                .symbolRenderingMode(.hierarchical)
//                                .font(.title2)
//                        }
//                        .buttonStyle(.plain)
//                    }
//                    .padding(.vertical, 8)
//                }
//                .contentShape(Rectangle())
//                .onTapGesture {
//                    withAnimation {
//                        item.isCompleted.toggle()
//                    }
//                }
//            }
//        } header: {
//            HStack {
//                Text("To do")
//                Text("\(session.intervals.filter { $0.isCompleted }.count)/\(session.intervals.count)")
//                    .font(.caption2)
//                    .foregroundStyle(Color(.systemBackground))
//                    .padding(4)
//                    .background(Capsule()
//                        .fill(session.goal.primaryTheme.theme.dark))
//                Spacer()
//                Button {
//                    addChecklistItem(to: session)
//                } label: {
//                    Image(systemName: "plus.circle.fill")
//                        .symbolRenderingMode(.hierarchical)
//                }
//            }
//        } footer: {
//            if session.intervals.count > historicalSessionLimit {
//                HStack {
//                    Spacer()
//                    Button {
//                        //                            dayToEdit = day
//                    } label: {
//                        Text("View all")
//                    }
//                    //                        .buttonStyle(PrimaryButtonStyle(color: goal.color))
//                    Spacer()
//                }
//            }
//        }
//    }
    
    private func addChecklistItem(to session: GoalSession) {
        let item = ChecklistItem(title: "")
        let checklistSession = ChecklistItemSession(checklistItem: item, isCompleted: false, session: session)
        session.checklist.append(checklistSession)
        context.insert(checklistSession)
    }
    
    // MARK: - Goal Actions
    
    private func markGoalAsDone() {
        timerManager.markGoalAsDone(session: session, day: session.day, context: context)
    }
    
    private func skipGoalForToday() {
        withAnimation {
            // Mark session as skipped
            session.status = .skipped
        }
        
        try? context.save()
    }
    
    // MARK: - Notifications
    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }

    private func notificationIdentifier(for interval: IntervalSession) -> String {
        return "interval_\(interval.id)"
    }
// TODO: 
//    private func cancelAllIntervalNotifications(for session: GoalSession) {
//        let ids = session.intervals.map { notificationIdentifier(for: $0) }
//        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
//    }
//
//    private func scheduleNotifications(from current: IntervalSession, in session: GoalSession, startingIn secondsOffset: TimeInterval = 0) {
//        // Schedule notification for current interval end and all subsequent intervals
//        requestNotificationAuthorizationIfNeeded()
//        let sorted = session.intervals.sorted { $0.interval.orderIndex < $1.interval.orderIndex }
//        guard let startIndex = sorted.firstIndex(where: { $0.id == current.id }) else { return }
//        var cumulative: TimeInterval = secondsOffset
//        for idx in startIndex..<sorted.count {
//            let item = sorted[idx]
//            let duration = TimeInterval(item.interval.durationSeconds)
//            cumulative += duration
//            let content = UNMutableNotificationContent()
//            content.title = session.goal.title
//            content.body = "\(item.interval.name) complete"
//            content.sound = .default
//
//            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(cumulative, 0.5), repeats: false)
//            let request = UNNotificationRequest(identifier: notificationIdentifier(for: item), content: content, trigger: trigger)
//            UNUserNotificationCenter.current().add(request)
//        }
//    }
}

// MARK: - Progress Summary Card

struct ProgressSummaryCard: View {
    let goalTitle: String
    let themeName: String
    let themeColors: Theme
    let dailyProgress: Double
    let dailyElapsed: TimeInterval
    let dailyTarget: TimeInterval
    let weeklyProgress: Double
    let weeklyElapsed: TimeInterval
    let weeklyTarget: TimeInterval
    
    @Binding var cardRotationY: Double
    @Binding var shimmerOffset: CGFloat
    
    // Compute text color based on background luminance
    private var textColor: Color {
        // Calculate average luminance of the gradient colors
        let colors = [themeColors.light, themeColors.neon, themeColors.dark]
        let luminances = colors.compactMap { $0.luminance }
        let averageLuminance = luminances.isEmpty ? 0.5 : luminances.reduce(0, +) / Double(luminances.count)
        
        // Use black text if background is light (luminance > 0.5), white otherwise
        return averageLuminance > 0.5 ? .black : .white
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Card background with radial gradient
                RadialGradient(
                    colors: [
                        themeColors.light,
                        themeColors.neon,
                        themeColors.dark
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .blur(radius: 40)
                
                // Shimmer overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: shimmerOffset, y: shimmerOffset)
                .blur(radius: 20)
                
                // Card content
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goalTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(textColor)
                        
                        Text(themeName)
                            .font(.subheadline)
                            .foregroundStyle(textColor.opacity(0.8))
                    }
                    
                    
                    // Progress stats
                    HStack(spacing: 30) {
                        // Daily progress
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TODAY")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(textColor.opacity(0.7))
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatTime(dailyElapsed))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(textColor)
                                
                                Text("/ \(formatTime(dailyTarget))")
                                    .font(.subheadline)
                                    .foregroundStyle(textColor.opacity(0.7))
                            }
                            
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(textColor.opacity(0.3))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(textColor)
                                        .frame(width: geo.size.width * min(dailyProgress, 1.0), height: 6)
                                        .animation(.spring(response: 0.6), value: dailyProgress)
                                }
                            }
                            .frame(height: 6)
                            
                            Text("\(Int(min(dailyProgress, 1.0) * 100))% complete")
                                .font(.caption)
                                .foregroundStyle(textColor.opacity(0.8))
                        }
                        
                        // Weekly progress
                        VStack(alignment: .leading, spacing: 8) {
                            Text("THIS WEEK")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(textColor.opacity(0.7))
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatTime(weeklyElapsed))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(textColor)
                                
                                Text("/ \(formatTime(weeklyTarget))")
                                    .font(.subheadline)
                                    .foregroundStyle(textColor.opacity(0.7))
                            }
                            
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(textColor.opacity(0.3))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(textColor)
                                        .frame(width: geo.size.width * min(weeklyProgress, 1.0), height: 6)
                                        .animation(.spring(response: 0.6), value: weeklyProgress)
                                }
                            }
                            .frame(height: 6)
                            
                            Text("\(Int(min(weeklyProgress, 1.0) * 100))% complete")
                                .font(.caption)
                                .foregroundStyle(textColor.opacity(0.8))
                        }
                    }
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: themeColors.dark.opacity(0.4), radius: 20, x: 0, y: 10)
            .rotation3DEffect(
                .degrees(cardRotationY),
                axis: (x: 0, y: 1, z: 0)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Calculate rotation based on horizontal drag only
                        let maxRotation: Double = 15
                        let width = geometry.size.width
                        
                        // Y-axis rotation (left-right tilt)
                        let xOffset = value.location.x - width / 2
                        let newRotationY = (xOffset / width) * maxRotation * 2
                        
                        // Animate rotation changes
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                            cardRotationY = newRotationY
                            shimmerOffset = -200 + (value.location.x / width) * 400
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            cardRotationY = 0
                            shimmerOffset = -200
                        }
                    }
            )
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Add subtle animation when device orientation changes
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    shimmerOffset = shimmerOffset == -200 ? 200 : -200
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        shimmerOffset = -200
                    }
                }
            }
            #endif
        }
        .frame(minHeight: 200)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Color Luminance Extension

extension Color {
    /// Calculates the relative luminance of a color
    /// Returns a value between 0 (darkest) and 1 (lightest)
    var luminance: Double? {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components else { return nil }
        #elseif os(macOS)
        guard let components = NSColor(self).cgColor.components else { return nil }
        #endif
        
        // Ensure we have RGB components
        guard components.count >= 3 else { return nil }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Calculate relative luminance using the standard formula
        // https://www.w3.org/TR/WCAG20/#relativeluminancedef
        let rsRGB = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gsRGB = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bsRGB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        return 0.2126 * rsRGB + 0.7152 * gsRGB + 0.0722 * bsRGB
    }
}



