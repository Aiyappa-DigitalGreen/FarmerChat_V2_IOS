//
//  UpdateUserNameState.swift
//  FarmerChat
//
//  Sealed UI state for Enter Name / Settings Name (Android UpdateUserNameState parity).
//

import Foundation

enum UpdateUserNameState {
    case idle
    case loading
    case success(UserNameResponse)
    case error(String)
}
