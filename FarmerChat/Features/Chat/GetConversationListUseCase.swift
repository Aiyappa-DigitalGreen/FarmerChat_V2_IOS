//
//  GetConversationListUseCase.swift
//  FarmerChat
//
//  Use case: get conversation list (Android HistoryUseCase.getConversationLists parity).
//

import Foundation

final class GetConversationListUseCase {
    private let repository: ChatHistoryRepositoryProtocol
    private let preferences: PreferencesManager

    init(
        repository: ChatHistoryRepositoryProtocol = ChatHistoryRepository(),
        preferences: PreferencesManager = .shared
    ) {
        self.repository = repository
        self.preferences = preferences
    }

    /// Reads userId from prefs; throws if blank (Android: "User Id is required").
    func execute(page: Int) async throws -> ConversationListResponse {
        let userId = preferences.userId ?? ""
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.server(400, "User Id is required")
        }
        return try await repository.getConversationLists(userId: userId, page: page)
    }
}
