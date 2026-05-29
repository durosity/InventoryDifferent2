import Foundation

// MARK: - Stats

struct WidgetStatsData: Codable {
    let totalDevices: Int
    let estimatedValue: Double
    let workingPercent: Double
    let forSaleCount: Int
    let netCash: Double
    let inRepairCount: Int
    let byStatus: [StatusBucket]
    let lastUpdated: Date

    struct StatusBucket: Codable {
        let label: String
        let count: Int
    }
}

struct WidgetStatsAPIResponse: Decodable {
    let collectionStats: APICollectionStats
    let financialOverview: APIFinancialOverview

    struct APICollectionStats: Decodable {
        let totalDevices: Int
        let workingPercent: Double
        let byStatus: [StatsBucket]
        struct StatsBucket: Decodable { let label: String; let count: Int }
    }
    struct APIFinancialOverview: Decodable {
        let estimatedValueOwned: Double
        let netCash: Double
    }
}

extension WidgetStatsData {
    init(from response: WidgetStatsAPIResponse) {
        let stats = response.collectionStats
        let fin = response.financialOverview
        self.totalDevices = stats.totalDevices
        self.estimatedValue = fin.estimatedValueOwned
        self.workingPercent = stats.workingPercent
        self.forSaleCount = stats.byStatus.first(where: { $0.label == "For Sale" })?.count ?? 0
        self.netCash = fin.netCash
        self.inRepairCount = stats.byStatus.first(where: { $0.label == "In Repair" })?.count ?? 0
        self.byStatus = stats.byStatus.map { StatusBucket(label: $0.label, count: $0.count) }
        self.lastUpdated = Date()
    }
}

// MARK: - Spotlight

struct SpotlightDevice: Codable {
    let id: Int
    let name: String
    let additionalName: String?
    let manufacturer: String?
    let releaseYear: Int?
    let estimatedValue: Double?
    let functionalStatus: String?
    let isFavorite: Bool
    let cpu: String?
    let ram: String?
    let thumbnailURL: String?
}

struct WidgetSpotlightAPIResponse: Decodable {
    let devices: [APIDevice]

    struct APIDevice: Decodable {
        let id: Int
        let name: String
        let additionalName: String?
        let manufacturer: String?
        let releaseYear: Int?
        let estimatedValue: Double?
        let functionalStatus: String?
        let isFavorite: Bool
        let cpu: String?
        let ram: String?
        let status: String?
        let images: [APIImage]?
        struct APIImage: Decodable { let thumbnailPath: String?; let isThumbnail: Bool? }
    }
}

extension SpotlightDevice {
    init(from device: WidgetSpotlightAPIResponse.APIDevice, serverURL: String) {
        self.id = device.id
        self.name = device.name
        self.additionalName = device.additionalName
        self.manufacturer = device.manufacturer
        self.releaseYear = device.releaseYear
        self.estimatedValue = device.estimatedValue
        self.functionalStatus = device.functionalStatus
        self.isFavorite = device.isFavorite
        self.cpu = device.cpu
        self.ram = device.ram
        let images = device.images ?? []
        let preferred = images.first(where: { $0.isThumbnail == true && $0.thumbnailPath != nil })
                     ?? images.first(where: { $0.thumbnailPath != nil })
        self.thumbnailURL = preferred?.thumbnailPath.map { "\(serverURL)\($0)" }
    }
}

// MARK: - Recent

struct RecentDevice: Codable {
    let id: Int
    let name: String
    let manufacturer: String?
    let releaseYear: Int?
    let dateAcquired: Date?
    let thumbnailURL: String?
}

struct WidgetRecentData: Codable {
    let devices: [RecentDevice]
    let lastUpdated: Date
}

struct WidgetRecentAPIResponse: Decodable {
    let devices: [APIRecentDevice]

    struct APIRecentDevice: Decodable {
        let id: Int
        let name: String
        let manufacturer: String?
        let releaseYear: Int?
        let dateAcquired: String?
        let images: [APIImage]?
        struct APIImage: Decodable { let thumbnailPath: String? }
    }
}

extension WidgetRecentData {
    init(from response: WidgetRecentAPIResponse, serverURL: String) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let mapped = response.devices.map { d -> RecentDevice in
            let acquired = d.dateAcquired.flatMap { iso.date(from: $0) }
            return RecentDevice(
                id: d.id,
                name: d.name,
                manufacturer: d.manufacturer,
                releaseYear: d.releaseYear,
                dateAcquired: acquired,
                thumbnailURL: d.images?.first(where: { $0.thumbnailPath != nil })?.thumbnailPath
                    .map { "\(serverURL)\($0)" }
            )
        }
        self.devices = mapped
            .sorted { ($0.dateAcquired ?? .distantPast) > ($1.dateAcquired ?? .distantPast) }
            .prefix(5)
            .map { $0 }
        self.lastUpdated = Date()
    }
}
