import WidgetKit
import SwiftUI

// MARK: - Entry

struct RecentEntry: TimelineEntry {
    let date: Date
    let data: WidgetRecentData?
}

// MARK: - Provider

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        Task {
            let data = await WidgetAPIService.shared.fetchRecent()
            completion(RecentEntry(date: Date(), data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        Task {
            let data = await WidgetAPIService.shared.fetchRecent()
            let entry = RecentEntry(date: Date(), data: data)
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Widget declaration

struct RecentWidget: Widget {
    let kind = "RecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentProvider()) { entry in
            RecentWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Additions")
        .description("Your latest acquisitions.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

struct RecentWidgetView: View {
    let entry: RecentEntry

    var body: some View {
        ZStack {
            Color(hex: "1c1c1e")
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("RECENT ADDITIONS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.0)
                    Spacer()
                    RainbowDot(size: 11)
                }
                .padding(.bottom, 10)

                if let data = entry.data, !data.devices.isEmpty {
                    VStack(spacing: 7) {
                        ForEach(Array(data.devices.prefix(3))) { device in
                            Link(destination: URL(string: "inventorydifferent://devices/\(device.id)")!) {
                                RecentRow(device: device)
                            }
                        }
                    }
                    if let ts = entry.data?.lastUpdated {
                        Text("Updated \(ts.widgetRelativeDescription)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.top, 6)
                    }
                } else {
                    Text("Open app to connect")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct RecentRow: View {
    let device: RecentDevice

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [Color(hex: "2a2a3e"), Color(hex: "1a1a2e")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
                .overlay(Text("💾").font(.system(size: 16)))

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text([device.manufacturer, device.releaseYear.map(String.init)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            if let acquired = device.dateAcquired {
                Text(acquired.widgetShortRelative)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "4d96ff"))
            }
        }
    }
}

// MARK: - Date helpers

extension Date {
    var widgetRelativeDescription: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 3600 { return "\(max(1, seconds / 60))m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    var widgetShortRelative: String {
        let days = Int(Date().timeIntervalSince(self) / 86400)
        if days == 0 { return "today" }
        if days == 1 { return "1d" }
        if days < 7 { return "\(days)d" }
        return "\(days / 7)w"
    }
}

extension RecentDevice: Identifiable {}
