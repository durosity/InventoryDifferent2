//
//  InventoryDifferentWidgetsLiveActivity.swift
//  InventoryDifferentWidgets
//
//  Created by Michael Wottle on 5/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct InventoryDifferentWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct InventoryDifferentWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InventoryDifferentWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension InventoryDifferentWidgetsAttributes {
    fileprivate static var preview: InventoryDifferentWidgetsAttributes {
        InventoryDifferentWidgetsAttributes(name: "World")
    }
}

extension InventoryDifferentWidgetsAttributes.ContentState {
    fileprivate static var smiley: InventoryDifferentWidgetsAttributes.ContentState {
        InventoryDifferentWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: InventoryDifferentWidgetsAttributes.ContentState {
         InventoryDifferentWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: InventoryDifferentWidgetsAttributes.preview) {
   InventoryDifferentWidgetsLiveActivity()
} contentStates: {
    InventoryDifferentWidgetsAttributes.ContentState.smiley
    InventoryDifferentWidgetsAttributes.ContentState.starEyes
}
