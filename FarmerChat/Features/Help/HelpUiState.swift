//
//  HelpUiState.swift
//  FarmerChat
//
//  Sealed UI state for Help screen (Android parity).
//

import Foundation

enum HelpUiState {
    case idle
    case loading
    case success(faqs: [FaqItem], legalLinks: [(title: String, url: String)])
    case error(String)
}
