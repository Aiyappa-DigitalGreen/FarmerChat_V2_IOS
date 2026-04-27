//
//  ErrorNavigationManager.swift
//  FarmerChat
//
//  Global error coordinator — Android parity.
//
//  Android moved from SharedFlow(replay=0) to Channel(BUFFERED) to fix a race
//  where events emitted before the collector subscribed were silently dropped.
//  iOS mirrors that with an AsyncStream whose continuation buffers unboundedly,
//  so late subscribers still receive events that fired before they attached.
//
//  Two consumer styles are supported:
//    • SwiftUI views bind to `currentError` (@Published) — unchanged contract.
//    • Async consumers (Splash, screen observers) iterate `events` to replay
//      the full buffered history.
//

import Foundation
import Combine

struct ErrorEvent {
    let isNetworkError: Bool
    /// Normalized (lowercase + trimmed) screen token. Raw input is preserved
    /// at emit time but comparisons should use this form.
    let fromScreen: String?
    let retry: () async -> Void
}

final class ErrorNavigationManager: ObservableObject {
    static let shared = ErrorNavigationManager()

    @Published private(set) var currentError: ErrorEvent?

    /// True while an error is pending presentation. Splash uses this to gate
    /// auto-routing after initial config fetch.
    var hasPendingError: Bool { currentError != nil }

    /// The screen currently on top of the nav stack. Set by each screen's
    /// `onAppear`; used as a stale-event guard so an in-flight API failure
    /// from a screen the user already left cannot hijack the current one.
    private(set) var activeScreen: String?

    /// Buffered async stream for consumers that subscribe after emission.
    /// Bounded only by memory; errors are small structs so in practice
    /// unbounded is fine.
    private var streamContinuation: AsyncStream<ErrorEvent>.Continuation?
    let events: AsyncStream<ErrorEvent>

    private init() {
        var cont: AsyncStream<ErrorEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { c in cont = c }
        self.streamContinuation = cont
    }

    func setActiveScreen(_ token: String?) {
        activeScreen = Self.normalize(token)
    }

    func emit(isNetworkError: Bool, fromScreen: String? = nil, retry: @escaping () async -> Void) {
        let normalized = Self.normalize(fromScreen)
        // Stale-event guard: if the user has navigated to a different screen
        // since this request was kicked off, drop silently rather than
        // hijacking the current screen with an unrelated error.
        if let active = activeScreen, let src = normalized, active != src {
            return
        }
        let event = ErrorEvent(isNetworkError: isNetworkError, fromScreen: normalized, retry: retry)
        currentError = event
        streamContinuation?.yield(event)
    }

    func clear() {
        currentError = nil
    }

    func retryLastAction() async {
        guard let err = currentError else { return }
        clear()
        await err.retry()
    }

    private static func normalize(_ token: String?) -> String? {
        guard let s = token?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !s.isEmpty else { return nil }
        return s
    }
}
