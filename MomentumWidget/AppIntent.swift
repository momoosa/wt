//
//  AppIntent.swift
//  MomentumWidget
//
//  Created by Mo Moosa on 01/02/2026.
//

import WidgetKit
import AppIntents

enum MediumWidgetLayout: String, AppEnum {
    case compact = "Compact"
    case extended = "Extended"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Layout")
    static var caseDisplayRepresentations: [MediumWidgetLayout: DisplayRepresentation] = [
        .compact: "3 Sessions + Actions",
        .extended: "Up to 6 Sessions"
    ]
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Configure your Momentum widget" }

    @Parameter(title: "Medium Widget Layout", default: .compact)
    var mediumLayout: MediumWidgetLayout
}
