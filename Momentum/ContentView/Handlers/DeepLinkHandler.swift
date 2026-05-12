//
//  DeepLinkHandler.swift
//  Momentum
//
//  Extracted from ContentView.swift — Deep link handling
//

import SwiftUI
import MomentumKit
import OSLog

// MARK: - Deep Link Handling

extension ContentView {
    
    func handleDeepLink(sessionID: String?) {
        guard let sessionID = sessionID,
              let uuid = UUID(uuidString: sessionID),
              let session = sessions.first(where: { $0.id == uuid }) else {
            AppLogger.app.warning("Session not found for ID: \(sessionID ?? "nil")")
            return
        }
        
        AppLogger.app.info("Found session to open: \(session.title)")
        
        // Open the session detail using selectedSession which triggers NavigationLink
        navigation.selectedSession = session
        
    }
}
