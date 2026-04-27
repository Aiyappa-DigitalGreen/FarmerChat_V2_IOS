//
//  AnalyticsManager.swift
//  FarmerChat
//
//  Single facade for analytics. No SDK events are sent on any screen while
//  AppSDKConfig.sdkEventsEnabled is false (default). All methods no-op until enabled.
//

import Foundation

enum AnalyticsManager {
    /// Call at app launch (e.g. from Splash). No-op; no SDK is initialised while sdkEventsEnabled is false.
    static func initializeSDKsIfEnabled() {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: MoEngage.initialize(), Plotline.init(), FirebaseApp.configure(), Adjust.activate()
    }

    /// Track screen view. Firebase, Adjust, Plotline only (not MoEngage). No-op until enabled.
    static func trackScreenView(screenName: String) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: Firebase trackScreenView, Adjust, Plotline (no MoEngage)
    }

    /// Track screen exit. Firebase, Adjust, Plotline only (not MoEngage). No-op until enabled.
    static func trackScreenExit(screenName: String) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: Firebase trackScreenExit, Adjust (SCREEN_EXITED token), Plotline
    }

    /// Track a screen view event (Screen_Viewed) with optional Adjust token. No-op until enabled.
    static func trackScreenViewed(screenName: String, adjustToken: String? = nil) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        var props: [String: Any] = [AnalyticsConstants.Property.screenName: screenName]
        if let t = adjustToken { props["adjustToken"] = t }
        // When enabled: trackEvent(AnalyticsConstants.Event.screenViewed, props); Adjust.trackEvent(token)
    }

    /// Track an event. No-op until enabled. adjustToken: optional Adjust event token from doc.
    static func trackEvent(name: String, properties: [String: Any]? = nil, adjustToken: String? = nil) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: forward to MoEngage, Firebase, Plotline; Adjust.trackEvent(adjustToken) if set
    }

    /// Legacy: track screen (alias). No-op until enabled.
    static func trackScreen(name: String, properties: [String: Any]? = nil) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
    }

    /// Set user identity (e.g. after login). No-op until enabled.
    static func identify(userId: String?, traits: [String: Any]? = nil) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: MoEngage.identify(), Firebase setUserId, Plotline.init/initAnonymousUser, Adjust
    }

    /// Reset identity (e.g. on logout). No-op until enabled.
    static func reset() {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: clear MoEngage, Firebase, etc.
    }
}

// MARK: - User attributes (MoEngage, Firebase user property, Plotline identify, Adjust global partner)
enum UserAttributeTracker {
    /// Set a user attribute. No-op until AppSDKConfig.sdkEventsEnabled. Exact keys from doc.
    static func track(attributeName: String, attributeValue: Any) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // When enabled: UserAttributeTracker.track() -> MoE setUserAttribute, Firebase setUserProperty, Plotline identify, Adjust addGlobalPartnerParameter
    }
}
