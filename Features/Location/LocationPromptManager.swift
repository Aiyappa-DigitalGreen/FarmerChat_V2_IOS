//
//  LocationPromptManager.swift
//  FarmerChat
//
//  State holder for LocationPromptHost; triggers overlay from Weather flow / Campaign / Widget.
//

import CoreLocation
import Foundation
import Network

@Observable
final class LocationPromptManager {
    static let shared = LocationPromptManager()

    var state: LocationPromptState = .idle
    /// Set by the View (e.g. in .onAppear) so we can open Settings without UIKit. Called from openSettings().
    var onOpenSettings: (() -> Void)?

    /// Run after location is saved (update_user_location when userId present per MD). Used for weather → open Chat with weather query.
    private var pendingNavigation: (() -> Void)?

    /// Current flow source: "weather" / "local_context" / "campaign" / "plotline" / "moengage" / "deeplink".
    /// Campaign-originated flows (anything other than weather/local_context) emit LocationUpdatedFromWidget
    /// after update_user_location succeeds so the host can toast + refresh. Cleared at terminal states.
    private var currentTriggerSource: String?
    private var currentCampaignId: String?

    private let locationManager = LocationManager()
    private let prefs = PreferencesManager.shared

    private init() {}

    /// Posted when a campaign-originated update_user_location succeeds so Home can show the
    /// "Location updated" toast and refetch its feed. Mirrors Android `LocationUpdatedFromWidget`.
    static let locationUpdatedFromWidgetNotification = Notification.Name("LocationUpdatedFromWidget")

    /// If state != idle, ignore. If location already saved and pendingNavigation provided, run it and return. Otherwise check network; if offline show error, else show interstitial and store pendingNavigation.
    func triggerInterstitial(pendingNavigation: (() -> Void)? = nil) {
        guard state == .idle else { return }
        if let nav = pendingNavigation, prefs.isLocationEnabledOnce {
            nav()
            return
        }
        self.pendingNavigation = pendingNavigation
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            monitor.cancel()
            Task { @MainActor in
                guard let self else { return }
                if path.status == .satisfied {
                    self.state = .interstitial
                } else {
                    self.state = .error(.noNetwork)
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .userInitiated))
    }

    /// Execute stored pending navigation (e.g. weather → Chat) then clear. Used for skip, deny once, recovery close, error dismiss, fetch fallback.
    private func executePendingNavigation() {
        pendingNavigation?()
        pendingNavigation = nil
    }

    /// Continue without location: run pending nav then go idle. Do not use for Cancel (use cancel() instead).
    func continueWithoutLocation(reason: String = "continue_without_location") {
        clearCampaignContext()
        executePendingNavigation()
        state = .idle
    }

    /// Cancel: clear pending nav and go idle; stay on Home (no navigation).
    func cancel() {
        pendingNavigation = nil
        clearCampaignContext()
        state = .idle
    }

    func userTappedTurnOnLocation() {
        switch state {
        case .interstitial:
            prefs.gpsPermissionAsked = true
            state = .requestPermission
            Task { await requestPermissionAndFetchIfAllowed() }
        case .requestPermission:
            Task { await requestPermissionAndFetchIfAllowed() }
        case .error:
            retry()
        default:
            break
        }
    }

    private func requestPermissionAndFetchIfAllowed() async {
        let status = await locationManager.ensureWhenInUseAuthorization()
        await MainActor.run {
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                checkGpsAndFetch()
            case .denied, .restricted:
                prefs.locationPermissionDenyCount += 1
                if prefs.locationPermissionDenyCount >= 2 {
                    state = .recovery(message: "We need your location. Turn on in Settings or close to continue without.")
                } else {
                    executePendingNavigation()
                    state = .idle
                }
            case .notDetermined:
                state = .interstitial
            @unknown default:
                prefs.locationPermissionDenyCount += 1
                if prefs.locationPermissionDenyCount >= 2 {
                    state = .recovery(message: "We need your location. Turn on in Settings or close to continue without.")
                } else {
                    executePendingNavigation()
                    state = .idle
                }
            }
        }
    }

    /// LOCATION_SCREEN.md §9.4 — after permission granted, verify that Location Services is toggled on.
    /// If not, iOS cannot show an in-app enable sheet, so we surface `gpsUnavailable` (canRetry=false);
    /// the user's only recovery is the system Settings app.
    private func checkGpsAndFetch() {
        state = .requestEnableGps
        Task.detached(priority: .userInitiated) { [weak self] in
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run {
                guard let self else { return }
                if servicesEnabled {
                    self.fetchLocation()
                } else {
                    self.state = .error(.gpsUnavailable)
                }
            }
        }
    }

    func fetchLocation() {
        state = .fetchingLocation
        Task {
            let loc = await locationManager.requestLocation()
            await MainActor.run {
                if let loc = loc {
                    let lat = loc.coordinate.latitude
                    let lng = loc.coordinate.longitude
                    Task {
                        // Per MD: call update_user_location whenever userId is non-empty (guest init or logged-in).
                        // Persist lat/lng to UserDefaults only AFTER the API call succeeds (spec §5).
                        var serverOk = false
                        if let uid = prefs.userId, !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let ok = await locationManager.updateLocationOnServer(lat: lat, lng: lng)
                            if ok {
                                serverOk = true
                                await MainActor.run {
                                    prefs.lastKnownLat = lat
                                    prefs.lastKnownLng = lng
                                }
                            }
                        }
                        await MainActor.run {
                            // LOCATION_SCREEN.md §7 — campaign-sourced success emits LocationUpdatedFromWidget
                            // so Home can toast + refresh. Weather/local_context sources rely on pendingNavigation.
                            if serverOk, let src = currentTriggerSource, src != "weather", src != "local_context" {
                                NotificationCenter.default.post(name: Self.locationUpdatedFromWidgetNotification, object: nil, userInfo: ["campaign_id": currentCampaignId ?? "", "trigger_source": src])
                            }
                            clearCampaignContext()
                            executePendingNavigation()
                            state = .idle
                        }
                    }
                } else {
                    clearCampaignContext()
                    executePendingNavigation()
                    state = .idle
                }
            }
        }
    }

    private func clearCampaignContext() {
        currentTriggerSource = nil
        currentCampaignId = nil
    }

    func skipOrContinueWithoutLocation() {
        continueWithoutLocation(reason: "skip")
    }

    /// Open Settings only; from Recovery we keep state and pending nav. On resume with permission granted, call dismissRecoveryAndShowInterstitial().
    func openSettings() {
        onOpenSettings?()
    }

    /// NoNetwork: re-check network and go to interstitial or stay error. GpsUnavailable: use dismissErrorAndContinue() from UI.
    func retry() {
        guard case .error(.noNetwork) = state else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            monitor.cancel()
            Task { @MainActor in
                guard let self else { return }
                if path.status == .satisfied {
                    self.state = .interstitial
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .userInitiated))
    }

    /// User closed Recovery sheet → continue without location (execute pending nav, then idle).
    func dismissRecovery() {
        continueWithoutLocation(reason: "recovery_closed")
    }

    /// When app resumes from Settings and state is Recovery with permission now granted: show Interstitial again (user must tap Share location).
    func dismissRecoveryAndShowInterstitial() {
        guard case .recovery = state else { return }
        state = .interstitial
    }

    /// Call when scene becomes active (e.g. returning from Settings). If state is Recovery and permission is now granted, show Interstitial again.
    func onSceneBecameActive() {
        guard case .recovery = state else { return }
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            dismissRecoveryAndShowInterstitial()
        default:
            break
        }
    }

    /// Error (e.g. GpsUnavailable) "Try again" → dismiss and continue: execute pending nav, idle.
    func dismissErrorAndContinue() {
        executePendingNavigation()
        state = .idle
    }

    /// Per logout MD: clear any pending navigation and dismiss overlay.
    func resetAfterLogout() {
        pendingNavigation = nil
        onOpenSettings = nil
        clearCampaignContext()
        state = .idle
    }

    // MARK: - Campaign / Widget / Plotline / MoEngage (navigation_screen = gps)

    /// Trigger GPS flow from widget/Plotline/MoEngage (navigation_screen = gps). Same permission
    /// flow as weather, but no redirect after: everything stays on Home. If permission already
    /// granted AND `allow_retrigger` is absent/false, nothing happens.
    /// Per LOCATION_SCREEN.md §9.7, `action` is a pseudo-URL-style string:
    /// `enable_location?skip_interstitial=true&min_interval_ms=86400000&max_shows=3&campaign_id=abc&trigger_source=plotline&allow_retrigger=true`.
    func triggerFromCampaign(action: String? = nil, triggerSource: String = "campaign") {
        guard state == .idle else { return }
        let cfg = Self.parseCampaignAction(action)
        let resolvedSource = (cfg.triggerSource ?? triggerSource).lowercased()

        // Spec §9.7: `allow_retrigger=true` bypasses the "already enabled once" short-circuit.
        if !cfg.allowRetrigger, prefs.isLocationEnabledOnce {
            return
        }

        // Spec §9.7 frequency gating — only applies when campaign_id is present.
        if let cid = cfg.campaignId, !cid.isEmpty {
            let shown = prefs.locShownCount(campaignId: cid)
            if shown >= cfg.maxShows {
                return
            }
            let lastShown = prefs.locLastShownAt(campaignId: cid)
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            if let minInterval = cfg.minIntervalMs, lastShown > 0, (now - lastShown) < minInterval {
                return
            }
            prefs.setLocLastShownAt(campaignId: cid, millis: now)
            prefs.incrementLocShownCount(campaignId: cid)
        }

        currentTriggerSource = resolvedSource
        currentCampaignId = cfg.campaignId

        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.locationUpdateTriggered, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.trigger: resolvedSource, AnalyticsConstants.Property.attempt: 1], adjustToken: AnalyticsConstants.AdjustToken.locationUpdateTriggered)

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self, cfg] path in
            monitor.cancel()
            Task { @MainActor in
                guard let self else { return }
                guard path.status == .satisfied else {
                    self.state = .error(.noNetwork)
                    return
                }
                // Spec §9.7: skip_interstitial jumps straight to the system permission prompt.
                if cfg.skipInterstitial {
                    self.prefs.gpsPermissionAsked = true
                    self.state = .requestPermission
                    Task { await self.requestPermissionAndFetchIfAllowed() }
                } else {
                    self.state = .interstitial
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .userInitiated))
    }

    /// Parsed campaign action config. Defaults match Android behaviour.
    private struct CampaignConfig {
        var campaignId: String?
        var skipInterstitial: Bool = false
        var minIntervalMs: Int64?
        var maxShows: Int = Int.max
        var triggerSource: String?
        var allowRetrigger: Bool = false
    }

    /// Parse `enable_location?key=value&key=value...` per spec §9.7. Unknown keys are ignored.
    /// Accepts trailing-only query, no scheme — mirrors the Android parser's loose format.
    private static func parseCampaignAction(_ action: String?) -> CampaignConfig {
        var cfg = CampaignConfig()
        guard let raw = action?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return cfg }
        let queryStart = raw.firstIndex(of: "?").map { raw.index(after: $0) } ?? raw.startIndex
        let query = String(raw[queryStart...])
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            let key = String(kv[0]).lowercased()
            let value = String(kv[1])
            switch key {
            case "campaign_id", "id":
                cfg.campaignId = value
            case "skip_interstitial", "skip_why_location":
                cfg.skipInterstitial = parseBool(value)
            case "min_interval_ms":
                cfg.minIntervalMs = Int64(value)
            case "min_interval_seconds":
                if let s = Int64(value) { cfg.minIntervalMs = s * 1000 }
            case "max_shows":
                if let n = Int(value), n > 0 { cfg.maxShows = n }
            case "trigger_source":
                cfg.triggerSource = value.lowercased()
            case "allow_retrigger", "force_retrigger":
                cfg.allowRetrigger = parseBool(value)
            default: break
            }
        }
        return cfg
    }

    private static func parseBool(_ s: String) -> Bool {
        switch s.lowercased() {
        case "true", "1", "yes": return true
        default: return false
        }
    }
}
