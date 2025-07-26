//
//  GoalTheme.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 26/07/2025.
//

import Foundation
import SwiftData

@Model
public final class GoalTheme {
    public var title: String
    public private(set) var theme: Theme
    
    public init(title: String, color: Theme) {
        self.title = title
        self.theme = color
    }
}
