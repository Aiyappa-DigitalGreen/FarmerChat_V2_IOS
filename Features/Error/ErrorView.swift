//
//  ErrorView.swift
//  FarmerChat
//
//  UI_ERROR.md §2 — NO_INTERNET / API_ERROR variants delegate to FullScreenMessage
//  (yellow Glow app bar, 300:450 pill illustration, 64pt PrimaryButton with
//  1500ms debounce on "Try again").
//

import SwiftUI

struct ErrorView: View {
    let isNetworkError: Bool
    let fromScreen: String?
    /// Full "Try again" handler — owns the §5 branch (offline-stays, skip-retry tokens,
    /// chathistory re-push, default pop+retry). Dismissal happens implicitly when the
    /// handler clears `ErrorNavigationManager.currentError`.
    let onTryAgain: () async -> Void

    private var title: String {
        isNetworkError ? "No internet connection" : "Something went wrong"
    }
    private var mainMessage: String {
        isNetworkError ? "FarmerChat needs\nthe internet" : "FarmerChat couldn't load"
    }
    private var subtitle: String {
        isNetworkError ? "Check mobile data or Wi-Fi signal" : "Please try again"
    }

    var body: some View {
        FullScreenMessage(
            title: title,
            mainMessage: mainMessage,
            subtitle: subtitle,
            primaryCtaLabel: "Try again",
            primaryCtaState: .chevron,
            onPrimaryCta: { Task { await onTryAgain() } },
            illustration: "farmer_looking_at_sky",
            enableDebounce: true
        )
    }
}
