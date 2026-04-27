//
//  AppDestination.swift
//  FarmerChat
//
//  Type-safe routes — mirrors Android Destination (Kotlin Serialization).
//

import Foundation

enum AppDestination: Hashable {
    case splash
    case language
    case enterName
    case home
    case chat(
        entrySource: ChatEntrySource,
        question: String?,
        conversationId: String?,
        imageUri: String?,
        transcriptionId: String?,
        preGeneratedAnswer: String?,
        followUpQuestions: [String]?,
        homeStatementId: String?,
        isWeatherAdviceCTA: Bool
    )
    case chatHistory
    case settings
    case settingsName
    case settingsLanguage
    case help
    case accountBenefits
    case auth
    case accountSuccess
    case error(isNetworkError: Bool, fromScreen: String?)
    case legalContent(url: URL, title: String)

    /// Convenience: build chat destination (mirrors Android Destination.Chat). transcriptionId from transcribe_audio for voice flow.
    static func chat(
        question: String? = nil,
        conversationId: String? = nil,
        imageUri: String? = nil,
        transcriptionId: String? = nil,
        preGeneratedAnswer: String? = nil,
        followUpQuestions: [String]? = nil,
        homeStatementId: String? = nil,
        isWeatherAdviceCTA: Bool = false,
        entrySource: ChatEntrySource? = nil
    ) -> AppDestination {
        let source: ChatEntrySource = entrySource ?? (conversationId != nil ? .history : .home)
        return .chat(
            entrySource: source,
            question: question,
            conversationId: conversationId,
            imageUri: imageUri,
            transcriptionId: transcriptionId,
            preGeneratedAnswer: preGeneratedAnswer,
            followUpQuestions: followUpQuestions,
            homeStatementId: homeStatementId,
            isWeatherAdviceCTA: isWeatherAdviceCTA
        )
    }
}

enum ChatEntrySource: String, Hashable, Codable {
    case home
    case history
    case moengage
    case plotline
    case deeplink
}
