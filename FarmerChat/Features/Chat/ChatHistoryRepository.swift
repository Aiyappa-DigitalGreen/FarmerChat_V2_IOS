//
//  ChatHistoryRepository.swift
//  FarmerChat
//
//  Repository for conversation list (Android HistoryRepository parity).
//

import Foundation

protocol ChatHistoryRepositoryProtocol {
    func getConversationLists(userId: String, page: Int) async throws -> ConversationListResponse
}

final class ChatHistoryRepository: ChatHistoryRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getConversationLists(userId: String, page: Int) async throws -> ConversationListResponse {
        try await apiClient.conversationList(page: page)
    }
}
