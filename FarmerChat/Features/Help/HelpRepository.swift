//
//  HelpRepository.swift
//  FarmerChat
//
//  Repository for help support / FAQs (Android GetHelpSupportUseCase parity).
//

import Foundation

protocol HelpRepositoryProtocol {
    func getHelpSupport(lang: String?, limit: Int, theme: String?, country: String?) async throws -> HelpSupportResponse
}

final class HelpRepository: HelpRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getHelpSupport(lang: String?, limit: Int, theme: String?, country: String?) async throws -> HelpSupportResponse {
        try await apiClient.faqs(lang: lang, limit: limit, theme: theme, country: country)
    }
}
