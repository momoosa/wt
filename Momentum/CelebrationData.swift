//
//  CelebrationData.swift
//  Momentum
//
//  Snapshot of session data captured before the timer is stopped,
//  used to populate the celebration sheet.
//

import Foundation
import MomentumKit

struct CelebrationData: Identifiable {
    let id = UUID()
    
    // Core session info
    let goalTitle: String
    let goalID: UUID
    let sessionDuration: TimeInterval
    let todayDoneCount: Int
    let targetUnit: Goal.TargetUnit
    let theme: ThemePreset
    let streak: Int
    let suggestedNextSession: GoalSession?
}
