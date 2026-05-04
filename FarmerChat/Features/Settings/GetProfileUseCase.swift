//
//  GetProfileUseCase.swift
//  FarmerChat
//
//  Use case: fetch user profile (Settings / UserProfileViewModel parity).
//

import Foundation

final class GetProfileUseCase {
    private let repository: UserProfileRepositoryProtocol

    init(repository: UserProfileRepositoryProtocol = UserProfileRepository()) {
        self.repository = repository
    }

    func execute() async throws -> FarmerProfile {
        try await repository.viewUserProfile()
    }
}
