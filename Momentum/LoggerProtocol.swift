//
//  LoggerProtocol.swift
//  Momentum
//
//  Logging facade for better testability
//

import Foundation
import OSLog

/// Protocol for logging operations
protocol LoggerProtocol {
    func info(_ message: String)
    func debug(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

/// Production logger using OSLog
class ProductionLogger: LoggerProtocol {
    private let logger: Logger
    
    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    func info(_ message: String) {
        logger.info("\(message)")
    }
    
    func debug(_ message: String) {
        logger.debug("\(message)")
    }
    
    func warning(_ message: String) {
        logger.warning("\(message)")
    }
    
    func error(_ message: String) {
        logger.error("\(message)")
    }
}

/// Mock logger for testing
class MockLogger: LoggerProtocol {
    var infoMessages: [String] = []
    var debugMessages: [String] = []
    var warningMessages: [String] = []
    var errorMessages: [String] = []
    
    func info(_ message: String) {
        infoMessages.append(message)
    }
    
    func debug(_ message: String) {
        debugMessages.append(message)
    }
    
    func warning(_ message: String) {
        warningMessages.append(message)
    }
    
    func error(_ message: String) {
        errorMessages.append(message)
    }
}
