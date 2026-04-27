//
//  AuthRepository.swift
//  FarmerChat
//
//  Repository for auth: send OTP, verify OTP, countries, OTP mode, guest init (Android parity).
//

import Foundation

protocol AuthRepositoryProtocol {
    func sendOtp(phoneNumber: String, countryCode: String, channel: [String]) async throws
    func verifyOtp(phoneNumber: String, countryCode: String, otp: String) async throws -> VerifyOtpResponse
    func getAllCountries() async throws -> [CountryItem]
    func getOtpMode(phoneCountryCode: String) async throws -> GetOtpModeResponseItem?
    func initializeUser(deviceId: String) async throws -> InitializeGuestUserResponse
    func acceptTerms() async throws
}

final class AuthRepository: AuthRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func sendOtp(phoneNumber: String, countryCode: String, channel: [String]) async throws {
        _ = try await apiClient.sendOtp(phoneNumber: phoneNumber, countryCode: countryCode, channel: channel)
    }

    func verifyOtp(phoneNumber: String, countryCode: String, otp: String) async throws -> VerifyOtpResponse {
        try await apiClient.verifyOtp(phoneNumber: phoneNumber, countryCode: countryCode, otp: otp)
    }

    func getAllCountries() async throws -> [CountryItem] {
        try await apiClient.getAllCountries()
    }

    func getOtpMode(phoneCountryCode: String) async throws -> GetOtpModeResponseItem? {
        try await apiClient.getOtpMode(phoneCountryCode: phoneCountryCode)
    }

    func initializeUser(deviceId: String) async throws -> InitializeGuestUserResponse {
        try await apiClient.initializeUser(deviceId: deviceId)
    }

    func acceptTerms() async throws {
        _ = try await apiClient.acceptTerms()
    }
}
