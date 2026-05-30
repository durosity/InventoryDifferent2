//
//  InventoryDifferentWidgetsBundle.swift
//  InventoryDifferentWidgets
//
//  Created by Michael Wottle on 5/29/26.
//

import WidgetKit
import SwiftUI

@main
struct InventoryDifferentWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        SpotlightWidget()
        RecentWidget()
    }
}
