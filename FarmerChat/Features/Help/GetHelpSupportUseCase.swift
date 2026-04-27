//
//  GetHelpSupportUseCase.swift
//  FarmerChat
//
//  Use case: get help support FAQs + legal (Android GetHelpSupportUseCase parity).
//

import Foundation

final class GetHelpSupportUseCase {
    private let repository: HelpRepositoryProtocol
    private let preferences: PreferencesManager

    init(
        repository: HelpRepositoryProtocol = HelpRepository(),
        preferences: PreferencesManager = .shared
    ) {
        self.repository = repository
        self.preferences = preferences
    }

    func execute(limit: Int = 5) async throws -> HelpSupportResponse {
        let lang = preferences.selectedLanguageCode ?? "en"
        let theme: String = switch preferences.appearanceMode {
        case .day: "light"
        case .night: "dark"
        case .auto: "default"
        }
        let country = preferences.userCountryCode
        return try await repository.getHelpSupport(lang: lang, limit: limit, theme: theme, country: country)
    }
}
