//
//  WatchConnectivityManager.swift
//  MomentumWatch Watch App
//
//  Created by Claude on 08/03/2026.
//

import Foundation
import WatchConnectivity
import MomentumKit
import OSLog

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    private let session: WCSession
    private let logger = Logger(subsystem: "com.moosa.momentum.watchkitapp", category: "WatchConnectivity")

    @Published var activeTimerState: ActiveTimerState?
    @Published var isReachable = false

    struct ActiveTimerState: Equatable {
        let sessionID: UUID
        let isActive: Bool
        let isPaused: Bool
        let elapsedTime: TimeInterval
        let startDate: Date
        let goalTitle: String
        let dailyTarget: TimeInterval
    }

    private override init() {
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            logger.info("WatchConnectivity initialized")
        }
    }

    // MARK: - Send Timer Commands

    func requestTimerToggle(sessionID: UUID) {
        guard session.isReachable else {
            logger.debug("iPhone not reachable")
            return
        }

        let message: [String: Any] = [
            "type": "toggleTimer",
            "sessionID": sessionID.uuidString
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            self.logger.error("Failed to send toggle command: \(error.localizedDescription)")
        }
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

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.logger.debug("iPhone reachability changed: \(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.debug("Received message from iPhone: \(message)")

        guard let type = message["type"] as? String else { return }

        switch type {
        case "timerState":
            handleTimerState(message)
        case "timerStopped":
            handleTimerStopped(message)
        default:
            logger.warning("Unknown message type: \(type)")
        }
    }

    private func handleTimerState(_ message: [String: Any]) {
        guard
            let sessionIDString = message["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let isActive = message["isActive"] as? Bool,
            let isPaused = message["isPaused"] as? Bool,
            let elapsedTime = message["elapsedTime"] as? TimeInterval,
            let startDateTimestamp = message["startDate"] as? TimeInterval,
            let goalTitle = message["goalTitle"] as? String,
            let dailyTarget = message["dailyTarget"] as? TimeInterval
        else {
            logger.error("Invalid timer state message format")
            return
        }

        let startDate = Date(timeIntervalSince1970: startDateTimestamp)

        DispatchQueue.main.async {
            self.activeTimerState = ActiveTimerState(
                sessionID: sessionID,
                isActive: isActive,
                isPaused: isPaused,
                elapsedTime: elapsedTime,
                startDate: startDate,
                goalTitle: goalTitle,
                dailyTarget: dailyTarget
            )
            self.logger.debug("Updated active timer state: \(goalTitle)")
        }
    }

    private func handleTimerStopped(_ message: [String: Any]) {
        DispatchQueue.main.async {
            self.activeTimerState = nil
            self.logger.debug("Timer stopped")
        }
    }
}
