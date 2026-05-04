//
//  PendingPreGeneratedContent.swift
//  FarmerChat
//
//  Sidecar to `PendingTarget` for `notification_type=qapair` payloads
//  (SPLASH_SCREEN.md §5.4). Holds the pre-generated answer + follow-ups so
//  the Chat screen can render them directly, skipping the chat API. The
//  `PendingTarget` itself stays shape-minimal (`.chatQuery`) — this store
//  carries the bulky strings separately.
//

import Foundation

struct PendingPreGeneratedContent: Codable, Equatable {
    let question: String
    let response: String
    let followUps: [String]
    let source: String
}

final class PendingPreGeneratedContentStore {
    static let shared = PendingPreGeneratedContentStore()

    private let defaults: UserDefaults
    private let key = PreferenceKeys.pendingPreGeneratedContent

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ content: PendingPreGeneratedContent) {
        guard let data = try? JSONEncoder().encode(content) else { return }
        defaults.set(data, forKey: key)
    }

    /// Returns the content without clearing it. Use when the Chat screen
    /// wants to check for pre-gen content without committing to consumption
    /// (e.g., it may still bail out before rendering).
    func peek() -> PendingPreGeneratedContent? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PendingPreGeneratedContent.self, from: data)
    }

    /// Reads and clears the stored content in one shot.
    @discardableResult
    func consume() -> PendingPreGeneratedContent? {
        let current = peek()
        if current != nil { defaults.removeObject(forKey: key) }
        return current
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
