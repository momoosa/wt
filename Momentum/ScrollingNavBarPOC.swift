import SwiftUI

// MARK: - POC: Custom Scrolling Nav Bar using onScrollGeometryChange

struct ScrollingNavBarPOC: View {
    @State private var scrollOffset: CGFloat = 0
    
    // How far the user needs to scroll before the bar is fully collapsed
    private let collapseThreshold: CGFloat = 120
    
    // Progress from 0 (top, expanded) to 1 (collapsed)
    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseThreshold, 0), 1)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Scrollable content — sits behind the header
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Spacer to push content below the expanded header
                    Color.clear
                        .frame(height: 140)
                    
                    ForEach(0..<30) { i in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 72)
                            .overlay {
                                HStack {
                                    Circle()
                                        .fill(.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    VStack(alignment: .leading) {
                                        Text("Item \(i + 1)")
                                            .fontWeight(.medium)
                                        Text("Some detail text")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Transform: extract just the Y offset
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { oldValue, newValue in
                scrollOffset = newValue
            }
            
            // Custom nav bar overlay — animates based on scroll offset
            customNavBar
        }
    }
    
    // MARK: - Custom Nav Bar
    
    private var customNavBar: some View {
        VStack(spacing: 0) {
            // The bar content
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Subtitle — fades out as you scroll
                        Text("Good Morning")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .opacity(1 - collapseProgress)
                            .offset(y: -10 * collapseProgress)
                        
                        // Title — shrinks and stays
                        Text("Today")
                            .font(.system(
                                size: lerp(from: 34, to: 20, progress: collapseProgress),
                                weight: .bold,
                                design: .rounded
                            ))
                    }
                    
                    Spacer()
                    
                    // Avatar — shrinks
                    Circle()
                        .fill(.blue.gradient)
                        .frame(
                            width: lerp(from: 44, to: 32, progress: collapseProgress),
                            height: lerp(from: 44, to: 32, progress: collapseProgress)
                        )
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: lerp(from: 20, to: 14, progress: collapseProgress)))
                        }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .frame(height: lerp(from: 140, to: 80, progress: collapseProgress))
            .background {
                // Blur background — opacity increases as you scroll
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(collapseProgress)
            }
            .background {
                // Solid fallback for expanded state
                Rectangle()
                    .fill(Color(.systemBackground))
                    .opacity(1 - collapseProgress)
            }
            
            // Bottom separator — fades in
            Divider()
                .opacity(collapseProgress)
        }
    }
    
    // MARK: - Helpers
    
    /// Linear interpolation between two values
    private func lerp(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

#Preview("Scrolling Nav Bar") {
    ScrollingNavBarPOC()
        .ignoresSafeArea(edges: .top)
}

#Preview("Scrolling Nav Bar — Dark") {
    ScrollingNavBarPOC()
        .ignoresSafeArea(edges: .top)
        .preferredColorScheme(.dark)
}
