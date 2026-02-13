//
//  ToastView.swift
//  Momentum
//
//  Created by Assistant on 13/02/2026.
//

import SwiftUI

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
    
    @State private var offset: CGFloat = 100
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Text(config.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
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
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offset = 0
                opacity = 1
            }
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            offset = 100
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                    print("Undo tapped")
                }
            ),
            onDismiss: {}
        )
        .padding(.bottom, 80)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}
