//
//  GetLanguageLabelsUseCase.swift
//  FarmerChat
//
//  Use case: get language labels (Android parity).
//

import Foundation

final class GetLanguageLabelsUseCase {
    private let repository: LanguageRepositoryProtocol

    init(repository: LanguageRepositoryProtocol = LanguageRepository()) {
        self.repository = repository
    }

    func execute(languageId: String) async throws -> [String: String] {
        try await repository.getLabels(languageId: languageId)
    }
}
