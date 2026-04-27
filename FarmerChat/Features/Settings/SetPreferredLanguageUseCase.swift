//
//  SetPreferredLanguageUseCase.swift
//  FarmerChat
//
//  Use case: set preferred language (Android parity).
//

import Foundation

final class SetPreferredLanguageUseCase {
    private let repository: LanguageRepositoryProtocol
    private let preferences: PreferencesManager

    init(
        repository: LanguageRepositoryProtocol = LanguageRepository(),
        preferences: PreferencesManager = .shared
    ) {
        self.repository = repository
        self.preferences = preferences
    }

    func execute(languageId: String) async throws {
        try await repository.setPreferredLanguage(languageId: languageId)
    }
}
