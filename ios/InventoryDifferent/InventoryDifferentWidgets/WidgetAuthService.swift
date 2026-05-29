import Foundation

final class WidgetAuthService {
    static let shared = WidgetAuthService()

    private let suite = "group.com.wottle.inventorydifferent"

    var serverURL: String {
        UserDefaults(suiteName: suite)?.string(forKey: "serverURL") ?? ""
    }

    // The main app mirrors the current access token here after every login and refresh.
    func getAccessToken() -> String? {
        UserDefaults(suiteName: suite)?.string(forKey: "widget_access_token")
    }
}
