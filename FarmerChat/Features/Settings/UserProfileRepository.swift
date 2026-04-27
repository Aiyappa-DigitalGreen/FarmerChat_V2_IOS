//
//  UserProfileRepository.swift
//  FarmerChat
//
//  Repository for view user profile (Settings parity).
//

import Foundation

protocol UserProfileRepositoryProtocol {
    func viewUserProfile() async throws -> FarmerProfile
}

final class UserProfileRepository: UserProfileRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func viewUserProfile() async throws -> FarmerProfile {
        try await apiClient.viewUserProfile()
    }
}
