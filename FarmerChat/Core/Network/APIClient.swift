//
//  APIClient.swift
//  FarmerChat
//
//  URLSession-based REST client with auth interceptor and token refresh.
//

import Foundation
import os.log
import UIKit

private let apiLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "FarmerChat", category: "API")

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decoding(Error)
    case server(Int, String?)
    case network(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No response data"
        case .decoding(let e): return "Invalid response: \(e.localizedDescription)"
        case .server(let code, let msg):
            if let msg = msg, !msg.isEmpty { return msg }
            return "Server error (\(code))"
        case .network(let e): return e.localizedDescription
        case .unauthorized: return "Session expired. Please sign in again."
        }
    }
}

actor APIClient {
    private let baseURL: String
    private let session: URLSession
    private let preferences: PreferencesManager
    private let keychain: KeychainManager

    init(
        baseURL: String = AppEnvironment.current.baseURL,
        preferences: PreferencesManager = .shared,
        keychain: KeychainManager = .shared
    ) {
        self.baseURL = baseURL
        self.preferences = preferences
        self.keychain = keychain
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = ApiConstants.readTimeout
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    private func token() -> String? {
        keychain.string(forKey: "APP_ACCESS_TOKEN") ?? preferences.accessToken
    }

    private func setTokens(access: String?, refresh: String?) {
        if let a = access { keychain.set(value: a, forKey: "APP_ACCESS_TOKEN"); preferences.accessToken = a }
        if let r = refresh { keychain.set(value: r, forKey: "APP_REFRESH_TOKEN"); preferences.refreshToken = r }
    }

    // MARK: - External (non-backend) requests

    private func absoluteRequest(
        url: URL,
        method: String,
        body: Encodable? = nil,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(value: body))
        }
        let fullURL = url.absoluteString
        os_log(.default, log: apiLog, "--> %{public}@ %{public}@", method, fullURL)
        print("[API] REQUEST \(method) \(fullURL)")
        if let bodyData = req.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8), !bodyStr.isEmpty {
            print("[API] REQUEST BODY: \(bodyStr.count > 2000 ? String(bodyStr.prefix(2000)) + "…" : bodyStr)")
        }
        let (data, res) = try await session.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw APIError.noData }
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        let responseTruncated = responseStr.count > 2000 ? String(responseStr.prefix(2000)) + "…" : responseStr
        print("[API] RESPONSE \(http.statusCode) \(method) \(fullURL)")
        print("[API] RESPONSE BODY: \(responseTruncated)")
        if http.statusCode >= 400 {
            os_log(.error, log: apiLog, "<-- ERROR %d %{public}@ %{public}@ %{public}@", http.statusCode, method, fullURL, responseStr)
            throw APIError.server(http.statusCode, responseStr)
        }
        os_log(.info, log: apiLog, "<-- SUCCESS %d %{public}@ %{public}@", http.statusCode, method, fullURL)
        return (data, http)
    }

    private struct GoogleGeolocateRequest: Codable { let considerIp: Bool }
    private struct GoogleGeolocateResponse: Codable {
        struct Loc: Codable { let lat: Double; let lng: Double }
        let location: Loc
        let accuracy: Double?
    }

    /// IP-based approximate location (per GPS_AND_COUNTRY_FLOW_GUEST_VS_LOGGED_IN.md).
    /// Best-effort; returns nil if GEO_API_KEY missing or request fails.
    private func ipGeolocateIfPossible() async -> (lat: Double, lng: Double, accuracy: Double?)? {
        guard let key = AppConfig.geoApiKey, !key.isEmpty else { return nil }
        guard let url = URL(string: "https://www.googleapis.com/geolocation/v1/geolocate?key=\(key)") else { return nil }
        do {
            let (data, _) = try await absoluteRequest(url: url, method: "POST", body: GoogleGeolocateRequest(considerIp: true))
            let decoded = try JSONDecoder().decode(GoogleGeolocateResponse.self, from: data)
            return (decoded.location.lat, decoded.location.lng, decoded.accuracy)
        } catch {
            return nil
        }
    }

    /// Locale-based fallback location (very approximate). Used only when GPS and IP geo are unavailable.
    private func localeFallbackLatLng() -> (lat: Double, lng: Double)? {
        let cc = (Locale.current.region?.identifier ?? "").uppercased()
        switch cc {
        case "IN": return (20.5937, 78.9629)
        case "KE": return (-0.0236, 37.9062)
        case "UG": return (1.3733, 32.2903)
        case "TZ": return (-6.3690, 34.8888)
        case "NG": return (9.0820, 8.6753)
        case "GH": return (7.9465, -1.0232)
        case "US": return (37.0902, -95.7129)
        case "GB": return (55.3781, -3.4360)
        default: return nil
        }
    }

    private func url(path: String, query: [String: String] = [:]) -> URL? {
        var comp = URLComponents(string: baseURL + path)
        if !query.isEmpty { comp?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return comp?.url
    }

    private func request(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        query: [String: String] = [:],
        skipAuth: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = url(path: path, query: query) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0", forHTTPHeaderField: "Build-Version")
        req.setValue(encodedDeviceInfo(), forHTTPHeaderField: "Device-Info")
        if let lang = preferences.selectedLanguageCode, !lang.isEmpty {
            req.setValue(lang, forHTTPHeaderField: ApiConstants.headerLanguage)
        }

        if !skipAuth, let t = token() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: ApiConstants.headerAuth)
        } else if skipAuth, let apiKey = AppConfig.guestUserApiKey {
            req.setValue(apiKey, forHTTPHeaderField: ApiConstants.headerApiKey)
        }

        if let b = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(value: b))
        }

        let fullURL = url.absoluteString
        let requestBodyStr = req.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        os_log(.default, log: apiLog, "--> %{public}@ %{public}@", method, fullURL)
        print("[API] REQUEST \(method) \(fullURL)")
        if !requestBodyStr.isEmpty {
            let truncated = requestBodyStr.count > 2000 ? String(requestBodyStr.prefix(2000)) + "…" : requestBodyStr
            os_log(.default, log: apiLog, "[API] REQUEST BODY: %{public}@", truncated)
            print("[API] REQUEST BODY: \(truncated)")
        }

        do {
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse else {
                os_log(.error, log: apiLog, "<-- FAILED %{public}@ %{public}@ (no HTTP response)", method, fullURL)
                print("[API] RESPONSE FAILED \(method) \(path) – no HTTP response")
                throw APIError.noData
            }

            let responseStr = String(data: data, encoding: .utf8) ?? ""
            let responseTruncated = responseStr.count > 2000 ? String(responseStr.prefix(2000)) + "…" : responseStr
            os_log(.default, log: apiLog, "<-- %d %{public}@ %{public}@", http.statusCode, method, fullURL)
            os_log(.default, log: apiLog, "[API] RESPONSE BODY: %{public}@", responseTruncated)
            print("[API] RESPONSE \(http.statusCode) \(method) \(path)")
            print("[API] RESPONSE BODY: \(responseTruncated)")

            if http.statusCode == 401 && !skipAuth {
                // Token refresh then retry once
                if await refreshToken() {
                    return try await request(path: path, method: method, body: body, query: query, skipAuth: false)
                }
                os_log(.error, log: apiLog, "<-- ERROR 401 %{public}@ %{public}@ (unauthorized)", method, fullURL)
                print("[API] RESPONSE ERROR 401 \(method) \(path) – unauthorized")
                throw APIError.unauthorized
            }

            if http.statusCode >= 400 {
                let message = parseServerErrorMessage(data: data)
                os_log(.error, log: apiLog, "<-- ERROR %d %{public}@ %{public}@ %{public}@", http.statusCode, method, fullURL, message ?? "")
                print("[API] RESPONSE ERROR \(http.statusCode) \(method) \(path): \(message ?? responseTruncated)")
                throw APIError.server(http.statusCode, message)
            }

            os_log(.info, log: apiLog, "<-- SUCCESS %d %{public}@ %{public}@", http.statusCode, method, fullURL)
            return (data, http)
        } catch {
            os_log(.error, log: apiLog, "<-- FAILED %{public}@ %{public}@ %{public}@", method, fullURL, String(describing: error))
            print("[API] REQUEST FAILED \(method) \(path): \(error)")
            throw error
        }
    }

    /// Extract user-facing message from 4xx/5xx JSON body (e.g. {"detail": "Invalid OTP"} or {"message": "..."}).
    private func parseServerErrorMessage(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        if let detail = json["detail"] as? String, !detail.isEmpty { return detail }
        if let msg = json["message"] as? String, !msg.isEmpty { return msg }
        if let msg = json["error"] as? String, !msg.isEmpty { return msg }
        return json["detail"] as? String ?? json["message"] as? String ?? String(data: data, encoding: .utf8)
    }

    private func refreshToken() async -> Bool {
        guard let refresh = keychain.string(forKey: "APP_REFRESH_TOKEN") ?? preferences.refreshToken,
              let url = URL(string: baseURL + AppConfig.authRefreshPath) else { return false }
        let fullURL = url.absoluteString
        os_log(.default, log: apiLog, "--> POST %{public}@ (refresh token)", fullURL)
        print("[API] REQUEST POST \(fullURL) (refresh token)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = AppConfig.guestUserApiKey {
            req.setValue(apiKey, forHTTPHeaderField: ApiConstants.headerApiKey)
        }
        req.httpBody = try? JSONEncoder().encode(RefreshTokenRequest(refresh_token: refresh))
        guard let (data, res) = try? await session.data(for: req),
              let http = res as? HTTPURLResponse else {
            os_log(.error, log: apiLog, "<-- FAILED POST %{public}@ (refresh token)", fullURL)
            print("[API] RESPONSE FAILED POST (refresh token)")
            return false
        }
        let refreshRespStr = String(data: data, encoding: .utf8) ?? ""
        print("[API] RESPONSE \(http.statusCode) POST (refresh token)")
        print("[API] RESPONSE BODY: \(refreshRespStr.count > 500 ? String(refreshRespStr.prefix(500)) + "…" : refreshRespStr)")
        guard let decoded = try? JSONDecoder().decode(RefreshTokenResponse.self, from: data) else {
            os_log(.error, log: apiLog, "<-- ERROR %d POST %{public}@ (refresh token decode failed)", http.statusCode, fullURL)
            print("[API] RESPONSE ERROR \(http.statusCode) (refresh token decode failed)")
            return false
        }
        os_log(.info, log: apiLog, "<-- SUCCESS %d POST %{public}@ (refresh token)", http.statusCode, fullURL)
        setTokens(access: decoded.access_token, refresh: decoded.refresh_token ?? refresh)
        return true
    }

    private func userId() -> String { preferences.userId ?? "" }

    /// Returns a non-empty device id (creates and persists one if missing). Backend requires valid device_id for generate_otp.
    private func deviceId() -> String {
        preferences.resolvedDeviceId
    }

    /// Device-Info header: URL-encoded JSON matching Android format so backend accepts it (avoids "device_id invalid or corrupt device_info format").
    private func encodedDeviceInfo() -> String {
        let did = deviceId()
        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let deviceConfig: [String: Any] = [
            "Build-Version": "v2",
            "app_version_name": versionName,
            "app_version_code": 1,
            "manufacturer": "Apple",
            "model": UIDevice.current.model,
            "brand": "Apple",
            "hardware": "iPhone",
            "product": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "android_id": did
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: deviceConfig),
              let json = String(data: data, encoding: .utf8) else {
            return did.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? did
        }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return json.addingPercentEncoding(withAllowedCharacters: allowed) ?? json
    }

    // MARK: - User
    func initializeUser(deviceId: String) async throws -> InitializeGuestUserResponse {
        // Per spec: prefer GPS (prefs.lastKnownLat/Lng), else IP geolocate (Google), else backend fallback.
        let gpsLat = preferences.lastKnownLat
        let gpsLng = preferences.lastKnownLng
        let ip = (gpsLat == nil || gpsLng == nil) ? await ipGeolocateIfPossible() : nil
        let locale = (gpsLat == nil || gpsLng == nil) && ip == nil ? localeFallbackLatLng() : nil
        let body = InitializeGuestUserRequest(
            device_id: deviceId,
            lat: gpsLat ?? ip?.lat ?? locale?.lat,
            long: gpsLng ?? ip?.lng ?? locale?.lng,
            accuracy: ip?.accuracy,
            utm_source: nil,
            utm_medium: nil,
            utm_campaign: nil,
            moengage_id: nil,
            google_advertise_id: nil
        )
        let (data, _) = try await request(path: "api/user/initialize_user/", method: "POST", body: body, skipAuth: true)
        return try JSONDecoder().decode(InitializeGuestUserResponse.self, from: data)
    }

    func acceptTerms() async throws {
        let body = AcceptPPandTCRequest(userId: userId())
        let _ = try await request(path: "api/user/accept_terms/", method: "POST", body: body, skipAuth: token() == nil)
    }

    /// LANGUAGE_SCREEN.md §6.8 — fired once per install during onboarding/splash.
    /// Caller enforces the `BUILD_VERSION_API_CALLED` pref gate.
    func updateBuildVersion() async throws {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        struct BuildVersionRequest: Codable {
            let user_id: String
            let app_version: String
            let build_version: String
            let platform: String
        }
        let body = BuildVersionRequest(
            user_id: userId(),
            app_version: version,
            build_version: build,
            platform: "ios"
        )
        let _ = try await request(path: "api/user/v2/update_build_version/", method: "POST", body: body, skipAuth: token() == nil)
    }

    func setPreferredLanguage(languageId: String) async throws {
        guard let id = Int(languageId) else {
            throw APIError.server(400, "Invalid language id: \(languageId)")
        }
        let body = SetPreferredLanguageRequest(languageId: id, userId: userId())
        let _ = try await request(path: "api/user/set_preferred_language/", method: "POST", body: body, skipAuth: token() == nil)
    }

    func updateUserProfile(name: String) async throws -> UserNameResponse {
        let parts = name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let first = String(parts.first ?? "")
        let last = parts.count > 1 ? String(parts[1]) : ""
        let body = UserNameRequest(
            user_id: userId(),
            name: name,
            first_name: first.isEmpty ? nil : first,
            last_name: last.isEmpty ? nil : last
        )
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Home] update_user_profile (name) REQUEST: \(bodyStr)")
        }
        let (data, _) = try await request(path: ApiConstants.updateUserName, method: "POST", body: body)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Home] update_user_profile (name) RESPONSE: \(responseStr.prefix(700))\(responseStr.count > 700 ? "…" : "")")
        return try JSONDecoder().decode(UserNameResponse.self, from: data)
    }

    func updateUserProfile(gender: String) async throws {
        let raw = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        // Per GENDER_LIVESTOCK_CROP_API.md: send option id as-is (e.g. "gender_male")
        let body = UserNameRequest(user_id: userId(), gender: raw)
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Home] update_user_profile (gender) REQUEST: \(bodyStr)")
        }
        let _ = try await request(path: ApiConstants.updateUserName, method: "POST", body: body)
    }

    func updateUserProfile(liveStockDetails: [LiveStockDetail]) async throws {
        let body = UserNameRequest(user_id: userId(), live_stock_details: liveStockDetails)
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Home] update_user_profile (livestock) REQUEST: \(bodyStr)")
        }
        let _ = try await request(path: ApiConstants.updateUserName, method: "POST", body: body)
    }

    func updateCropDetails(cropDetails: [String]) async throws -> UpdateCropDetailsResponse {
        let body = UpdateCropDetailsRequest(user_id: userId(), crop_details: cropDetails)
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Home] update_crop_details REQUEST: \(bodyStr)")
        }
        let (data, _) = try await request(path: ApiConstants.updateCropDetails, method: "POST", body: body)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Home] update_crop_details RESPONSE: \(responseStr)")
        return try JSONDecoder().decode(UpdateCropDetailsResponse.self, from: data)
    }

    func viewUserProfile() async throws -> FarmerProfile {
        print("[Home] view_user_profile REQUEST: GET ?id=\(userId())")
        let (data, _) = try await request(path: "api/user/view_user_profile/", query: ["id": userId()])
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Home] view_user_profile RESPONSE: \(responseStr.prefix(500))\(responseStr.count > 500 ? "…" : "")")
        return try JSONDecoder().decode(FarmerProfile.self, from: data)
    }

    func updateUserLocation(lat: Double, lng: Double) async throws {
        let body = UpdateLocationRequest(user_id: userId(), lat: "\(lat)", long: "\(lng)", geography_level2: nil, geography_level3: nil, geography_level4: nil, geography_level5: nil, geography_level6: nil, address: nil)
        let _ = try await request(path: "api/user/update_user_location/", method: "POST", body: body)
    }

    func getAllCountries() async throws -> [CountryItem] {
        let (data, _) = try await request(path: ApiConstants.getAllCountries, skipAuth: token() == nil)
        return try JSONDecoder().decode([CountryItem].self, from: data)
    }

    func getOtpMode(phoneCountryCode: String) async throws -> GetOtpModeResponseItem? {
        let stripped = phoneCountryCode.replacingOccurrences(of: "+", with: "")
        print("[API] getOtpMode: requesting with phone_country_code=\(stripped)")
        let (data, _) = try await request(
            path: ApiConstants.getCommunicationChannel,
            query: ["phone_country_code": stripped],
            skipAuth: token() == nil
        )
        let rawJson = String(data: data, encoding: .utf8) ?? "(nil)"
        print("[API] getOtpMode: raw response=\(rawJson)")
        let list = try JSONDecoder().decode([GetOtpModeResponseItem].self, from: data)
        let first = list.first
        print("[API] getOtpMode: decoded sms=\(String(describing: first?.sms_enabled)), wa=\(String(describing: first?.whatsapp_enabled))")
        return first
    }

    func sendOtp(phoneNumber: String, countryCode: String, channel: [String]) async throws -> SendOtpResponse {
        let body = SendOtpRequest(phone: phoneNumber, phone_country_code: countryCode, channel: channel, device_id: deviceId(), user_id: userId())
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Auth] generate_otp REQUEST: \(bodyStr)")
        }
        let (data, http) = try await request(path: ApiConstants.sendOtp, method: "POST", body: body, skipAuth: true)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Auth] generate_otp RESPONSE (\(http.statusCode)): \(responseStr)")
        return try JSONDecoder().decode(SendOtpResponse.self, from: data)
    }

    func verifyOtp(phoneNumber: String, countryCode: String, otp: String) async throws -> VerifyOtpResponse {
        // Match Android: guest_onboarding "True" (capital T), user_id from guest init
        let body = VerifyOtpRequest(otp: otp, phone: phoneNumber, phone_country_code: countryCode, guest_onboarding: "True", user_id: userId())
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Auth] verify_otp REQUEST: \(bodyStr)")
        }
        let (data, http) = try await request(path: ApiConstants.verifyOtp, method: "POST", body: body, skipAuth: true)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Auth] verify_otp RESPONSE (\(http.statusCode)): \(responseStr)")
        // Backend may return flat { access_token, id, ... } or wrapped { data: { access_token, ... } }
        let decoded: VerifyOtpResponse
        if let wrapped = try? JSONDecoder().decode(VerifyOtpDataWrapper.self, from: data) {
            decoded = wrapped.data
        } else {
            decoded = try JSONDecoder().decode(VerifyOtpResponse.self, from: data)
        }
        // Backend may return 200 with error/detail in body for invalid OTP
        if decoded.error == true {
            let msg = decoded.detail ?? decoded.message ?? "Invalid OTP"
            throw APIError.server(401, msg)
        }
        return decoded
    }

    func logout() async throws {
        let _ = try await request(path: "api/user/logout/", method: "POST")
    }

    // MARK: - Language (guest-accessible when no token: send API-Key via skipAuth)
    /// - Parameters:
    ///   - countryCode: ISO 3166-1 alpha-2 (e.g. "IN", "KE"). Defaults to device region.
    ///   - state: State/region code (backend requires it; use "" if unknown).
    func countryWiseSupportedLanguages(countryCode: String? = nil, state: String = "") async throws -> [SupportedLanguageGroup] {
        let code = countryCode ?? preferences.userCountryCode ?? Locale.current.region?.identifier ?? "IN"
        let (data, _) = try await request(
            path: "api/language/v2/country_wise_supported_languages/",
            query: ["country_code": code, "state": state],
            skipAuth: token() == nil
        )
        return try JSONDecoder().decode([SupportedLanguageGroup].self, from: data)
    }

    func getLabels(languageId: String) async throws -> [String: String] {
        let (data, _) = try await request(
            path: "api/language/v2/get_labels/",
            query: ["language": languageId],
            skipAuth: token() == nil
        )
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    // MARK: - Home
    /// Load daily feed (per HOME_AND_CHAT_COMPLETE_APIS.md). user_device_time e.g. "14:30"; optional user_id for logged-in.
    func dailyContent(userDeviceTime: String? = nil, userId: String? = nil) async throws -> HomeUdfResponse {
        var query: [String: String] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        let timeStr = userDeviceTime ?? formatter.string(from: Date())
        query["user_device_time"] = timeStr
        if let uid = userId ?? preferences.userId, !uid.isEmpty { query["user_id"] = uid }
        let skipAuth = token() == nil
        let reqStr = "GET ?user_device_time=\(timeStr)\(query["user_id"].map { "&user_id=\($0)" } ?? "")"
        print("[Home] daily_content REQUEST: \(reqStr)")
        let (data, http) = try await request(path: "api/images/v2/daily/", query: query, skipAuth: skipAuth)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Home] daily_content RESPONSE (\(http.statusCode)): \(responseStr.prefix(700))\(responseStr.count > 700 ? "…" : "")")
        if http.statusCode == 204 || data.isEmpty {
            return HomeUdfResponse(greeting: nil, sections: [])
        }
        return try JSONDecoder().decode(HomeUdfResponse.self, from: data)
    }

    /// GET api/images/v2/user_question_count/ – returns `{total_questions_asked, bypass_interstitial}` (AUTH_FLOW.md §6.1).
    /// Caller routes on `bypass_interstitial`; on thrown error, Android no-ops (user stays on current screen).
    func userQuestionCount() async throws -> UserQuestionCountResponse {
        let skipAuth = token() == nil
        print("[Auth] user_question_count REQUEST: GET api/images/v2/user_question_count/")
        let (data, http) = try await request(path: "api/images/v2/user_question_count/", method: "GET", skipAuth: skipAuth)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Auth] user_question_count RESPONSE (\(http.statusCode)): \(responseStr)")
        return try JSONDecoder().decode(UserQuestionCountResponse.self, from: data)
    }

    /// Image/statement card content (short_answer + follow_up_questions) for Home feed. Mirrors Android getImageStatement.
    func imageStatement(statementId: String, triggeredInputType: String = "statement") async throws -> ImageStatementResponse {
        let body = ImageStatementRequest(statement_id: statementId, triggered_input_type: triggeredInputType)
        let (data, _) = try await request(path: ApiConstants.imageStatement, method: "POST", body: body)
        return try JSONDecoder().decode(ImageStatementResponse.self, from: data)
    }

    /// PATCH api/images/v2/viewed/ – mark image card viewed (per HOME_AND_CHAT_COMPLETE_APIS.md). Call when card 50%+ visible.
    func markImageViewed(statementId: String, userId: String, status: String = "viewed") async throws -> ImageViewedResponse {
        let body = ImageViewedRequest(statement_id: statementId, user_id: userId, status: status)
        let (data, _) = try await request(path: ApiConstants.imageViewed, method: "PATCH", body: body)
        return try JSONDecoder().decode(ImageViewedResponse.self, from: data)
    }

    /// Weather forecast. Backend expects POST body with user_id (uses saved location); optionally lat/long.
    /// Send Bearer when logged in, API-Key when guest. If backend returns 404 "User profile not found", caller should treat as no weather (show "--°").
    func weatherForecast(lat: Double?, lng: Double?) async throws -> WeatherResponse {
        let uid = userId()
        guard !uid.isEmpty else { throw APIError.server(400, "user_id required for weather") }
        let body = WeatherRequest(
            user_id: uid,
            lat: lat.map { "\($0)" },
            long: lng.map { "\($0)" }
        )
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Home] weather_forecast REQUEST: \(bodyStr)")
        }
        let (data, _) = try await request(
            path: ApiConstants.weather,
            method: "POST",
            body: body,
            query: [:],
            skipAuth: token() == nil
        )
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Home] weather_forecast RESPONSE: \(responseStr.prefix(700))\(responseStr.count > 700 ? "…" : "")")
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }

    // MARK: - Chat
    func newConversation() async throws -> NewConversationResponse {
        let body = NewConversationRequest(user_id: userId())
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            os_log(.default, log: apiLog, "[Chat] new_conversation REQUEST: %{public}@", bodyStr)
            print("[Chat] new_conversation REQUEST: \(bodyStr)")
        }
        let (data, _) = try await request(path: "api/chat/new_conversation/", method: "POST", body: body)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        os_log(.default, log: apiLog, "[Chat] new_conversation RESPONSE (200): %{public}@", responseStr)
        print("[Chat] new_conversation RESPONSE: \(responseStr)")
        let decoded = try JSONDecoder().decode(NewConversationResponse.self, from: data)
        print("[Chat] new_conversation decoded conversation_id: \(decoded.conversation_id)")
        await MainActor.run { preferences.newConversationId = decoded.conversation_id }
        return decoded
    }

    /// triggeredInputType: "text" for text, "audio" for voice (per QUERY_FLOW_AND_APIS.md). Pass messageId "" for first message.
    func getAnswerForTextQuery(conversationId: String, query: String, messageId: String = "", triggeredInputType: String = "text", transcriptionId: String? = nil, statementId: String? = nil, weatherCtaTriggered: Bool = false) async throws -> TextPromptResponse {
        let cc = (preferences.userCountryCode ?? Locale.current.region?.identifier ?? "IN")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let countryCodeToSend = cc.isEmpty ? "IN" : cc.uppercased()
        let body = TextPromptRequest(
            query: query,
            conversation_id: conversationId,
            message_id: messageId,
            weather_cta_triggered: weatherCtaTriggered,
            triggered_input_type: triggeredInputType,
            ssfr_crop: nil,
            use_entity_extraction: true,
            transcription_id: transcriptionId,
            retry: false,
            statement_id: statementId,
            country_code: countryCodeToSend
        )
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            os_log(.default, log: apiLog, "[Chat] get_answer_for_text_query REQUEST: %{public}@", bodyStr)
            print("[Chat] get_answer_for_text_query REQUEST: \(bodyStr)")
        }
        let (data, _) = try await request(path: "api/chat/get_answer_for_text_query/", method: "POST", body: body, skipAuth: token() == nil)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        os_log(.default, log: apiLog, "[Chat] get_answer_for_text_query RESPONSE (200): %{public}@", responseStr)
        print("[Chat] get_answer_for_text_query RESPONSE: \(responseStr)")
        do {
            let decoded = try JSONDecoder().decode(TextPromptResponse.self, from: data)
            let ansText = decoded.response ?? "<nil>"
            let transText = decoded.translated_response ?? "<nil>"
            let mid = decoded.message_id ?? "<nil>"
            print("[Chat] get_answer decoded response (answer text):", ansText)
            print("[Chat] get_answer decoded translated_response:", transText)
            print("[Chat] get_answer decoded message_id:", mid)
            return decoded
        } catch {
            print("[Chat] get_answer DECODE FAILED: \(error) – attempting fallback parse")
            // Fallback: extract response/translated_response/message_id (top-level or nested under "data") so we don't lose content.
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw error }
            let dataObj = json["data"] as? [String: Any]
            let response = (json["response"] as? String) ?? (dataObj?["response"] as? String)
                ?? (json["translated_response"] as? String) ?? (dataObj?["translated_response"] as? String)
            let translatedResponse = (json["translated_response"] as? String) ?? (dataObj?["translated_response"] as? String)
            let messageId = (json["message_id"] as? String) ?? (dataObj?["message_id"] as? String)
            let messageText = (json["message"] as? String) ?? (dataObj?["message"] as? String)
            let content = response ?? translatedResponse ?? messageText
            if content != nil {
                var followUps: [FollowUpQuestionOption]?
                let arr = (json["follow_up_questions"] ?? dataObj?["follow_up_questions"]) as? [[String: Any]]
                if let arr = arr, !arr.isEmpty {
                    followUps = arr.compactMap { dict in
                        guard let q = dict["question"] as? String else { return nil }
                        return FollowUpQuestionOption(follow_up_question_id: dict["follow_up_question_id"] as? String, sequence: (dict["sequence"] as? NSNumber)?.intValue, question: q)
                    }
                    if followUps?.isEmpty == true { followUps = nil }
                }
                let fallback = TextPromptResponse(response: content, message_id: messageId, translated_response: translatedResponse, follow_up_questions: followUps)
                print("[Chat] get_answer fallback used – content length:", content?.count ?? 0, "message_id:", messageId ?? "nil")
                return fallback
            }
            throw error
        }
    }

    func conversationList(page: Int = 1) async throws -> ConversationListResponse {
        let uid = userId()
        guard !uid.isEmpty else { throw APIError.server(400, "user_id required for conversation_list") }
        let query: [String: String] = ["user_id": uid, "page": "\(page)"]
        let reqStr = "GET ?user_id=\(uid)&page=\(page)"
        print("[Chat] conversation_list REQUEST: \(reqStr)")
        os_log(.default, log: apiLog, "[Chat] conversation_list REQUEST: %{public}@", reqStr)
        let (data, _) = try await request(path: "api/chat/conversation_list/", query: query)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Chat] conversation_list RESPONSE: \(responseStr.prefix(500))\(responseStr.count > 500 ? "…" : "")")
        os_log(.default, log: apiLog, "[Chat] conversation_list RESPONSE: %{public}@", String(responseStr.prefix(500)))
        // API may return a raw array [...] or a wrapper { "results": [...] }
        if let items = try? JSONDecoder().decode([ConversationListItem].self, from: data) {
            return ConversationListResponse(results: items, has_more: false, items: nil, can_load_more: false)
        }
        return try JSONDecoder().decode(ConversationListResponse.self, from: data)
    }

    func conversationChatHistory(conversationId: String, page: Int = 1) async throws -> ConversationChatHistoryResponse {
        let query: [String: String] = ["conversation_id": conversationId, "page": "\(page)"]
        print("[Chat] conversation_chat_history REQUEST: GET ?conversation_id=\(conversationId)&page=\(page)")
        os_log(.default, log: apiLog, "[Chat] conversation_chat_history REQUEST: conversation_id=%@", conversationId)
        let (data, _) = try await request(path: "api/chat/conversation_chat_history/", query: query)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Chat] conversation_chat_history RESPONSE: \(responseStr.prefix(500))\(responseStr.count > 500 ? "…" : "")")
        os_log(.default, log: apiLog, "[Chat] conversation_chat_history RESPONSE: %{public}@", String(responseStr.prefix(500)))
        return try JSONDecoder().decode(ConversationChatHistoryResponse.self, from: data)
    }

    /// GET api/chat/follow_up_questions/?message_id={id}&use_latest_prompt=true (Android: @Query params, default use_latest_prompt=true).
    func followUpQuestions(messageId: String, useLatestPrompt: Bool = true) async throws -> FollowUpQuestionsResponse {
        let query: [String: String] = ["message_id": messageId, "use_latest_prompt": useLatestPrompt ? "true" : "false"]
        print("[Chat] follow_up_questions GET message_id=\(messageId) use_latest_prompt=\(useLatestPrompt)")
        let (data, _) = try await request(path: ApiConstants.followUpQuestions, method: "GET", query: query, skipAuth: token() == nil)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Chat] follow_up_questions RESPONSE: \(responseStr.prefix(300))")
        return try JSONDecoder().decode(FollowUpQuestionsResponse.self, from: data)
    }

    /// POST api/chat/follow_up_question_click/ – when user taps follow-up chip (per HOME_AND_CHAT_COMPLETE_APIS.md).
    func followUpQuestionClick(followUpQuestion: String) async throws {
        let body = FollowUpQuestionClickRequest(follow_up_question: followUpQuestion)
        let _ = try await request(path: ApiConstants.followUpQuestionClick, method: "POST", body: body, skipAuth: token() == nil)
    }

    /// POST api/chat/synthesise_audio/ – TTS Listen (per HOME_AND_CHAT_COMPLETE_APIS.md). Returns audio URL.
    func synthesiseAudio(messageId: String, text: String, userId: String) async throws -> SynthesiseAudioResponse {
        let body = SynthesiseAudioRequest(message_id: messageId, text: text, user_id: userId)
        let (data, _) = try await request(path: ApiConstants.synthesiseAudio, method: "POST", body: body)
        return try JSONDecoder().decode(SynthesiseAudioResponse.self, from: data)
    }

    /// POST api/chat/add_query_to_history/ – Plotline/MoEngage QAPair (per HOME_AND_CHAT_COMPLETE_APIS.md).
    /// Call from app when logging pre-generated Q&A (e.g. from campaign); do not invoke from any SDK event.
    func addQueryToHistory(body: AddQueryToHistoryRequest) async throws {
        let _ = try await request(path: ApiConstants.addQueryToHistory, method: "POST", body: body)
    }

    /// POST transcribe_audio (per QUERY_FLOW_AND_APIS.md). Used on Home for voice input; returns heard_input_query and transcription_id.
    func transcribeAudio(body: SetVoiceRequest) async throws -> GetVoiceResponse {
        if let bodyData = try? JSONEncoder().encode(body), let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("[Chat] transcribe_audio REQUEST: \(bodyStr)")
            os_log(.default, log: apiLog, "[Chat] transcribe_audio REQUEST: %{public}@", bodyStr)
        }
        let (data, _) = try await request(path: ApiConstants.transcribeAudio, method: "POST", body: body)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Chat] transcribe_audio RESPONSE: \(responseStr)")
        os_log(.default, log: apiLog, "[Chat] transcribe_audio RESPONSE: %{public}@", responseStr)
        return try JSONDecoder().decode(GetVoiceResponse.self, from: data)
    }

    /// POST image_analysis (Plantix) (per QUERY_FLOW_AND_APIS.md). Base64 image + optional query, lat/lng.
    func imageAnalysis(conversationId: String, imageBase64: String, imageName: String, query: String? = nil, latitude: String? = nil, longitude: String? = nil, retry: Bool = false) async throws -> PlantixResponse {
        let body = PlantixRequest(conversation_id: conversationId, image: imageBase64, triggered_input_type: "image", query: query, latitude: latitude, longitude: longitude, image_name: imageName, retry: retry)
        let reqSummary = "conversation_id=\(conversationId), image_name=\(imageName), query=\(query ?? "nil"), image_base64_len=\(imageBase64.count)"
        print("[Chat] image_analysis REQUEST: \(reqSummary)")
        os_log(.default, log: apiLog, "[Chat] image_analysis REQUEST: %{public}@", reqSummary)
        let (data, _) = try await request(path: ApiConstants.imageAnalysis, method: "POST", body: body)
        let responseStr = String(data: data, encoding: .utf8) ?? ""
        print("[Chat] image_analysis RESPONSE: \(responseStr)")
        os_log(.default, log: apiLog, "[Chat] image_analysis RESPONSE: %{public}@", responseStr)
        return try JSONDecoder().decode(PlantixResponse.self, from: data)
    }

    // MARK: - Help (guest-accessible)
    /// - Parameters:
    ///   - lang: Language code (e.g. "en", "sw").
    ///   - limit: Max number of FAQs (backend expects this).
    ///   - theme: Optional theme/appearance.
    ///   - country: Optional country code.
    func faqs(lang: String? = nil, limit: Int = 5, theme: String? = nil, country: String? = nil) async throws -> HelpSupportResponse {
        var query: [String: String] = [:]
        query["lang"] = lang ?? preferences.selectedLanguageCode ?? "en"
        query["limit"] = "\(limit)"
        if let t = theme { query["theme"] = t }
        if let c = country ?? preferences.userCountryCode { query["country"] = c }
        let (data, _) = try await request(path: ApiConstants.getHelpSupport, query: query, skipAuth: token() == nil)
        return try JSONDecoder().decode(HelpSupportResponse.self, from: data)
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    func encode(to c: Encoder) throws { try value.encode(to: c) }
}
