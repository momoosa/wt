//
//  SessionError.swift
//  Momentum
//
//  Error types for session operations
//

import Foundation

/// Errors that can occur during session operations
enum SessionError: Error, LocalizedError {
    case saveFailed
    case sessionNotFound
    case goalNotFound
    case invalidTarget
    case timerNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save changes"
        case .sessionNotFound:
            return "Session not found"
        case .goalNotFound:
            return "Goal not found"
        case .invalidTarget:
            return "Invalid target value"
        case .timerNotAvailable:
            return "Timer is not available"
        }
    }
}
