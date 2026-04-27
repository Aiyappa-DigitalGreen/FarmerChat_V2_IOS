//
//  PreferenceKeys.swift
//  FarmerChat
//
//  Mirrors Android PreferenceKeys / PreferenceHelperManager / LocationPromptPrefs per SHARED_PREFERENCES_KEYS_AND_SCREENS.md.
//

import Foundation

enum PreferenceKeys {
    // MARK: - User & Auth
    static let prefUserId = "PREF_USER_ID"
    static let appAccessToken = "APP_ACCESS_TOKEN"
    static let appRefreshToken = "APP_REFRESH_TOKEN"
    static let otpVerified = "OTP_VERIFIED"
    static let userRole = "USER_ROLE"
    static let userPhoneCountryCode = "GET_USER_SELECTED_COUNTRY_PHONE_CODE"
    static let phoneNumberLogin = "PHONE_NUMBER_LOGIN"

    // MARK: - Onboarding
    static let selectedLanguageId = "SELECTED_LANGUAGE_ID"
    static let selectedLanguageDisplayName = "SELECTED_LANGUAGE_DISPLAY_NAME"
    static let selectedLanguageCode = "SELECTED_LANGUAGE_CODE"
    static let userName = "USER_NAME"
    /// True when name has been set (onboarding or settings); cleared on logout.
    static let userNameAdded = "USER_NAME_ADDED"
    /// Language screen done; drives splash → name/home.
    static let onboardingLanguageDone = "ONBOARDING_LANGUAGE_DONE"
    /// Profile/name step done (KEY_NAME_DONE).
    static let onboardingNameDone = "ONBOARDING_NAME_DONE"
    /// Has user seen name screen once (KEY_NAME_SCREEN_SEEN).
    static let nameScreenSeenOnce = "NAME_SCREEN_SEEN_ONCE"
    /// Set to false after first onboarding completion; analytics/flow.
    static let firstTimeOnboardingCompleted = "First_Time_Onboarding_Completed"

    // MARK: - Appearance & UX
    static let appearanceMode = "APPEARANCE_MODE"
    static let darkThemeEnabled = "DARK_THEME_ENABLED"
    static let gpsPermissionAsked = "GPS_PERMISSION_ASKED"

    // MARK: - Language labels
    static let languageLabelsJson = "LANGUAGE_LABELS_JSON"
    /// Whether labels JSON was loaded; clear on logout.
    static let languageLabelsLoaded = "LANGUAGE_LABELS_LOADED"

    // MARK: - Device / Guest
    static let deviceId = "DEVICE_ID"

    // MARK: - Location (last known) — Android parity: FARMER_APP_LATITUDE/LONGITUDE.
    // Persist only after update_user_location API succeeds, never on raw GPS fix.
    static let lastKnownLat = "FARMER_APP_LATITUDE"
    static let lastKnownLng = "FARMER_APP_LONGITUDE"
    static let locationUpdatedAt = "LOCATION_UPDATED_AT"
    static let locationPermissionDenyCount = "LOCATION_PERMISSION_DENY_COUNT"
    static let gpsPermissionShouldAsk = "GPS_PERMISSION_SHOULD_ASK"
    static let locationUpgradedToGps = "LOCATION_UPGRADED_TO_GPS"

    // MARK: - Country / region
    static let userCountryCode = "USER_COUNTRY_CODE"
    static let userCountryName = "USER_COUNTRY_NAME"
    static let userSelectedStateCode = "USER_SELECTED_STATE_CODE"

    // MARK: - Chat
    static let newConversationId = "NEW_CONVERSATION_ID"

    // MARK: - Home
    static let cachedHomeFeedResponse = "CACHED_HOME_FEED_RESPONSE"

    // MARK: - Permission counts (camera / microphone)
    static let cameraPermissionDenyCount = "CAMERA_PERMISSION_DENY_COUNT"
    static let cameraPermissionAttemptCount = "CAMERA_PERMISSION_ATTEMPT_COUNT"
    static let microphonePermissionDenyCount = "MICROPHONE_PERMISSION_DENY_COUNT"
    static let microphonePermissionAttemptCount = "MICROPHONE_PERMISSION_ATTEMPT_COUNT"

    // MARK: - Feature flags (ASR / TTS)
    static let asrEnabled = "ASR_ENABLED"
    static let ttsEnabled = "TTS_ENABLED"

    // MARK: - Build / API
    static let buildVersionApiCalled = "BUILD_VERSION_API_CALLED"

    // MARK: - Location campaign gating (LOCATION_SCREEN.md §9.7)
    /// Prefix keys; full key is `<prefix><campaign_id>`.
    static let locLastShownAtPrefix = "loc_last_shown_at_"
    static let locShownCountPrefix = "loc_shown_count_"

    // MARK: - Plantix / image location
    static let plantixLatitude = "PLANTIX_LATITUDE"
    static let plantixLongitude = "PLANTIX_LONGITUDE"

    // MARK: - UI / Toasts
    static let pendingNameUpdatedToast = "PENDING_NAME_UPDATED_TOAST"

    // MARK: - Analytics
    static let dashboardFirstTimeViewed = "DASHBOARD_FIRST_TIME_VIEWED"
    static let firstQueryAsked = "FIRST_QUERY_ASKED"

    // MARK: - App lifecycle
    static let hasLaunchedBefore = "HAS_LAUNCHED_BEFORE"
    static let lastSeenAppVersion = "LAST_SEEN_APP_VERSION"

    // MARK: - Pending deep-link target (SPLASH_SCREEN.md §4.2 / §7)
    /// Stored as JSON-encoded `PendingTarget`; consumed in `AppNavigator.routeFromSplash`.
    static let pendingTarget = "PENDING_TARGET"
    /// Sidecar to `pendingTarget` for qapair deep links (SPLASH_SCREEN.md §5.4).
    /// Stored as JSON-encoded `PendingPreGeneratedContent`; consumed by ChatView.
    static let pendingPreGeneratedContent = "PENDING_PREGEN_CONTENT"
}
