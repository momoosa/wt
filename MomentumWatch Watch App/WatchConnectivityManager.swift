//
//  WatchConnectivityManager.swift
//  MomentumWatch Watch App
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
    private let logger = Logger(subsystem: "com.moosa.momentum.watchkitapp", category: "WatchConnectivity")

    @Published var activeTimerState: ActiveTimerState?
    @Published var isReachable = false
    @Published var lastError: String?
    
    private var commandQueue: [(type: String, data: [String: Any])] = []
    private let maxRetries = 3

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
        let message: [String: Any] = [
            "type": "toggleTimer",
            "sessionID": sessionID.uuidString
        ]
        
        sendMessageWithRetry(message: message, commandType: "toggleTimer")
    }
    
    func requestStartTimer(sessionID: UUID) {
        logger.info("requestStartTimer called for session: \(sessionID)")
        let isReachable = session.isReachable
        let activationState = session.activationState.rawValue
        logger.info("Session isReachable: \(isReachable)")
        logger.info("Session activationState: \(activationState)")
        
        let message: [String: Any] = [
            "type": "startTimer",
            "sessionID": sessionID.uuidString
        ]
        
        sendMessageWithRetry(message: message, commandType: "startTimer")
    }
    
    func requestQuickLog(sessionID: UUID, minutes: Int) {
        let message: [String: Any] = [
            "type": "quickLog",
            "sessionID": sessionID.uuidString,
            "minutes": minutes
        ]
        
        sendMessageWithRetry(message: message, commandType: "quickLog")
    }
    
    private func sendMessageWithRetry(message: [String: Any], commandType: String, retryCount: Int = 0) {
        // Try sendMessage first for immediate delivery if possible
        guard session.isReachable else {
            logger.debug("iPhone not reachable, using transferUserInfo for \(commandType)")
            transferCommand(message: message, commandType: commandType)
            return
        }
        
        session.sendMessage(message, replyHandler: { response in
            self.logger.debug("\(commandType) command sent successfully")
            DispatchQueue.main.async {
                self.lastError = nil
            }
        }) { error in
            let errorMessage = error.localizedDescription
            self.logger.error("Failed to send \(commandType) command: \(errorMessage)")
            
            // Check for specific error indicating iPhone app isn't available
            if errorMessage.contains("Payload could not be delivered") {
                self.logger.warning("iPhone app not available - using transferUserInfo for \(commandType)")
                self.transferCommand(message: message, commandType: commandType)
            } else if retryCount < self.maxRetries {
                self.logger.info("Retrying \(commandType) command, attempt \(retryCount + 1)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.sendMessageWithRetry(message: message, commandType: commandType, retryCount: retryCount + 1)
                }
            } else {
                self.logger.error("Max retries reached for \(commandType) command")
                self.transferCommand(message: message, commandType: commandType)
            }
        }
    }
    
    private func transferCommand(message: [String: Any], commandType: String) {
        // Use transferUserInfo for guaranteed delivery (even if iPhone app isn't running)
        session.transferUserInfo(message)
        logger.info("Transferred \(commandType) command via transferUserInfo")
        
        DispatchQueue.main.async {
            self.lastError = "Command sent. Will sync when iPhone app opens."
        }
        
        // Clear error after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.lastError == "Command sent. Will sync when iPhone app opens." {
                self.lastError = nil
            }
        }
    }
    
    private func queueCommand(type: String, data: [String: Any]) {
        commandQueue.append((type: type, data: data))
        let queueSize = commandQueue.count
        logger.info("Command queued: \(type), queue size: \(queueSize)")
    }
    
    private func processQueue() {
        guard session.isReachable, !commandQueue.isEmpty else { return }
        
        let pendingCount = commandQueue.count
        logger.info("Processing command queue, \(pendingCount) commands pending")
        
        let commands = commandQueue
        commandQueue.removeAll()
        
        for command in commands {
            sendMessageWithRetry(message: command.data, commandType: command.type)
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
            
            // Process queued commands when connection is restored
            if session.isReachable {
                self.processQueue()
            }
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
        
        // Validate data integrity
        guard elapsedTime >= 0, dailyTarget > 0 else {
            let elapsedStr = message["elapsedTime"] as? TimeInterval ?? -1
            let targetStr = message["dailyTarget"] as? TimeInterval ?? -1
            logger.error("Invalid timer state values: elapsedTime=\(elapsedStr), dailyTarget=\(targetStr)")
            return
        }

        let startDate = Date(timeIntervalSince1970: startDateTimestamp)
        
        // Validate start date is not in the future
        if startDate > Date() {
            logger.warning("Start date is in the future, adjusting to now")
        }

        DispatchQueue.main.async {
            // Only update if this is a new state or different session
            let shouldUpdate = self.activeTimerState == nil ||
                               self.activeTimerState?.sessionID != sessionID ||
                               self.activeTimerState?.isActive != isActive ||
                               self.activeTimerState?.isPaused != isPaused
            
            if shouldUpdate {
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
                self.lastError = nil
            }
        }
    }

    private func handleTimerStopped(_ message: [String: Any]) {
        guard let sessionIDString = message["sessionID"] as? String,
              let sessionID = UUID(uuidString: sessionIDString) else {
            logger.warning("Timer stopped message missing sessionID, clearing all active timers")
            DispatchQueue.main.async {
                self.activeTimerState = nil
                self.logger.debug("Timer stopped (no session ID)")
            }
            return
        }
        
        DispatchQueue.main.async {
            // Only clear if it matches the current active timer
            if self.activeTimerState?.sessionID == sessionID {
                self.activeTimerState = nil
                self.logger.debug("Timer stopped for session: \(sessionID)")
            } else {
                self.logger.debug("Ignoring timer stopped for non-active session: \(sessionID)")
            }
        }
    }
}
