//
//  LogoutRepository.swift
//  FarmerChat
//
//  Repository for logout (Android HistoryUseCase.logoutApp parity).
//

import Foundation

protocol LogoutRepositoryProtocol {
    func logout() async throws
}

final class LogoutRepository: LogoutRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func logout() async throws {
        _ = try await apiClient.logout()
    }
}
