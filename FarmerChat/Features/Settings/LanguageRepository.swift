//
//  LanguageRepository.swift
//  FarmerChat
//
//  Repository for supported languages, set preferred language, get labels (Android parity).
//

import Foundation

protocol LanguageRepositoryProtocol {
    func getCountryWiseSupportedLanguages(countryCode: String?) async throws -> [SupportedLanguageGroup]
    func setPreferredLanguage(languageId: String) async throws
    func getLabels(languageId: String) async throws -> [String: String]
}

final class LanguageRepository: LanguageRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getCountryWiseSupportedLanguages(countryCode: String?) async throws -> [SupportedLanguageGroup] {
        try await apiClient.countryWiseSupportedLanguages(countryCode: countryCode)
    }

    func setPreferredLanguage(languageId: String) async throws {
        _ = try await apiClient.setPreferredLanguage(languageId: languageId)
    }

    func getLabels(languageId: String) async throws -> [String: String] {
        try await apiClient.getLabels(languageId: languageId)
    }
}
