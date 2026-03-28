//
//  WatchSessionRow.swift
//  MomentumWatch Watch App
//
//  Created by Mo Moosa on 02/03/2026.
//

import SwiftUI
import MomentumKit
import WatchKit

struct WatchSessionRow: View {
    let session: GoalSession
    let day: Day
    
    @State private var showingStartAlert = false
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    private var formattedTime: String {
        let elapsedMinutes = Int(session.elapsedTime / 60)
        return "\(elapsedMinutes)m"
    }
    
    var body: some View {
        Button {
            startSession()
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.goal?.title ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle((session.goal?.primaryTag?.theme ?? themePresets[0]).textColor(for: colorScheme))
                    
                    HStack(spacing: 4) {
                        Text(formattedTime)
                            .font(.caption2)
                            .foregroundStyle((session.goal?.primaryTag?.theme ?? themePresets[0]).textColor(for: colorScheme).opacity(0.7))
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Play button
                Image(systemName: "play.circle.fill")
                    .foregroundStyle((session.goal?.primaryTag?.theme ?? themePresets[0]).textColor(for: colorScheme))
            }
            .padding(6)
            .background(
                LinearGradient(
                    colors: [
                        (session.goal?.primaryTag?.theme ?? themePresets[0]).neon,
                        (session.goal?.primaryTag?.theme ?? themePresets[0]).dark
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .alert("Timer Request", isPresented: $showingStartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if connectivityManager.isReachable {
                Text("Starting timer for \(session.goal?.title ?? "session")")
            } else {
                Text("iPhone not reachable. Command queued.")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                quickLog(minutes: 5)
            } label: {
                Label("+5m", systemImage: "plus.circle.fill")
            }
            .tint(.green)
            
            Button {
                quickLog(minutes: 15)
            } label: {
                Label("+15m", systemImage: "plus.circle.fill")
            }
            .tint(.blue)
        }
    }
    
    private func startSession() {
        // Haptic feedback
        WKInterfaceDevice.current().play(.start)
        
        // Show feedback
        showingStartAlert = true
        
        // Send start timer request to iPhone via WatchConnectivity
        WatchConnectivityManager.shared.requestStartTimer(sessionID: session.id)
    }
    
    private func quickLog(minutes: Int) {
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Send quick log request to iPhone via WatchConnectivity
        WatchConnectivityManager.shared.requestQuickLog(sessionID: session.id, minutes: minutes)
    }
}
