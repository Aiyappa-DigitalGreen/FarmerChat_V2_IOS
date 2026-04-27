//
//  AuthUseCase.swift
//  FarmerChat
//
//  Use case: send OTP, verify OTP, countries, OTP mode, guest init (Android parity).
//

import Foundation

final class AuthUseCase {
    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository
    }

    func sendOtp(phoneNumber: String, countryCode: String, channel: [String]) async throws {
        try await repository.sendOtp(phoneNumber: phoneNumber, countryCode: countryCode, channel: channel)
    }

    func verifyOtp(phoneNumber: String, countryCode: String, otp: String) async throws -> VerifyOtpResponse {
        try await repository.verifyOtp(phoneNumber: phoneNumber, countryCode: countryCode, otp: otp)
    }

    func getAllCountries() async throws -> [CountryItem] {
        try await repository.getAllCountries()
    }

    func getOtpMode(phoneCountryCode: String) async throws -> GetOtpModeResponseItem? {
        try await repository.getOtpMode(phoneCountryCode: phoneCountryCode)
    }

    func initializeUser(deviceId: String) async throws -> InitializeGuestUserResponse {
        try await repository.initializeUser(deviceId: deviceId)
    }

    func acceptTerms() async throws {
        try await repository.acceptTerms()
    }
}
