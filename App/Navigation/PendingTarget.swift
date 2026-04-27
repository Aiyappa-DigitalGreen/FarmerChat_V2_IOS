//
//  PendingTarget.swift
//  FarmerChat
//
//  Post-onboarding deferred navigation target — mirrors Android `PendingTarget` sealed class
//  (SPLASH_SCREEN.md §4.2 / §5). Persisted as JSON under PreferenceKeys.pendingTarget so a
//  deep link captured at cold start survives onboarding screens before being consumed.
//

import Foundation

enum PendingTarget: Equatable {
    case home
    case chat(chatId: String)
    case chatQuery(question: String, source: String)
    case gps(action: String)
}

extension PendingTarget: Codable {
    private enum Kind: String, Codable {
        case home
        case chat
        case chatQuery = "chat_query"
        case gps
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case chatId = "chat_id"
        case question
        case source
        case action
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .home:
            try c.encode(Kind.home, forKey: .type)
        case .chat(let chatId):
            try c.encode(Kind.chat, forKey: .type)
            try c.encode(chatId, forKey: .chatId)
        case .chatQuery(let question, let source):
            try c.encode(Kind.chatQuery, forKey: .type)
            try c.encode(question, forKey: .question)
            try c.encode(source, forKey: .source)
        case .gps(let action):
            try c.encode(Kind.gps, forKey: .type)
            try c.encode(action, forKey: .action)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .home:
            self = .home
        case .chat:
            self = .chat(chatId: try c.decode(String.self, forKey: .chatId))
        case .chatQuery:
            self = .chatQuery(
                question: try c.decode(String.self, forKey: .question),
                source: try c.decode(String.self, forKey: .source)
            )
        case .gps:
            self = .gps(action: try c.decode(String.self, forKey: .action))
        }
    }
}
