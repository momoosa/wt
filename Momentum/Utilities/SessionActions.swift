//
//  SessionActions.swift
//  Momentum
//
//  Shared session action callbacks passed via @Environment to eliminate prop drilling.
//

import SwiftUI
import MomentumKit

/// Bundles common session action callbacks that many child views need.
/// Injected once at the top of the view hierarchy and read by any descendant.
@Observable
final class SessionActions {
    var onSkip: (GoalSession) -> Void
    var onSyncHealthKit: (() -> Void)?
    var isSyncingHealthKit: Bool

    init(
        onSkip: @escaping (GoalSession) -> Void = { _ in },
        onSyncHealthKit: (() -> Void)? = nil,
        isSyncingHealthKit: Bool = false
    ) {
        self.onSkip = onSkip
        self.onSyncHealthKit = onSyncHealthKit
        self.isSyncingHealthKit = isSyncingHealthKit
    }
}

// MARK: - Environment Key

struct SessionActionsKey: EnvironmentKey {
    static let defaultValue = SessionActions()
}

extension EnvironmentValues {
    var sessionActions: SessionActions {
        get { self[SessionActionsKey.self] }
        set { self[SessionActionsKey.self] = newValue }
    }
}
