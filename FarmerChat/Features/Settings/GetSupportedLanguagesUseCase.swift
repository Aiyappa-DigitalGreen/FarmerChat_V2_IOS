//
//  GetSupportedLanguagesUseCase.swift
//  FarmerChat
//
//  Use case: get country-wise supported languages (Android parity).
//

import Foundation

final class GetSupportedLanguagesUseCase {
    private let repository: LanguageRepositoryProtocol
    private let preferences: PreferencesManager

    init(
        repository: LanguageRepositoryProtocol = LanguageRepository(),
        preferences: PreferencesManager = .shared
    ) {
        self.repository = repository
        self.preferences = preferences
    }

    func execute(countryCode: String? = nil) async throws -> [SupportedLanguageGroup] {
        let code = countryCode ?? preferences.userCountryCode
        return try await repository.getCountryWiseSupportedLanguages(countryCode: code)
    }
}
