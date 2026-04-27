//
//  ChatHistoryUiState.swift
//  FarmerChat
//
//  Mirrors Android ChatHistoryUiState (sealed UI state). View observes via ViewModel @Published.
//

import Foundation

/// Sealed UI state for Chat History screen (Android parity).
enum ChatHistoryUiState {
    case idle
    case loading
    case success(
        items: [ConversationListItem],
        canLoadMore: Bool,
        page: Int
    )
    case error(message: String, isNetworkError: Bool)
}
