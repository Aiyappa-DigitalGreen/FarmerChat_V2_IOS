//
//  ChatRepository.swift
//  FarmerChat
//
//  Repository for chat: new conversation, get answer, follow-ups, history, image analysis, TTS (Android parity).
//

import Foundation

protocol ChatRepositoryProtocol {
    func newConversation() async throws -> NewConversationResponse
    func getAnswerForTextQuery(conversationId: String, query: String, messageId: String, triggeredInputType: String, transcriptionId: String?, statementId: String?, weatherCtaTriggered: Bool) async throws -> TextPromptResponse
    func followUpQuestions(messageId: String, useLatestPrompt: Bool) async throws -> FollowUpQuestionsResponse
    func followUpQuestionClick(followUpQuestion: String) async throws
    func synthesiseAudio(messageId: String, text: String, userId: String) async throws -> SynthesiseAudioResponse
    func transcribeAudio(body: SetVoiceRequest) async throws -> GetVoiceResponse
    func imageAnalysis(conversationId: String, imageBase64: String, imageName: String, query: String?, latitude: String?, longitude: String?, retry: Bool) async throws -> PlantixResponse
    func conversationChatHistory(conversationId: String, page: Int) async throws -> ConversationChatHistoryResponse
    func addQueryToHistory(body: AddQueryToHistoryRequest) async throws
}

final class ChatRepository: ChatRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func newConversation() async throws -> NewConversationResponse {
        try await apiClient.newConversation()
    }

    func getAnswerForTextQuery(conversationId: String, query: String, messageId: String, triggeredInputType: String, transcriptionId: String?, statementId: String?, weatherCtaTriggered: Bool) async throws -> TextPromptResponse {
        try await apiClient.getAnswerForTextQuery(conversationId: conversationId, query: query, messageId: messageId, triggeredInputType: triggeredInputType, transcriptionId: transcriptionId, statementId: statementId, weatherCtaTriggered: weatherCtaTriggered)
    }

    func followUpQuestions(messageId: String, useLatestPrompt: Bool) async throws -> FollowUpQuestionsResponse {
        try await apiClient.followUpQuestions(messageId: messageId, useLatestPrompt: useLatestPrompt)
    }

    func followUpQuestionClick(followUpQuestion: String) async throws {
        try await apiClient.followUpQuestionClick(followUpQuestion: followUpQuestion)
    }

    func synthesiseAudio(messageId: String, text: String, userId: String) async throws -> SynthesiseAudioResponse {
        try await apiClient.synthesiseAudio(messageId: messageId, text: text, userId: userId)
    }

    func transcribeAudio(body: SetVoiceRequest) async throws -> GetVoiceResponse {
        try await apiClient.transcribeAudio(body: body)
    }

    func imageAnalysis(conversationId: String, imageBase64: String, imageName: String, query: String?, latitude: String?, longitude: String?, retry: Bool) async throws -> PlantixResponse {
        try await apiClient.imageAnalysis(conversationId: conversationId, imageBase64: imageBase64, imageName: imageName, query: query, latitude: latitude, longitude: longitude, retry: retry)
    }

    func conversationChatHistory(conversationId: String, page: Int = 1) async throws -> ConversationChatHistoryResponse {
        try await apiClient.conversationChatHistory(conversationId: conversationId, page: page)
    }

    func addQueryToHistory(body: AddQueryToHistoryRequest) async throws {
        try await apiClient.addQueryToHistory(body: body)
    }
}
