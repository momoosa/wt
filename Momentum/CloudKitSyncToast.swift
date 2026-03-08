//
//  CloudKitSyncToast.swift
//  Momentum
//
//  Created by Assistant on 08/03/2026.
//

import SwiftUI

struct CloudKitSyncToast: View {
    let status: SyncStatus
    @Binding var isShowing: Bool
    
    enum SyncStatus: Equatable {
        case enabled
        case syncing
        case error(String)
        
        var icon: String {
            switch self {
            case .enabled: return "checkmark.icloud.fill"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.icloud.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .enabled: return .green
            case .syncing: return .blue
            case .error: return .red
            }
        }
        
        var title: String {
            switch self {
            case .enabled: return "iCloud Sync Enabled"
            case .syncing: return "Syncing to iCloud"
            case .error: return "iCloud Sync Issue"
            }
        }
        
        var message: String {
            switch self {
            case .enabled: return "Your data syncs across all your devices"
            case .syncing: return "Setting up sync..."
            case .error(let errorMsg): return errorMsg
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundStyle(status.color)
                    .symbolEffect(.pulse, isActive: status == .syncing)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(status.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )
            .padding(.horizontal)
            .padding(.bottom, 100) // Above tab bar
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 5 seconds for success, 8 seconds for errors
            let dismissTime: Double = {
                switch status {
                case .enabled, .syncing: return 5.0
                case .error: return 8.0
                }
            }()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isShowing = false
                }
            }
        }
    }
}

// View modifier for easy toast presentation
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let status: CloudKitSyncToast.SyncStatus
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                CloudKitSyncToast(status: status, isShowing: $isShowing)
            }
        }
    }
}

extension View {
    func cloudKitSyncToast(isShowing: Binding<Bool>, status: CloudKitSyncToast.SyncStatus) -> some View {
        modifier(ToastModifier(isShowing: isShowing, status: status))
    }
}

#Preview {
    VStack {
        Text("Preview")
    }
    .cloudKitSyncToast(isShowing: .constant(true), status: .enabled)
}
