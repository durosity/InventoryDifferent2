import Foundation

final class WidgetAPIService {
    static let shared = WidgetAPIService()
    private let auth = WidgetAuthService.shared
    private let appGroupSuite = "group.com.wottle.inventorydifferent"

    // MARK: - Public fetch methods

    func fetchStats() async -> WidgetStatsData? {
        let query = """
        query WidgetStats {
          collectionStats {
            totalDevices workingPercent
            byStatus { label count }
          }
          financialOverview {
            estimatedValueOwned totalSpent
          }
        }
        """
        if let response: WidgetStatsAPIResponse = await execute(query: query) {
            let result = WidgetStatsData(from: response)
            cache(result, key: "widget_stats_cache")
            return result
        }
        return loadCache(key: "widget_stats_cache")
    }

    func fetchSpotlightPool() async -> [SpotlightDevice]? {
        let query = """
        query WidgetSpotlight {
          devices(where: { deleted: false }) {
            id name manufacturer releaseYear estimatedValue
            functionalStatus isFavorite cpu ram
            images(where: { isThumbnail: true }) { thumbnailPath }
            status
          }
        }
        """
        if let response: WidgetSpotlightAPIResponse = await execute(query: query) {
            // Filter to eligible statuses client-side (avoids enum_in syntax uncertainty)
            let eligible: Set<String> = ["COLLECTION", "FOR_SALE", "PENDING_SALE", "IN_REPAIR"]
            let filtered = response.devices.filter { eligible.contains($0.status ?? "") }
            let devices = filtered.map { SpotlightDevice(from: $0, serverURL: auth.serverURL) }
            cache(devices, key: "widget_spotlight_pool_cache")
            return devices
        }
        return loadCache(key: "widget_spotlight_pool_cache")
    }

    func fetchRecent() async -> WidgetRecentData? {
        let query = """
        query WidgetRecent {
          devices(orderBy: { dateAcquired: desc }, take: 5, where: { deleted: false }) {
            id name manufacturer releaseYear dateAcquired
            images(where: { isThumbnail: true }) { thumbnailPath }
          }
        }
        """
        if let response: WidgetRecentAPIResponse = await execute(query: query) {
            let result = WidgetRecentData(from: response, serverURL: auth.serverURL)
            cache(result, key: "widget_recent_cache")
            return result
        }
        return loadCache(key: "widget_recent_cache")
    }

    func fetchThumbnail(urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }

    // MARK: - Private

    private func execute<T: Decodable>(query: String) async -> T? {
        guard !auth.serverURL.isEmpty,
              let url = URL(string: "\(auth.serverURL)/graphql") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = auth.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode(WidgetGQLRequest(query: query))

        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }

        if (response as? HTTPURLResponse)?.statusCode == 401 {
            guard let newToken = await auth.refreshTokens() else { return nil }
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            guard let (retryData, _) = try? await URLSession.shared.data(for: request) else { return nil }
            return parseGQL(data: retryData)
        }

        return parseGQL(data: data)
    }

    private func parseGQL<T: Decodable>(data: Data) -> T? {
        guard let wrapper = try? JSONDecoder().decode(GQLWrapper<T>.self, from: data) else { return nil }
        return wrapper.data
    }

    private func cache<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults(suiteName: appGroupSuite)?.set(data, forKey: key)
    }

    private func loadCache<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults(suiteName: appGroupSuite)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private struct WidgetGQLRequest: Encodable {
    let query: String
}

private struct GQLWrapper<T: Decodable>: Decodable {
    let data: T?
}
