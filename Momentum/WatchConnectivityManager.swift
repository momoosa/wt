//
//  WatchConnectivityManager.swift
//  Momentum
//
//  Created by Claude on 08/03/2026.
//

import Foundation
import SwiftUI
import Combine
import WatchConnectivity
import MomentumKit
import OSLog

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    private let session: WCSession
    private let logger = Logger(subsystem: "com.moosa.momentum.ios", category: "WatchConnectivity")

    @Published var isReachable = false

    private override init() {
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            logger.info("WatchConnectivity initialized")
        }
    }

    // MARK: - Send Timer State

    func sendTimerState(sessionID: UUID, isActive: Bool, isPaused: Bool, elapsedTime: TimeInterval, startDate: Date, goalTitle: String, dailyTarget: TimeInterval) {
        guard session.isReachable else {
            logger.debug("Watch not reachable, skipping timer state update")
            return
        }

        let message: [String: Any] = [
            "type": "timerState",
            "sessionID": sessionID.uuidString,
            "isActive": isActive,
            "isPaused": isPaused,
            "elapsedTime": elapsedTime,
            "startDate": startDate.timeIntervalSince1970,
            "goalTitle": goalTitle,
            "dailyTarget": dailyTarget
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            self.logger.error("Failed to send timer state: \(error.localizedDescription)")
        }

        logger.debug("Sent timer state to Watch: \(goalTitle), active: \(isActive)")
    }

    func sendTimerStopped(sessionID: UUID) {
        guard session.isReachable else { return }

        let message: [String: Any] = [
            "type": "timerStopped",
            "sessionID": sessionID.uuidString
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            self.logger.error("Failed to send timer stopped: \(error.localizedDescription)")
        }

        logger.debug("Sent timer stopped to Watch")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WatchConnectivity activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WatchConnectivity activated: \(String(describing: activationState.rawValue))")
        }

        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WatchConnectivity became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WatchConnectivity deactivated")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.logger.debug("Watch reachability changed: \(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.debug("Received message from Watch: \(message)")
        handleWatchMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        logger.debug("Received userInfo from Watch: \(userInfo)")
        handleWatchMessage(userInfo)
    }
    
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "toggleTimer":
            handleToggleTimer(message)
        case "startTimer":
            handleStartTimer(message)
        case "quickLog":
            handleQuickLog(message)
        default:
            logger.warning("Unknown message type from Watch: \(type)")
        }
    }
    
    private func handleToggleTimer(_ message: [String: Any]) {
        guard let sessionIDString = message["sessionID"] as? String,
              let sessionID = UUID(uuidString: sessionIDString) else {
            logger.error("Invalid toggleTimer message format")
            return
        }
        
        logger.info("Received toggle timer request for session: \(sessionID)")
        
        // Post notification to toggle timer
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleTimerFromWatch"),
                object: nil,
                userInfo: ["sessionID": sessionID]
            )
        }
    }
    
    private func handleStartTimer(_ message: [String: Any]) {
        guard let sessionIDString = message["sessionID"] as? String,
              let sessionID = UUID(uuidString: sessionIDString) else {
            logger.error("Invalid startTimer message format")
            return
        }
        
        logger.info("Received start timer request for session: \(sessionID)")
        
        // Post notification to start timer
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("StartTimerFromWatch"),
                object: nil,
                userInfo: ["sessionID": sessionID]
            )
        }
    }
    
    private func handleQuickLog(_ message: [String: Any]) {
        guard let sessionIDString = message["sessionID"] as? String,
              let sessionID = UUID(uuidString: sessionIDString),
              let minutes = message["minutes"] as? Int else {
            logger.error("Invalid quickLog message format")
            return
        }
        
        logger.info("Received quick log request for session: \(sessionID), minutes: \(minutes)")
        
        // Post notification to quick log time
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickLogFromWatch"),
                object: nil,
                userInfo: ["sessionID": sessionID, "minutes": minutes]
            )
        }
    }
}
