//
//  Loadable.swift
//  FarmerChat
//
//  Generic loading state — mirrors Android UiState sealed class.
//

import Foundation

enum Loadable<T> {
    case idle
    case loading
    case success(T)
    case error(String)

    var value: T? {
        if case .success(let t) = self { return t }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}
