//
//  HomeUseCase.swift
//  FarmerChat
//
//  Use case: home feed, weather, profile, new conversation, image statement (Android HomeUseCase parity).
//

import Foundation

final class HomeUseCase {
    private let repository: HomeRepositoryProtocol
    private let preferences: PreferencesManager

    init(
        repository: HomeRepositoryProtocol = HomeRepository(),
        preferences: PreferencesManager = .shared
    ) {
        self.repository = repository
        self.preferences = preferences
    }

    func getHomeFeed(userDeviceTime: String?, userId: String?) async throws -> HomeUdfResponse {
        try await repository.getDailyHomeSections(userDeviceTime: userDeviceTime, userId: userId)
    }

    func getWeather() async throws -> WeatherResponse {
        let uid = preferences.userId ?? ""
        guard !uid.isEmpty else { throw APIError.server(400, "user_id required for weather") }
        let lat = preferences.lastKnownLat
        let lng = preferences.lastKnownLng
        return try await repository.getWeather(lat: lat, lng: lng)
    }

    func newConversation() async throws -> NewConversationResponse {
        try await repository.newConversation()
    }

    func fetchUserProfile() async throws -> FarmerProfile {
        try await repository.viewUserProfile()
    }

    func markImageViewed(statementId: String, userId: String, status: String = "viewed") async throws {
        try await repository.markImageViewed(statementId: statementId, userId: userId, status: status)
    }

    func getImageStatement(statementId: String, triggeredInputType: String) async throws -> ImageStatementResponse {
        try await repository.getImageStatement(statementId: statementId, triggeredInputType: triggeredInputType)
    }

    func updateUserProfile(gender: String) async throws {
        try await repository.updateUserProfile(gender: gender)
    }

    func updateUserProfile(liveStockDetails: [LiveStockDetail]) async throws {
        try await repository.updateUserProfile(liveStockDetails: liveStockDetails)
    }

    func updateCropDetails(cropDetails: [String]) async throws -> UpdateCropDetailsResponse {
        try await repository.updateCropDetails(cropDetails: cropDetails)
    }

    /// Gate for AccountBenefits interstitial (AUTH_FLOW.md §0.3 / §6.1). When
    /// `bypass_interstitial` is true the UI should navigate straight to `.auth`;
    /// otherwise route to `.accountBenefits`. On thrown error, mirror Android and no-op.
    func getUserQuestionCount() async throws -> UserQuestionCountResponse {
        try await repository.getUserQuestionCount()
    }
}
