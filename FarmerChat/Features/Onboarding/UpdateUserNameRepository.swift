//
//  UpdateUserNameRepository.swift
//  FarmerChat
//
//  Repository for update user name (Enter Name & Settings Name parity).
//

import Foundation

protocol UpdateUserNameRepositoryProtocol {
    func updateUserName(name: String) async throws -> UserNameResponse
}

final class UpdateUserNameRepository: UpdateUserNameRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func updateUserName(name: String) async throws -> UserNameResponse {
        try await apiClient.updateUserProfile(name: name)
    }
}
