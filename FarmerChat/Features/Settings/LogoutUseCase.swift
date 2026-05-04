//
//  LogoutUseCase.swift
//  FarmerChat
//
//  Use case: logout app (Android HistoryUseCase.logoutApp parity).
//

import Foundation

final class LogoutUseCase {
    private let repository: LogoutRepositoryProtocol

    init(repository: LogoutRepositoryProtocol = LogoutRepository()) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.logout()
    }
}
