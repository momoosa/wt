import SwiftUI

/// A reusable scrolling header that collapses as the user scrolls down.
///
/// Usage:
/// ```
/// ScrollingHeaderView(scrollOffset: scrollOffset) {
///     // Expanded content (subtitle, extra info)
///     Text("Good morning")
/// } title: {
///     Text("Today")
/// } trailing: {
///     Button { } label: { Image(systemName: "plus") }
/// }
/// ```
struct ScrollingHeaderView<Expanded: View, Title: View, Leading: View, Trailing: View>: View {
    let scrollOffset: CGFloat
    let collapseThreshold: CGFloat
    @ViewBuilder let expanded: () -> Expanded
    @ViewBuilder let title: () -> Title
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing
    
    init(
        scrollOffset: CGFloat,
        collapseThreshold: CGFloat = 100,
        @ViewBuilder expanded: @escaping () -> Expanded,
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.scrollOffset = scrollOffset
        self.collapseThreshold = collapseThreshold
        self.expanded = expanded
        self.title = title
        self.leading = leading
        self.trailing = trailing
    }
    
    /// Progress from 0 (expanded) to 1 (collapsed)
    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseThreshold, 0), 1)
    }
    
    private var expandedHeight: CGFloat { 90.0 }
    private var collapsedHeight: CGFloat { 48 }
    
    private var currentHeight: CGFloat {
        lerp(from: expandedHeight, to: collapsedHeight, progress: collapseProgress)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    // Expanded content (date + weather) — fades out on scroll
                    expanded()
                        .opacity(1.0 - collapseProgress * 2.0)
                        .scaleEffect(
                            lerp(from: 1, to: 0.8, progress: collapseProgress),
                            anchor: .leading
                        )
                    
                    Spacer()
                }
                .padding(.horizontal)
                .frame(
                    height: lerp(from: 34, to: 0, progress: collapseProgress),
                    alignment: .center
                )
                .clipped()
                
                Spacer(minLength: 0)
                
                HStack(alignment: .bottom) {
                    // Title — shrinks from large to inline
                    title()
                        .scaleEffect(
                            lerp(from: 1, to: 0.75, progress: collapseProgress),
                            anchor: .bottomLeading
                        )
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom)
            }
            .frame(height: currentHeight)
            // Trailing buttons — fixed position, never collapse
            .overlay(alignment: .topTrailing) {
                trailing()
                    .font(.title3)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            Divider()
                .opacity(collapseProgress)
        }
        .background {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGroupedBackground))
                    .opacity(1.0 - collapseProgress)
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(collapseProgress)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
    
    private func lerp(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

// MARK: - Scroll Offset Tracking Modifier

extension View {
    /// Tracks the scroll offset of the nearest parent ScrollView and writes it to the binding.
    func trackScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        self.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, newValue in
            offset.wrappedValue = newValue
        }
    }
}

// MARK: - Preview

#Preview("Scrolling Header") {
    ScrollingHeaderPreview()
}

private struct ScrollingHeaderPreview: View {
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 100)
                    
                    ForEach(0..<25) { i in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 68)
                            .overlay(alignment: .leading) {
                                Text("Item \(i + 1)")
                                    .padding(.leading)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .trackScrollOffset($scrollOffset)
            
            ScrollingHeaderView(scrollOffset: scrollOffset) {
                Text("Good morning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } title: {
                Text("Today")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            } leading: {
                Button { } label: {
                    Image(systemName: "gear")
                }
            } trailing: {
                HStack(spacing: 16) {
                    Button { } label: {
                        Image(systemName: "plus")
                    }
                    Button { } label: {
                        Image(systemName: "target")
                    }
                }
            }
        }
    }
}
