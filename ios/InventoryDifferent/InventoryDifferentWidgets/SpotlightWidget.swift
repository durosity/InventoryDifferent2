import WidgetKit
import SwiftUI

// MARK: - Entry

struct SpotlightEntry: TimelineEntry {
    let date: Date
    let device: SpotlightDevice?
    let thumbnailData: Data?
}

// MARK: - Provider

struct SpotlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpotlightEntry {
        SpotlightEntry(date: Date(), device: nil, thumbnailData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpotlightEntry) -> Void) {
        Task {
            let pool = await WidgetAPIService.shared.fetchSpotlightPool() ?? []
            let device = Self.pickDevice(from: pool, for: Date())
            let thumb = await fetchThumb(device)
            completion(SpotlightEntry(date: Date(), device: device, thumbnailData: thumb))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpotlightEntry>) -> Void) {
        Task {
            let pool = await WidgetAPIService.shared.fetchSpotlightPool() ?? []
            let today = Calendar.current.startOfDay(for: Date())

            var entries: [SpotlightEntry] = []
            for offset in 0..<7 {
                let date = Calendar.current.date(byAdding: .day, value: offset, to: today)!
                let device = Self.pickDevice(from: pool, for: date)
                let thumb = offset == 0 ? await fetchThumb(device) : nil
                entries.append(SpotlightEntry(date: date, device: device, thumbnailData: thumb))
            }

            let refresh = Calendar.current.date(byAdding: .day, value: 7, to: today)!
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }

    private func fetchThumb(_ device: SpotlightDevice?) async -> Data? {
        guard let url = device?.thumbnailURL else { return nil }
        return await WidgetAPIService.shared.fetchThumbnail(urlString: url)
    }

    /// Deterministic weighted random selection — `internal` so tests can call it directly.
    internal static func pickDevice(from devices: [SpotlightDevice], for date: Date) -> SpotlightDevice? {
        guard !devices.isEmpty else { return nil }
        var pool: [SpotlightDevice] = []
        for d in devices {
            pool.append(d)
            if d.isFavorite { pool.append(d); pool.append(d) }
        }
        let dayOrdinal = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 1
        return pool[dayOrdinal % pool.count]
    }
}

// MARK: - Widget declaration

struct SpotlightWidget: Widget {
    let kind = "SpotlightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpotlightProvider()) { entry in
            SpotlightEntryView(entry: entry)
                .widgetURL(entry.device.map { URL(string: "inventorydifferent://devices/\($0.id)") } ?? nil)
        }
        .configurationDisplayName("Device Spotlight")
        .description("A daily highlight from your collection.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry view (routes by size)

struct SpotlightEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SpotlightEntry

    var body: some View {
        switch family {
        case .systemSmall:  SpotlightSmallView(entry: entry)
        case .systemMedium: SpotlightMediumView(entry: entry)
        default:            SpotlightLargeView(entry: entry)
        }
    }
}

// MARK: - Small

struct SpotlightSmallView: View {
    let entry: SpotlightEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [.clear, Color.black.opacity(0.9)],
                           startPoint: .center, endPoint: .bottom)
            if let device = entry.device {
                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    Text(device.name)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white)
                        .tracking(0.5)
                        .lineLimit(2)
                    if let year = device.releaseYear {
                        Text(String(year))
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                            .textCase(.uppercase)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            } else {
                SpotlightPlaceholder()
            }
        }
        .widgetBackground {
            SpotlightBackground(thumbnailData: entry.thumbnailData)
        }
    }
}

// MARK: - Medium

struct SpotlightMediumView: View {
    let entry: SpotlightEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [.clear, Color.black.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
            if let device = entry.device {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text("TODAY'S HIGHLIGHT")
                        .font(.system(size: 8, weight: .light))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(3.5)
                    Text(device.name)
                        .font(.system(size: 19, weight: .light))
                        .foregroundColor(.white)
                        .tracking(0.6)
                        .lineLimit(1)
                    Text(metaLine(device).uppercased())
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.8)
                    if let value = device.estimatedValue {
                        Text("$\(Int(value).formatted())")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "6bcb77").opacity(0.85))
                            .tracking(0.8)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            } else {
                SpotlightPlaceholder()
            }
        }
        .widgetBackground {
            SpotlightBackground(thumbnailData: entry.thumbnailData)
        }
    }

    private func metaLine(_ device: SpotlightDevice) -> String {
        [device.manufacturer, device.releaseYear.map(String.init), device.cpu]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

// MARK: - Large

struct SpotlightLargeView: View {
    let entry: SpotlightEntry

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [.clear, Color.black.opacity(0.3)],
                               startPoint: .center, endPoint: .bottom)
                VStack {
                    HStack {
                        Text("TODAY'S HIGHLIGHT")
                            .font(.system(size: 8, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(3.0)
                            .padding(12)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                if let device = entry.device {
                    Text(device.name)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.white)
                        .tracking(0.6)
                    Text([device.manufacturer, device.releaseYear.map(String.init)]
                            .compactMap { $0 }.joined(separator: " · ").uppercased())
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(1.8)
                    if device.cpu != nil || device.ram != nil {
                        HStack(spacing: 6) {
                            if let cpu = device.cpu { SpecChip(text: cpu) }
                            if let ram = device.ram { SpecChip(text: ram) }
                            if device.functionalStatus == "YES" { SpecChip(text: "Working", isGreen: true) }
                        }
                        .padding(.top, 2)
                    }
                    if let value = device.estimatedValue {
                        Text("$\(Int(value).formatted())")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "6bcb77").opacity(0.85))
                            .tracking(0.8)
                            .padding(.top, 4)
                    }
                } else {
                    SpotlightPlaceholder()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("WidgetBackground"))
        }
        .widgetBackground {
            SpotlightBackground(thumbnailData: entry.thumbnailData)
        }
    }
}

// MARK: - Shared sub-views

struct SpotlightBackground: View {
    let thumbnailData: Data?

    var body: some View {
        if let data = thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(colors: [Color(hex: "2d2d1a"), Color(hex: "1a1a1a"), Color(hex: "0d0d0d")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct SpecChip: View {
    let text: String
    var isGreen = false

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(isGreen ? Color(hex: "6bcb77") : Color.white.opacity(0.7))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isGreen ? Color(hex: "6bcb77").opacity(0.15) : Color.white.opacity(0.08))
            )
    }
}

struct SpotlightPlaceholder: View {
    var body: some View {
        Text("Open app to connect")
            .font(.system(size: 11, weight: .light))
            .foregroundColor(.white.opacity(0.35))
            .padding(12)
    }
}
