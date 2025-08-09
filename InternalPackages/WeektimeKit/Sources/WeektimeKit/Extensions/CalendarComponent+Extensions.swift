//
//  File.swift
//  WeektimeKit
//
//  Created by Mo Moosa on 27/07/2025.
//

import Foundation

public extension Calendar.Component {
    static let yearMonthDay: Set<Calendar.Component> = [.year, .month, .day]
    static let yearMonthDayAndTime: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
}
