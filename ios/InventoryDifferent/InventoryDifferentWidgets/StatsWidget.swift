import WidgetKit
import SwiftUI

// MARK: - Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let data: WidgetStatsData?
}

// MARK: - Provider

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        Task {
            let data = await WidgetAPIService.shared.fetchStats()
            completion(StatsEntry(date: Date(), data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        Task {
            let data = await WidgetAPIService.shared.fetchStats()
            let entry = StatsEntry(date: Date(), data: data)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

// MARK: - Widget declaration

struct StatsWidget: Widget {
    let kind = "StatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            StatsWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "inventorydifferent://stats"))
        }
        .configurationDisplayName("Collection Stats")
        .description("Device count, value, and status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry view (routes by size)

struct StatsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StatsEntry

    var body: some View {
        switch family {
        case .systemSmall:  StatsSmallView(data: entry.data)
        case .systemMedium: StatsMediumView(data: entry.data)
        default:            StatsLargeView(data: entry.data)
        }
    }
}

// MARK: - Small

struct StatsSmallView: View {
    let data: WidgetStatsData?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("AppIconImage")
                .resizable()
                .frame(width: 26, height: 26)
                .cornerRadius(6)
            Spacer()
            if let data {
                Text("\(data.totalDevices)")
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundColor(.primary)
                Text("DEVICES")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
                Text("$\(Int(data.estimatedValue).formatted()) est.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "4d96ff"))
                    .padding(.top, 3)
            } else {
                StatsPlaceholderText()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground {
            Color("WidgetBackground")
        }
    }
}

// MARK: - Medium

struct StatsMediumView: View {
    let data: WidgetStatsData?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .cornerRadius(5)
                Text("INVENTORY DIFFERENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
            }
            if let data {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    StatsCell(value: "\(data.totalDevices)", label: "Devices")
                    StatsCell(value: "$\(Int(data.estimatedValue).formatted())", label: "Est. Value")
                    StatsCell(value: "\(Int(data.workingPercent))%", label: "Working", valueColor: Color(hex: "6bcb77"))
                    StatsCell(value: "\(data.forSaleCount)", label: "For Sale", valueColor: Color(hex: "ffd93d"))
                }
            } else {
                StatsPlaceholderText()
            }
        }
        .padding(14)
        .widgetBackground {
            Color("WidgetBackground")
        }
    }
}

// MARK: - Large

struct StatsLargeView: View {
    let data: WidgetStatsData?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .cornerRadius(5)
                Text("INVENTORY DIFFERENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
            }
            if let data {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatsCell(value: "\(data.totalDevices)", label: "Total Devices", fontSize: 24)
                    StatsCell(value: "$\(Int(data.estimatedValue).formatted())", label: "Est. Value", fontSize: 20)
                    StatsCell(value: "\(Int(data.workingPercent))%", label: "Working", valueColor: Color(hex: "6bcb77"), fontSize: 24)
                    StatsCell(value: "\(data.forSaleCount)", label: "For Sale", valueColor: Color(hex: "ffd93d"), fontSize: 24)
                    StatsCell(value: "$\(Int(data.netCash).formatted())", label: "Net Cash", valueColor: Color(hex: "4d96ff"), fontSize: 18)
                    StatsCell(value: "\(data.inRepairCount)", label: "In Repair", valueColor: Color(hex: "ff6b6b"), fontSize: 24)
                }
                Divider().padding(.vertical, 2)
                ForEach(statusBarsData(data.byStatus), id: \.label) { bar in
                    StatusBarRow(label: bar.label, fraction: bar.fraction, color: bar.color)
                }
            } else {
                StatsPlaceholderText()
            }
        }
        .padding(16)
        .widgetBackground {
            Color("WidgetBackground")
        }
    }

    private struct BarData { let label: String; let fraction: Double; let color: Color }

    private func statusBarsData(_ buckets: [WidgetStatsData.StatusBucket]) -> [BarData] {
        let total = max(1, buckets.reduce(0) { $0 + $1.count })
        let colorMap: [String: Color] = [
            "In Collection": Color(hex: "4d96ff"),
            "For Sale": Color(hex: "ffd93d"),
            "Sold": Color(hex: "6bcb77"),
            "In Repair": Color(hex: "ff6b6b"),
            "Pending Sale": Color(hex: "ffa07a"),
            "Donated": Color(hex: "888888"),
            "Returned": Color(hex: "888888"),
            "Repaired": Color(hex: "888888"),
            "Loaned": Color(hex: "a78bfa")
        ]
        return buckets
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
            .prefix(4)
            .map { BarData(label: $0.label,
                           fraction: Double($0.count) / Double(total),
                           color: colorMap[$0.label] ?? .gray) }
    }
}

// MARK: - Sub-views

struct StatsCell: View {
    let value: String
    let label: String
    var valueColor: Color = .primary
    var fontSize: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.07))
        .cornerRadius(10)
    }
}

struct StatusBarRow: View {
    let label: String
    let fraction: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
            Text("\(Int(fraction * 100))%")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct StatsPlaceholderText: View {
    var body: some View {
        Text("Open app to connect")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }
}
