//
//  FeatureFlags.swift
//  FarmerChat
//
//  Per-flavor feature flags. Android reads these from Firebase Remote Config;
//  on iOS they come from Info.plist (xcconfig-driven per flavor) with a
//  Config.plist fallback. All flags default to `true` if missing so a
//  misconfigured build fails open (feature enabled) rather than silently
//  broken.
//

import Foundation

struct FeatureFlags {
    let showNameScreenOnboarding: Bool
    let enableAuthInterstitial: Bool
    let chatFeedbackEnabled: Bool
    let hideReadFullAdviceForCampaign: Bool
    let v2WobbleAnimationEnabled: Bool
    let stopAnimationOnFirstCardClick: Bool

    static let shared: FeatureFlags = .loadFromBundle()

    private static func loadFromBundle() -> FeatureFlags {
        let plist = loadConfigPlist()
        return FeatureFlags(
            showNameScreenOnboarding: readBool("v2_show_name_screen_onboarding", plist: plist),
            enableAuthInterstitial: readBool("enable_auth_interstitial", plist: plist),
            chatFeedbackEnabled: readBool("chat_feedback_enabled", plist: plist),
            hideReadFullAdviceForCampaign: readBool("hide_read_full_advice_for_campaign", plist: plist),
            v2WobbleAnimationEnabled: readBool("v2_wobble_animation_enabled", plist: plist),
            stopAnimationOnFirstCardClick: readBool("STOP_ANIMATION_ON_FIRST_CARD_CLICK", plist: plist)
        )
    }

    private static func readBool(_ key: String, plist: [String: Any]?) -> Bool {
        if let raw = Bundle.main.object(forInfoDictionaryKey: key), let v = coerceBool(raw) { return v }
        if let raw = plist?[key], let v = coerceBool(raw) { return v }
        return true
    }

    /// xcconfig values flow through Info.plist as strings ("YES", "true", "1").
    /// Native Config.plist entries are typically `<true/>` (Bool) or `<integer>1</integer>`.
    private static func coerceBool(_ raw: Any) -> Bool? {
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String {
            switch s.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private static func loadConfigPlist() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let dict = (try? NSDictionary(contentsOf: url)) as? [String: Any] else {
            return nil
        }
        return dict
    }
}
