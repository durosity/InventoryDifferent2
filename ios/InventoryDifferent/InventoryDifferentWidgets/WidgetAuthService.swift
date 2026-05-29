import Foundation
import Security

final class WidgetAuthService {
    static let shared = WidgetAuthService()

    private let appGroupSuite = "group.com.wottle.inventorydifferent"
    private let keychainAccessGroup = "group.com.wottle.InventoryDifferent"
    private let accessTokenKey = "inv_access_token"
    private let refreshTokenKey = "inv_refresh_token"

    var serverURL: String {
        UserDefaults(suiteName: appGroupSuite)?.string(forKey: "serverURL") ?? ""
    }

    func getAccessToken() -> String? {
        getKeychainString(key: accessTokenKey)
    }

    /// Attempts a token refresh using the stored refresh token. Returns new access token on success.
    func refreshTokens() async -> String? {
        guard !serverURL.isEmpty,
              let refreshToken = getKeychainString(key: refreshTokenKey),
              let url = URL(string: "\(serverURL)/auth/refresh") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["refreshToken": refreshToken])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = try? JSONDecoder().decode(RefreshResponse.self, from: data) else {
            return nil
        }

        setKeychainString(key: accessTokenKey, value: parsed.accessToken)
        return parsed.accessToken
    }

    // MARK: - Keychain helpers (shared access group)

    private func getKeychainString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: keychainAccessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func setKeychainString(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: keychainAccessGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String
    }
}
