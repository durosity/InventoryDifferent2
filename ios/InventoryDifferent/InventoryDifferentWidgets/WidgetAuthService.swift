import Foundation

final class WidgetAuthService {
    static let shared = WidgetAuthService()
    private let suite = "group.com.wottle.inventorydifferent"

    var serverURL: String {
        UserDefaults(suiteName: suite)?.string(forKey: "serverURL") ?? ""
    }

    func getAccessToken() -> String? {
        UserDefaults(suiteName: suite)?.string(forKey: "widget_access_token")
    }

    /// Calls /auth/refresh using the mirrored refresh token. Stores and returns the new
    /// access token on success, or nil if the refresh token is missing or invalid.
    func refreshTokens() async -> String? {
        let defaults = UserDefaults(suiteName: suite)
        guard !serverURL.isEmpty,
              let refreshToken = defaults?.string(forKey: "widget_refresh_token"),
              !refreshToken.isEmpty,
              let url = URL(string: "\(serverURL)/auth/refresh") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["accessToken"] as? String else { return nil }

        defaults?.set(accessToken, forKey: "widget_access_token")
        if let newRefresh = json["refreshToken"] as? String {
            defaults?.set(newRefresh, forKey: "widget_refresh_token")
        }
        return accessToken
    }
}
