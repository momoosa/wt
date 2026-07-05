//
//  BottomBarOverlayPoC.swift
//  Momentum
//
//  Maps-style PoC: A floating capsule at the bottom that expands into a full
//  sheet via drag gesture. No UISheetPresentationController, pure SwiftUI overlay.
//

import SwiftUI

// MARK: - PoC Tab

private enum PoCTab: String, CaseIterable {
    case plan = "Plan"
    case goals = "Goals"
    case analytics = "Analytics"
    case search = "Search"

    var icon: String {
        switch self {
        case .plan: return "calendar"
        case .goals: return "target"
        case .analytics: return "chart.bar.fill"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - Main PoC View

struct BottomBarOverlayPoC: View {
    @State private var selectedTab: PoCTab = .plan
    @State private var sheetOffset: CGFloat = 0      // 0 = collapsed, negative = dragged up
    @State private var isAtScrollTop = true           // tracks if inner scroll is at top

    @State private var isExpanded = false
    @GestureState private var dragOffset: CGFloat = 0

    // Layout constants
    private let capsuleHeight: CGFloat = 120
    private let capsuleHPadding: CGFloat = 24
    private let expandedTopInset: CGFloat = 60        // distance from top when expanded
    private let sheetCornerRadius: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let screenH = geo.size.height + geo.safeAreaInsets.top + safeBottom

            // The max travel distance from collapsed position to expanded
            let collapsedY = screenH - safeBottom - capsuleHeight - 16
            let expandedY = expandedTopInset
            let maxTravel = collapsedY - expandedY

            // Current Y of the sheet top edge — allow overshoot for spring bounce
            let baseY = isExpanded ? expandedY : collapsedY
            let rawY = baseY + dragOffset + sheetOffset
            // Clamp during drag (no overshoot), but allow spring overshoot when offset is animating back to 0
            let currentY = min(max(rawY, expandedY - 20), collapsedY + 30)

            // Progress: 0 = collapsed, 1 = fully expanded (can slightly exceed 0–1 during bounce)
            let rawProgress = maxTravel > 0 ? 1.0 - ((currentY - expandedY) / maxTravel) : 0
            let progress = min(max(rawProgress, -0.05), 1.05)

            // Interpolated values — clamp visual properties to valid range
            let visualProgress = min(max(progress, 0), 1.0)
            let currentHPadding = capsuleHPadding * (1.0 - visualProgress)
            let currentRadius = sheetCornerRadius
            let currentHeight = capsuleHeight + (screenH - capsuleHeight - expandedTopInset) * visualProgress

            ZStack {
                // Background content placeholder
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack {
                    Text("Main Content Behind")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Dimming overlay
                if visualProgress > 0.1 {
                    Color.black
                        .opacity(Double(visualProgress) * 0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            collapse()
                        }
                }

                // The floating sheet
                VStack(spacing: 0) {
                    // Grab handle
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Collapsed content — info row
                    if visualProgress < 0.5 {
                        capsuleContent
                            .opacity(max(1.0 - visualProgress * 3.0, 0.0))
                    }

                    // Tab bar — always visible
                    tabBar(progress: visualProgress)
                        .padding(.horizontal, 12)
                        .padding(.top, visualProgress > 0.5 ? 4 : 0)

                    // Expanded content
                    if visualProgress > 0.3 {
                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .opacity(visualProgress)

                        expandedContent
                            .opacity(Double(visualProgress))
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: currentHeight, alignment: .top)
                .clipped()
                .background(
                    RoundedRectangle(cornerRadius: currentRadius, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
                )
                .clipShape(RoundedRectangle(cornerRadius: currentRadius, style: .continuous))
                .padding(.horizontal, currentHPadding)
                .position(x: geo.size.width / 2, y: currentY + currentHeight / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            sheetOffset = value.translation.height
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.height - value.translation.height
                            let draggedProgress = maxTravel > 0
                                ? 1.0 - ((baseY + value.translation.height - expandedY) / maxTravel)
                                : 0

                            let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
                            withAnimation(bouncy) {
                                sheetOffset = 0
                                // Determine target based on progress + velocity
                                if velocity < -200 || draggedProgress > 0.4 {
                                    isExpanded = true
                                } else if velocity > 200 || draggedProgress < 0.6 {
                                    isExpanded = false
                                }
                            }
                        }
                )
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Capsule Content (collapsed info)

    private var capsuleContent: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text("72° Clear")
                        .font(.subheadline.weight(.semibold))
                    Text("window to 4pm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 28)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text("2h 30m free")
                        .font(.subheadline.weight(.semibold))
                    Text("until Standup")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tab Bar

    private func tabBar(progress: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(PoCTab.allCases, id: \.self) { tab in
                let isSelected = isExpanded && selectedTab == tab

                Button {
                    if isExpanded {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } else {
                        selectedTab = tab
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isExpanded = true
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        isSelected
                            ? Color.primary.opacity(0.08)
                            : .clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        TabView(selection: $selectedTab) {
            planContent.tag(PoCTab.plan)
            goalsContent.tag(PoCTab.goals)
            analyticsContent.tag(PoCTab.analytics)
            searchContent.tag(PoCTab.search)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var planContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today's Plan")
                    .font(.title.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ForEach(0..<8) { i in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "target")
                                    .foregroundStyle(Color.accentColor)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Goal \(i + 1)")
                                .font(.subheadline.weight(.medium))
                            Text("30 min remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(Int.random(in: 20...90))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesSheet(isAtTop: $isAtScrollTop, collapse: collapse)
    }

    private var goalsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("All Goals")
                    .font(.title.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                ForEach(0..<12) { i in
                    Text("Goal item \(i + 1)")
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesSheet(isAtTop: $isAtScrollTop, collapse: collapse)
    }

    private var analyticsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Analytics")
                    .font(.title.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                Text("Charts and data here")
                    .padding(.horizontal, 20)
            }
        }
        .scrollDismissesSheet(isAtTop: $isAtScrollTop, collapse: collapse)
    }

    private var searchContent: some View {
        VStack(spacing: 16) {
            Text("Search")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func collapse() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isExpanded = false
        }
    }
}

// MARK: - Scroll-to-Dismiss Modifier

private struct ScrollDismissesSheetModifier: ViewModifier {
    @Binding var isAtTop: Bool
    var collapse: () -> Void

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geo in
                // At top when content offset is at or above the top inset
                geo.contentOffset.y <= geo.contentInsets.top + 1
            } action: { _, newAtTop in
                isAtTop = newAtTop
            }
            .onScrollPhaseChange { oldPhase, newPhase, context in
                // When the user was interacting and scroll settles while at top
                // with upward velocity, collapse the sheet
                if oldPhase == .interacting,
                   newPhase != .interacting,
                   isAtTop,
                   let velocity = context.velocity,
                   velocity.dy > 30 {
                    collapse()
                }
            }
    }
}

private extension View {
    func scrollDismissesSheet(isAtTop: Binding<Bool>, collapse: @escaping () -> Void) -> some View {
        modifier(ScrollDismissesSheetModifier(isAtTop: isAtTop, collapse: collapse))
    }
}

// MARK: - Preview

#Preview {
    BottomBarOverlayPoC()
}
