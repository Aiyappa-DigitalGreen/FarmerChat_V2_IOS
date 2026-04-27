//
//  UpdateUserNameUseCase.swift
//  FarmerChat
//
//  Use case: update user name (Android UpdateUserNameUseCase parity).
//

import Foundation

final class UpdateUserNameUseCase {
    private let repository: UpdateUserNameRepositoryProtocol
    private let preferences: PreferencesManager

    init(
        repository: UpdateUserNameRepositoryProtocol = UpdateUserNameRepository(),
        preferences: PreferencesManager = .shared
    ) {
        self.repository = repository
        self.preferences = preferences
    }

    func execute(name: String) async throws -> UserNameResponse {
        try await repository.updateUserName(name: name)
    }
}
