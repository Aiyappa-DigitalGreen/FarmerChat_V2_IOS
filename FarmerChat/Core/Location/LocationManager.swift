//
//  LocationManager.swift
//  FarmerChat
//
//  Location: permission, fresh + last-known fetch, update_user_location API.
//  Uses CLLocationManager; replicate Android timeout/retry (e.g. 10s fresh, 2s last known).
//

import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var lastLocation: CLLocation?
    var isFetching = false

    private let manager = CLLocationManager()
    private let prefs = PreferencesManager.shared
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Requests When-In-Use authorization if needed and returns the resulting status.
    func ensureWhenInUseAuthorization() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        if status != .notDetermined { return status }
        return await withCheckedContinuation { (cont: CheckedContinuation<CLAuthorizationStatus, Never>) in
            authContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestLocation() async -> CLLocation? {
        isFetching = true
        defer { isFetching = false }
        let loc = await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = cont
            manager.requestLocation()
        }
        if let loc = loc {
            // Spec rule: never persist lat/lng on raw GPS fix — only after
            // update_user_location API succeeds (done in LocationPromptManager).
            // Timestamp + country resolution stay on raw fix (outside the spec's lat/lng rule).
            prefs.locationUpdatedAt = Date()
            await resolveAndStoreCountry(from: loc)
        }
        return loc
    }

    /// Calls update_user_location. Returns true on HTTP success so the caller
    /// can persist lat/lng to UserDefaults only then.
    @discardableResult
    func updateLocationOnServer(lat: Double, lng: Double) async -> Bool {
        do {
            try await APIClient().updateUserLocation(lat: lat, lng: lng)
            return true
        } catch {
            return false
        }
    }

    private func resolveAndStoreCountry(from location: CLLocation) async {
        guard prefs.userCountryCode == nil || prefs.userCountryCode?.isEmpty == true else { return }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let pm = placemarks.first
            let code = pm?.isoCountryCode
            let name = pm?.country
            if let code, !code.isEmpty {
                prefs.userCountryCode = code
            }
            if let name, !name.isEmpty {
                prefs.userCountryName = name
            }
        } catch {
            // Best-effort only.
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: lastLocation)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if let cont = authContinuation {
            authContinuation = nil
            cont.resume(returning: authorizationStatus)
        }
    }
}
