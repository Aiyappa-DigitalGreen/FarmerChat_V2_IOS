//
//  PreferencesManager.swift
//  FarmerChat
//
//  UserDefaults wrapper — mirrors Android PreferenceHelperManager.
//

import Combine
import Foundation
import SwiftUI

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - User & Auth
    var userId: String? {
        get { defaults.string(forKey: PreferenceKeys.prefUserId) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.prefUserId)
            objectWillChange.send()
        }
    }

    var accessToken: String? {
        get { defaults.string(forKey: PreferenceKeys.appAccessToken) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.appAccessToken)
            objectWillChange.send()
        }
    }

    var refreshToken: String? {
        get { defaults.string(forKey: PreferenceKeys.appRefreshToken) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.appRefreshToken)
            objectWillChange.send()
        }
    }

    var isOtpVerified: Bool {
        get { defaults.bool(forKey: PreferenceKeys.otpVerified) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.otpVerified)
            objectWillChange.send()
        }
    }

    var userRole: String? {
        get { defaults.string(forKey: PreferenceKeys.userRole) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.userRole)
            objectWillChange.send()
        }
    }

    var userPhoneCountryCode: String? {
        get { defaults.string(forKey: PreferenceKeys.userPhoneCountryCode) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.userPhoneCountryCode)
            objectWillChange.send()
        }
    }

    var phoneNumberLogin: String? {
        get { defaults.string(forKey: PreferenceKeys.phoneNumberLogin) }
        set { defaults.set(newValue, forKey: PreferenceKeys.phoneNumberLogin) }
    }

    var isLoggedIn: Bool {
        accessToken != nil && !(accessToken?.isEmpty ?? true)
    }

    // MARK: - Onboarding
    var selectedLanguageId: String? {
        get { defaults.string(forKey: PreferenceKeys.selectedLanguageId) }
        set { defaults.set(newValue, forKey: PreferenceKeys.selectedLanguageId) }
    }

    /// Language code used for localized APIs (e.g., "en", "sw").
    var selectedLanguageCode: String? {
        get { defaults.string(forKey: PreferenceKeys.selectedLanguageCode) }
        set { defaults.set(newValue, forKey: PreferenceKeys.selectedLanguageCode) }
    }

    var selectedLanguageDisplayName: String? {
        get { defaults.string(forKey: PreferenceKeys.selectedLanguageDisplayName) }
        set { defaults.set(newValue, forKey: PreferenceKeys.selectedLanguageDisplayName) }
    }

    var userName: String? {
        get { defaults.string(forKey: PreferenceKeys.userName) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.userName)
            objectWillChange.send()
        }
    }

    /// True when name has been set; cleared on logout.
    var userNameAdded: Bool {
        get { defaults.bool(forKey: PreferenceKeys.userNameAdded) }
        set { defaults.set(newValue, forKey: PreferenceKeys.userNameAdded) }
    }

    /// Has user seen name screen once; set when navigating to Name.
    var nameScreenSeenOnce: Bool {
        get { defaults.bool(forKey: PreferenceKeys.nameScreenSeenOnce) }
        set { defaults.set(newValue, forKey: PreferenceKeys.nameScreenSeenOnce) }
    }

    var firstTimeOnboardingCompleted: Bool {
        get { defaults.object(forKey: PreferenceKeys.firstTimeOnboardingCompleted) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PreferenceKeys.firstTimeOnboardingCompleted) }
    }

    var onboardingLanguageDone: Bool {
        get { defaults.bool(forKey: PreferenceKeys.onboardingLanguageDone) }
        set { defaults.set(newValue, forKey: PreferenceKeys.onboardingLanguageDone) }
    }

    var onboardingNameDone: Bool {
        get { defaults.bool(forKey: PreferenceKeys.onboardingNameDone) }
        set { defaults.set(newValue, forKey: PreferenceKeys.onboardingNameDone) }
    }

    // MARK: - Appearance & UX
    var appearanceModeRaw: String {
        get { defaults.string(forKey: PreferenceKeys.appearanceMode) ?? AppearanceMode.auto.rawValue }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.appearanceMode)
            objectWillChange.send()
        }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .auto }
        set { appearanceModeRaw = newValue.rawValue }
    }

    var gpsPermissionAsked: Bool {
        get { defaults.bool(forKey: PreferenceKeys.gpsPermissionAsked) }
        set { defaults.set(newValue, forKey: PreferenceKeys.gpsPermissionAsked) }
    }

    /// Backward-compat for theme; synced with APPEARANCE_MODE; preserved on logout.
    var darkThemeEnabled: Bool {
        get { defaults.bool(forKey: PreferenceKeys.darkThemeEnabled) }
        set { defaults.set(newValue, forKey: PreferenceKeys.darkThemeEnabled) }
    }

    // MARK: - Language labels (stored as JSON)
    var languageLabels: [String: String] {
        get {
            guard let data = defaults.data(forKey: PreferenceKeys.languageLabelsJson),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: PreferenceKeys.languageLabelsJson)
            }
        }
    }

    var languageLabelsLoaded: Bool {
        get { defaults.bool(forKey: PreferenceKeys.languageLabelsLoaded) }
        set { defaults.set(newValue, forKey: PreferenceKeys.languageLabelsLoaded) }
    }

    func label(_ key: String, fallback: String) -> String {
        let v = languageLabels[key] ?? ""
        return v.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : v
    }

    // MARK: - Device
    var deviceId: String? {
        get { defaults.string(forKey: PreferenceKeys.deviceId) }
        set {
            defaults.set(newValue, forKey: PreferenceKeys.deviceId)
            objectWillChange.send()
        }
    }

    /// Returns the persisted device ID, creating and saving a new one on first call.
    /// All callers must use this instead of generating UUID inline.
    var resolvedDeviceId: String {
        if let existing = deviceId, !existing.isEmpty { return existing }
        let newId = UUID().uuidString
        deviceId = newId
        return newId
    }

    // MARK: - Location cache
    var lastKnownLat: Double? {
        get { defaults.object(forKey: PreferenceKeys.lastKnownLat) as? Double }
        set { defaults.set(newValue, forKey: PreferenceKeys.lastKnownLat) }
    }

    var lastKnownLng: Double? {
        get { defaults.object(forKey: PreferenceKeys.lastKnownLng) as? Double }
        set { defaults.set(newValue, forKey: PreferenceKeys.lastKnownLng) }
    }

    var locationUpdatedAt: Date? {
        get { defaults.object(forKey: PreferenceKeys.locationUpdatedAt) as? Date }
        set { defaults.set(newValue, forKey: PreferenceKeys.locationUpdatedAt) }
    }

    /// Location permission deny count; incremented on each deny, never reset. Recovery when >= 2.
    var locationPermissionDenyCount: Int {
        get { defaults.integer(forKey: PreferenceKeys.locationPermissionDenyCount) }
        set { defaults.set(newValue, forKey: PreferenceKeys.locationPermissionDenyCount) }
    }

    /// True when valid lat/lng are stored (location saved after flow or update_user_location success).
    var isLocationEnabledOnce: Bool {
        guard let lat = lastKnownLat, let lng = lastKnownLng else { return false }
        return lat != 0 || lng != 0
    }

    var gpsPermissionShouldAsk: Bool {
        get { defaults.bool(forKey: PreferenceKeys.gpsPermissionShouldAsk) }
        set { defaults.set(newValue, forKey: PreferenceKeys.gpsPermissionShouldAsk) }
    }

    var locationUpgradedToGps: Bool {
        get { defaults.bool(forKey: PreferenceKeys.locationUpgradedToGps) }
        set { defaults.set(newValue, forKey: PreferenceKeys.locationUpgradedToGps) }
    }

    // MARK: - Country (for guest vs logged-in flows)
    var userCountryCode: String? {
        get { defaults.string(forKey: PreferenceKeys.userCountryCode) }
        set { defaults.set(newValue, forKey: PreferenceKeys.userCountryCode) }
    }

    var userCountryName: String? {
        get { defaults.string(forKey: PreferenceKeys.userCountryName) }
        set { defaults.set(newValue, forKey: PreferenceKeys.userCountryName) }
    }

    var userSelectedStateCode: String? {
        get { defaults.string(forKey: PreferenceKeys.userSelectedStateCode) }
        set { defaults.set(newValue, forKey: PreferenceKeys.userSelectedStateCode) }
    }

    /// Conversation id from new_conversation; used for get_answer_for_text_query and image_analysis (per QUERY_FLOW_AND_APIS.md).
    var newConversationId: String? {
        get { defaults.string(forKey: PreferenceKeys.newConversationId) }
        set { defaults.set(newValue, forKey: PreferenceKeys.newConversationId) }
    }

    var cachedHomeFeedResponse: String? {
        get { defaults.string(forKey: PreferenceKeys.cachedHomeFeedResponse) }
        set { defaults.set(newValue, forKey: PreferenceKeys.cachedHomeFeedResponse) }
    }

    // MARK: - Permission counts (camera / microphone; reset on grant)
    var cameraPermissionDenyCount: Int {
        get { defaults.integer(forKey: PreferenceKeys.cameraPermissionDenyCount) }
        set { defaults.set(newValue, forKey: PreferenceKeys.cameraPermissionDenyCount) }
    }

    var cameraPermissionAttemptCount: Int {
        get { defaults.integer(forKey: PreferenceKeys.cameraPermissionAttemptCount) }
        set { defaults.set(newValue, forKey: PreferenceKeys.cameraPermissionAttemptCount) }
    }

    var microphonePermissionDenyCount: Int {
        get { defaults.integer(forKey: PreferenceKeys.microphonePermissionDenyCount) }
        set { defaults.set(newValue, forKey: PreferenceKeys.microphonePermissionDenyCount) }
    }

    var microphonePermissionAttemptCount: Int {
        get { defaults.integer(forKey: PreferenceKeys.microphonePermissionAttemptCount) }
        set { defaults.set(newValue, forKey: PreferenceKeys.microphonePermissionAttemptCount) }
    }

    // MARK: - Feature flags (ASR / TTS)
    var asrEnabled: Bool {
        get { defaults.object(forKey: PreferenceKeys.asrEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PreferenceKeys.asrEnabled) }
    }

    var ttsEnabled: Bool {
        get { defaults.object(forKey: PreferenceKeys.ttsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: PreferenceKeys.ttsEnabled) }
    }

    var buildVersionApiCalled: Bool {
        get { defaults.bool(forKey: PreferenceKeys.buildVersionApiCalled) }
        set { defaults.set(newValue, forKey: PreferenceKeys.buildVersionApiCalled) }
    }

    // MARK: - Location campaign gating (LOCATION_SCREEN.md §9.7)
    /// Millis since 1970 for last shown time of a campaign overlay.
    func locLastShownAt(campaignId: String) -> Int64 {
        guard !campaignId.isEmpty else { return 0 }
        return defaults.object(forKey: PreferenceKeys.locLastShownAtPrefix + campaignId) as? Int64 ?? 0
    }

    func setLocLastShownAt(campaignId: String, millis: Int64) {
        guard !campaignId.isEmpty else { return }
        defaults.set(millis, forKey: PreferenceKeys.locLastShownAtPrefix + campaignId)
    }

    func locShownCount(campaignId: String) -> Int {
        guard !campaignId.isEmpty else { return 0 }
        return defaults.integer(forKey: PreferenceKeys.locShownCountPrefix + campaignId)
    }

    func incrementLocShownCount(campaignId: String) {
        guard !campaignId.isEmpty else { return }
        let key = PreferenceKeys.locShownCountPrefix + campaignId
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    var plantixLatitude: Double? {
        get { defaults.object(forKey: PreferenceKeys.plantixLatitude) as? Double }
        set { defaults.set(newValue, forKey: PreferenceKeys.plantixLatitude) }
    }

    var plantixLongitude: Double? {
        get { defaults.object(forKey: PreferenceKeys.plantixLongitude) as? Double }
        set { defaults.set(newValue, forKey: PreferenceKeys.plantixLongitude) }
    }

    var dashboardFirstTimeViewed: Bool {
        get { defaults.bool(forKey: PreferenceKeys.dashboardFirstTimeViewed) }
        set { defaults.set(newValue, forKey: PreferenceKeys.dashboardFirstTimeViewed) }
    }

    var firstQueryAsked: Bool {
        get { defaults.bool(forKey: PreferenceKeys.firstQueryAsked) }
        set { defaults.set(newValue, forKey: PreferenceKeys.firstQueryAsked) }
    }

    // MARK: - Pending deep-link target (SPLASH_SCREEN.md §4.2 / §7)
    /// Survives cold start + onboarding. Read/cleared by `AppNavigator.consumePendingTarget()`.
    var pendingTarget: PendingTarget? {
        get {
            guard let data = defaults.data(forKey: PreferenceKeys.pendingTarget) else { return nil }
            return try? JSONDecoder().decode(PendingTarget.self, from: data)
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: PreferenceKeys.pendingTarget)
            } else {
                defaults.removeObject(forKey: PreferenceKeys.pendingTarget)
            }
        }
    }

    // MARK: - Logout (per SHARED_PREFERENCES_KEYS_AND_SCREENS.md §4.9)
    /// Clear all except APPEARANCE_MODE, DARK_THEME_ENABLED, GPS_PERMISSION_ASKED; then re-set preserved so theme survives logout.
    func clearOnLogout() {
        let preservedAppearance = appearanceModeRaw
        let preservedDarkTheme = darkThemeEnabled
        let preservedGpsAsked = gpsPermissionAsked

        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        } else {
            let keysToClear: [String] = [
                PreferenceKeys.prefUserId,
                PreferenceKeys.appAccessToken,
                PreferenceKeys.appRefreshToken,
                PreferenceKeys.otpVerified,
                PreferenceKeys.userRole,
                PreferenceKeys.userPhoneCountryCode,
                PreferenceKeys.phoneNumberLogin,
                PreferenceKeys.selectedLanguageId,
                PreferenceKeys.selectedLanguageCode,
                PreferenceKeys.selectedLanguageDisplayName,
                PreferenceKeys.userName,
                PreferenceKeys.userNameAdded,
                PreferenceKeys.onboardingLanguageDone,
                PreferenceKeys.onboardingNameDone,
                PreferenceKeys.nameScreenSeenOnce,
                PreferenceKeys.firstTimeOnboardingCompleted,
                PreferenceKeys.languageLabelsJson,
                PreferenceKeys.languageLabelsLoaded,
                PreferenceKeys.deviceId,
                PreferenceKeys.lastKnownLat,
                PreferenceKeys.lastKnownLng,
                PreferenceKeys.locationUpdatedAt,
                PreferenceKeys.locationPermissionDenyCount,
                PreferenceKeys.gpsPermissionShouldAsk,
                PreferenceKeys.locationUpgradedToGps,
                PreferenceKeys.userCountryCode,
                PreferenceKeys.userCountryName,
                PreferenceKeys.userSelectedStateCode,
                PreferenceKeys.newConversationId,
                PreferenceKeys.cachedHomeFeedResponse,
                PreferenceKeys.cameraPermissionDenyCount,
                PreferenceKeys.cameraPermissionAttemptCount,
                PreferenceKeys.microphonePermissionDenyCount,
                PreferenceKeys.microphonePermissionAttemptCount,
                PreferenceKeys.asrEnabled,
                PreferenceKeys.ttsEnabled,
                PreferenceKeys.buildVersionApiCalled,
                PreferenceKeys.plantixLatitude,
                PreferenceKeys.plantixLongitude,
                PreferenceKeys.pendingNameUpdatedToast,
                PreferenceKeys.dashboardFirstTimeViewed,
                PreferenceKeys.firstQueryAsked,
                PreferenceKeys.pendingTarget,
                PreferenceKeys.pendingPreGeneratedContent,
            ]
            keysToClear.forEach { defaults.removeObject(forKey: $0) }
        }

        appearanceModeRaw = preservedAppearance
        darkThemeEnabled = preservedDarkTheme
        gpsPermissionAsked = preservedGpsAsked

        objectWillChange.send()
    }
}
