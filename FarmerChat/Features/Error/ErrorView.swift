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
        isNetworkError ? PreferencesManager.shared.label("fc_v2_app_label_no_internet_connection", fallback: "No internet connection") : PreferencesManager.shared.label("fc_v2_app_label_something_went_wrong", fallback: "Something went wrong")
    }
    private var mainMessage: String {
        isNetworkError ? PreferencesManager.shared.label("fc_v2_app_label_farmerchat_needs_the_internet", fallback: "FarmerChat needs\nthe internet") : PreferencesManager.shared.label("fc_v2_app_label_farmerchat_couldnt_load", fallback: "FarmerChat couldn't load")
    }
    private var subtitle: String {
        isNetworkError ? PreferencesManager.shared.label("fc_v2_app_label_check_mobile_data_wi-fi_signal", fallback: "Check mobile data or Wi-Fi signal") : PreferencesManager.shared.label("fc_v2_app_label_please_try_again", fallback: "Please try again")
    }

    var body: some View {
        FullScreenMessage(
            title: title,
            mainMessage: mainMessage,
            subtitle: subtitle,
            primaryCtaLabel: PreferencesManager.shared.label("fc_v2_app_label_try_again", fallback: "Try again"),
            primaryCtaState: .chevron,
            onPrimaryCta: { Task { await onTryAgain() } },
            illustration: "farmer_looking_at_sky",
            enableDebounce: true
        )
    }
}
