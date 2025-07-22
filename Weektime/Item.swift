//
//  Item.swift
//  Weektime
//
//  Created by Mo Moosa on 22/07/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
