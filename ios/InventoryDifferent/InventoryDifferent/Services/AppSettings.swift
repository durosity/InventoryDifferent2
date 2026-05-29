//
//  AppSettings.swift
//  InventoryDifferent
//
//  Created by Michael Wottle on 2/2/26.
//

import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let appGroupSuite = "group.com.wottle.inventorydifferent"

    private let serverURLKey = "serverURL"
    private let isConfiguredKey = "isConfigured"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppSettings.appGroupSuite) ?? .standard
    }

    @Published var serverURL: String
    @Published var isConfigured: Bool

    init() {
        let suite = UserDefaults(suiteName: AppSettings.appGroupSuite) ?? .standard
        // Migrate any value already in UserDefaults.standard on first run
        if let existing = UserDefaults.standard.string(forKey: "serverURL"),
           suite.string(forKey: "serverURL") == nil {
            suite.set(existing, forKey: "serverURL")
            suite.set(UserDefaults.standard.bool(forKey: "isConfigured"), forKey: "isConfigured")
        }
        self.serverURL = suite.string(forKey: "serverURL") ?? ""
        self.isConfigured = suite.bool(forKey: "isConfigured")
    }

    func configure(serverURL: String) {
        self.serverURL = serverURL
        self.isConfigured = true
        defaults.set(serverURL, forKey: serverURLKey)
        defaults.set(true, forKey: isConfiguredKey)
        APIService.shared.updateBaseURL(serverURL)
    }

    func logout() {
        self.isConfigured = false
        defaults.set(false, forKey: isConfiguredKey)
    }
}
