//
//  ChatUseCase.swift
//  FarmerChat
//
//  Use case: new conversation, get answer, follow-ups, history, image analysis, TTS (Android parity).
//

import Foundation

final class ChatUseCase {
    private let repository: ChatRepositoryProtocol

    init(repository: ChatRepositoryProtocol = ChatRepository()) {
        self.repository = repository
    }

    func newConversation() async throws -> NewConversationResponse {
        try await repository.newConversation()
    }

    func getAnswerForTextQuery(conversationId: String, query: String, messageId: String, triggeredInputType: String, transcriptionId: String?, statementId: String?, weatherCtaTriggered: Bool) async throws -> TextPromptResponse {
        try await repository.getAnswerForTextQuery(conversationId: conversationId, query: query, messageId: messageId, triggeredInputType: triggeredInputType, transcriptionId: transcriptionId, statementId: statementId, weatherCtaTriggered: weatherCtaTriggered)
    }

    func followUpQuestions(messageId: String, useLatestPrompt: Bool) async throws -> FollowUpQuestionsResponse {
        try await repository.followUpQuestions(messageId: messageId, useLatestPrompt: useLatestPrompt)
    }

    func followUpQuestionClick(followUpQuestion: String) async throws {
        try await repository.followUpQuestionClick(followUpQuestion: followUpQuestion)
    }

    func synthesiseAudio(messageId: String, text: String, userId: String) async throws -> SynthesiseAudioResponse {
        try await repository.synthesiseAudio(messageId: messageId, text: text, userId: userId)
    }

    func transcribeAudio(conversationId: String, audioBase64: String, format: String) async throws -> GetVoiceResponse {
        let body = SetVoiceRequest(
            conversation_id: conversationId,
            query: audioBase64,
            message_reference_id: UUID().uuidString,
            input_audio_encoding_format: format,
            triggered_input_type: "voice"
        )
        return try await repository.transcribeAudio(body: body)
    }

    func imageAnalysis(conversationId: String, imageBase64: String, imageName: String, query: String?, latitude: String?, longitude: String?, retry: Bool) async throws -> PlantixResponse {
        try await repository.imageAnalysis(conversationId: conversationId, imageBase64: imageBase64, imageName: imageName, query: query, latitude: latitude, longitude: longitude, retry: retry)
    }

    func conversationChatHistory(conversationId: String, page: Int) async throws -> ConversationChatHistoryResponse {
        try await repository.conversationChatHistory(conversationId: conversationId, page: page)
    }

    /// Best-effort campaign hydration — CHAT_SCREEN.md §6.2. Errors are logged by the
    /// caller and never surface to the UI.
    func addQueryToHistory(conversationId: String, query: String, response: String, followUps: [String], triggeredInputType: String) async throws {
        let body = AddQueryToHistoryRequest(
            conversation_id: conversationId,
            query: query,
            response: response,
            follow_up_questions: followUps.map { FollowUpQuestionMessage(message: $0) },
            video_resources: [],
            triggered_input_type: triggeredInputType
        )
        try await repository.addQueryToHistory(body: body)
    }
}
