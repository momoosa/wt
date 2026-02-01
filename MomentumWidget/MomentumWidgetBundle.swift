//
//  MomentumWidgetBundle.swift
//  MomentumWidget
//
//  Created by Mo Moosa on 01/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct MomentumWidgetBundle: WidgetBundle {
    var body: some Widget {
        MomentumWidget()
        MomentumWidgetControl()
        MomentumWidgetLiveActivity()
    }
}
