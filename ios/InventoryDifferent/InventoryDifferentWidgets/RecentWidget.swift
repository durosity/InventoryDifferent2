import WidgetKit
import SwiftUI

// MARK: - Entry

struct RecentEntry: TimelineEntry {
    let date: Date
    let data: WidgetRecentData?
    let thumbnails: [Data?]  // parallel to data.devices, pre-fetched at timeline generation
}

// MARK: - Provider

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date(), data: nil, thumbnails: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        Task {
            let data = await WidgetAPIService.shared.fetchRecent()
            let thumbs = await Self.fetchThumbnails(for: data)
            completion(RecentEntry(date: Date(), data: data, thumbnails: thumbs))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        Task {
            let data = await WidgetAPIService.shared.fetchRecent()
            let thumbs = await Self.fetchThumbnails(for: data)
            let entry = RecentEntry(date: Date(), data: data, thumbnails: thumbs)
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private static func fetchThumbnails(for data: WidgetRecentData?) async -> [Data?] {
        guard let devices = data?.devices else { return [] }
        let count = min(devices.count, 3)
        return await withTaskGroup(of: (Int, Data?).self, returning: [Data?].self) { group in
            for i in 0..<count {
                let url = devices[i].thumbnailURL
                group.addTask {
                    guard let url else { return (i, nil) }
                    return (i, await WidgetAPIService.shared.fetchThumbnail(urlString: url))
                }
            }
            var result = [Data?](repeating: nil, count: count)
            for await (i, data) in group { result[i] = data }
            return result
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT ADDITIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                Spacer()
                RainbowDot(size: 11)
            }
            .padding(.bottom, 10)

            if let data = entry.data, !data.devices.isEmpty {
                VStack(spacing: 7) {
                    ForEach(Array(data.devices.prefix(3).enumerated()), id: \.element.id) { index, device in
                        Link(destination: URL(string: "inventorydifferent://devices/\(device.id)")!) {
                            RecentRow(device: device, thumbnailData: index < entry.thumbnails.count ? entry.thumbnails[index] : nil)
                        }
                    }
                }
                if let ts = entry.data?.lastUpdated {
                    Text("Updated \(ts.widgetRelativeDescription)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                }
            } else {
                Text("Open app to connect")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground {
            Color("WidgetBackground")
        }
    }
}

struct RecentRow: View {
    let device: RecentDevice
    var thumbnailData: Data? = nil

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let data = thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text("💾").font(.system(size: 16))
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.08)))

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text([device.manufacturer, device.releaseYear.map(String.init)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
