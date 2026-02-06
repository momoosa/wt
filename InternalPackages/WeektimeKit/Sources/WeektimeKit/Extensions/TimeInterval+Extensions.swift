//
//  TimeInterval+Extensions.swift
//  WeektimeKit
//
//  Centralized time formatting utilities
//

import Foundation

public extension TimeInterval {
    /// Different time formatting styles
    enum TimeFormatStyle {
        /// Formats as "Xh Ym" (e.g., "1h 30m" or "45m")
        case hourMinute
        /// Formats as "H:MM:SS" or "M:SS" (e.g., "1:30:45" or "5:30")
        case hmmss
        /// Formats as "Xh Ym Zs" with all components (e.g., "1h 30m 15s")
        case components
        /// Formats with units spelled out (e.g., "1 hour 30 minutes")
        case fullUnits
    }

    /// Formats the time interval based on the specified style
    /// - Parameter style: The formatting style to use (default: .hourMinute)
    /// - Returns: Formatted time string
    func formatted(style: TimeFormatStyle = .hourMinute) -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        switch style {
        case .hourMinute:
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }

        case .hmmss:
            if hours > 0 {
                return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
            } else if minutes > 0 {
                return "\(minutes):\(String(format: "%02d", seconds))"
            } else {
                return "0:\(String(format: "%02d", seconds))"
            }

        case .components:
            var parts: [String] = []
            if hours > 0 { parts.append("\(hours)h") }
            if minutes > 0 { parts.append("\(minutes)m") }
            if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
            return parts.joined(separator: " ")

        case .fullUnits:
            var parts: [String] = []
            if hours > 0 {
                parts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
            }
            if minutes > 0 {
                parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
            }
            if seconds > 0 || parts.isEmpty {
                parts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")")
            }
            return parts.joined(separator: " ")
        }
    }
}
