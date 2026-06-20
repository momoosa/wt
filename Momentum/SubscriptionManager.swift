//
//  SubscriptionManager.swift
//  Momentum
//

import SwiftUI

@Observable
class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    var isSubscribed: Bool {
        get {
            access(keyPath: \.isSubscribed)
            return UserDefaults.standard.bool(forKey: "isSubscribed")
        }
        set {
            withMutation(keyPath: \.isSubscribed) {
                UserDefaults.standard.set(newValue, forKey: "isSubscribed")
            }
        }
    }
}
