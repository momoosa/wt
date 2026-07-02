//
//  ToastView.swift
//  Momentum
//
//  Created by Assistant on 13/02/2026.
//

import SwiftUI
import OSLog
import MomentumKit

/// Toast configuration for displaying temporary messages with optional undo action
struct ToastConfig: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let showUndo: Bool
    let onUndo: (() -> Void)?
    
    init(message: String, showUndo: Bool = false, onUndo: (() -> Void)? = nil) {
        self.message = message
        self.showUndo = showUndo
        self.onUndo = onUndo
    }
    
    static func == (lhs: ToastConfig, rhs: ToastConfig) -> Bool {
        lhs.id == rhs.id
    }
}

/// Toast view that appears above the bottom toolbar
struct ToastView: View {
    let config: ToastConfig
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var offset: CGFloat = -300
    @State private var opacity: Double = 0
    
    private var backgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Fill the top safe area
                backgroundColor
                    .frame(height: geo.safeAreaInsets.top)
                
                // Toast message content
                HStack(spacing: 12) {
                    Text(config.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                    
                    Spacer()
                    
                    if config.showUndo, let onUndo = config.onUndo {
                        Button(action: {
                            onUndo()
                            dismiss()
                        }) {
                            Text("Undo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(colorScheme == .dark ? .black.opacity(0.6) : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(backgroundColor)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            .ignoresSafeArea(edges: .top)
            .offset(y: offset)
            .opacity(opacity)
        }
        .frame(height: 0, alignment: .top)
        .onAppear {
            withAnimation(AnimationPresets.smoothSpring) {
                offset = 0
                opacity = 1
            }
            
            // Auto-dismiss after 4 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            offset = -300
            opacity = 0
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            onDismiss()
        }
    }
}

#Preview {
    VStack {
        Spacer()
        
        ToastView(
            config: ToastConfig(
                message: "Goal skipped",
                showUndo: true,
                onUndo: {
                    AppLogger.app.debug("Undo tapped")
                }
            ),
            onDismiss: {}
        )
        .padding(.bottom, 80)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}
