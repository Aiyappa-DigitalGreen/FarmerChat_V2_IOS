//
//  AppConfig.swift
//  FarmerChat
//
//  Runtime config from API_KEYS_AND_CONFIG.md. Values from Info.plist or Config.plist (do not commit secrets).
//

import Foundation

enum AppConfig {
    /// Backend API key for guest auth and unauthenticated calls (Android: GUEST_USER_API_KEY).
    /// Set in Info.plist as "GUEST_USER_API_KEY" or in Config.plist. Do not commit.
    static var guestUserApiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "GUEST_USER_API_KEY") as? String
            ?? loadFromConfigPlist("GUEST_USER_API_KEY")
    }

    /// Google Geocoding/Places API key (Android: GEO_API_KEY). Optional until geo features are added.
    static var geoApiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "GEO_API_KEY") as? String
            ?? loadFromConfigPlist("GEO_API_KEY")
    }

    /// Auth refresh path. Default from ApiConstants; override if backend uses a different path.
    static var authRefreshPath: String {
        (Bundle.main.object(forInfoDictionaryKey: "AUTH_REFRESH_PATH") as? String)
            ?? loadFromConfigPlist("AUTH_REFRESH_PATH")
            ?? ApiConstants.authRefresh
    }

    /// MoEngage App ID (Android: MOENGAGE_APP_ID). Used when AppSDKConfig.enableMoEngage is true.
    static var moEngageAppId: String? {
        Bundle.main.object(forInfoDictionaryKey: "MOENGAGE_APP_ID") as? String
            ?? loadFromConfigPlist("MOENGAGE_APP_ID")
    }

    /// Adjust App Token (Android: ADJUST_APP_TOKEN). Used when AppSDKConfig.enableAdjust is true.
    static var adjustAppToken: String? {
        Bundle.main.object(forInfoDictionaryKey: "ADJUST_APP_TOKEN") as? String
            ?? loadFromConfigPlist("ADJUST_APP_TOKEN")
    }

    /// Plotline API key — dev or prod based on build (Android: PLOTLINE_API_KEY_DEV / PLOTLINE_API_KEY_PROD).
    static var plotlineApiKey: String? {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: "PLOTLINE_API_KEY_DEV") as? String
            ?? loadFromConfigPlist("PLOTLINE_API_KEY_DEV")
        #else
        return Bundle.main.object(forInfoDictionaryKey: "PLOTLINE_API_KEY_PROD") as? String
            ?? loadFromConfigPlist("PLOTLINE_API_KEY_PROD")
        #endif
    }

    private static func loadFromConfigPlist(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let dict = (try? NSDictionary(contentsOf: url)) as? [String: Any] else {
            return nil
        }
        return dict[key] as? String
    }
}
