//
//  LocationPromptState.swift
//  FarmerChat
//
//  Screen 16: States for LocationPromptHost overlay.
//

import Foundation

enum LocationPromptState: Equatable {
    case idle
    case interstitial
    case requestPermission
    /// LOCATION_SCREEN.md §2: after permission granted, we check `CLLocationManager.locationServicesEnabled()`.
    /// Enabled → `.fetchingLocation`; disabled → `.error(.gpsUnavailable)` (iOS can't show an in-app Services sheet).
    case requestEnableGps
    case fetchingLocation
    case recovery(message: String)
    case error(LocationPromptErrorType)

    var shouldShowOverlay: Bool {
        switch self {
        case .idle: return false
        default: return true
        }
    }

    /// UI_HOME.md §7 — true when a widget/campaign is resolving GPS **without** showing
    /// the LocationPrompt overlay (skip_interstitial path). Home renders "Getting your
    /// location..." in place of "Getting today's advice" while this is true. The overlay
    /// path keeps `shouldShowOverlay=true` and this flag `false`, so Home uses the usual
    /// loader label underneath.
    var isFetchingSilently: Bool { false }
}

enum LocationPromptErrorType: Equatable {
    case noNetwork
    case gpsUnavailable
    case locationFailed
}
