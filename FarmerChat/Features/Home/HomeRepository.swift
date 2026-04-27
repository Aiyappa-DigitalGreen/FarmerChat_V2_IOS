//
//  HomeRepository.swift
//  FarmerChat
//
//  Repository for home feed, weather, profile, etc. (Android HomeRepository parity).
//

import Foundation

protocol HomeRepositoryProtocol {
    func getDailyHomeSections(userDeviceTime: String?, userId: String?) async throws -> HomeUdfResponse
    func getWeather(lat: Double?, lng: Double?) async throws -> WeatherResponse
    func newConversation() async throws -> NewConversationResponse
    func viewUserProfile() async throws -> FarmerProfile
    func markImageViewed(statementId: String, userId: String, status: String) async throws
    func getImageStatement(statementId: String, triggeredInputType: String) async throws -> ImageStatementResponse
    func updateUserProfile(gender: String) async throws
    func updateUserProfile(liveStockDetails: [LiveStockDetail]) async throws
    func updateCropDetails(cropDetails: [String]) async throws -> UpdateCropDetailsResponse
    func getUserQuestionCount() async throws -> UserQuestionCountResponse
}

final class HomeRepository: HomeRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getDailyHomeSections(userDeviceTime: String?, userId: String?) async throws -> HomeUdfResponse {
        try await apiClient.dailyContent(userDeviceTime: userDeviceTime, userId: userId)
    }

    func getWeather(lat: Double?, lng: Double?) async throws -> WeatherResponse {
        try await apiClient.weatherForecast(lat: lat, lng: lng)
    }

    func newConversation() async throws -> NewConversationResponse {
        try await apiClient.newConversation()
    }

    func viewUserProfile() async throws -> FarmerProfile {
        try await apiClient.viewUserProfile()
    }

    func markImageViewed(statementId: String, userId: String, status: String) async throws {
        _ = try await apiClient.markImageViewed(statementId: statementId, userId: userId, status: status)
    }

    func getImageStatement(statementId: String, triggeredInputType: String) async throws -> ImageStatementResponse {
        try await apiClient.imageStatement(statementId: statementId, triggeredInputType: triggeredInputType)
    }

    func updateUserProfile(gender: String) async throws {
        try await apiClient.updateUserProfile(gender: gender)
    }

    func updateUserProfile(liveStockDetails: [LiveStockDetail]) async throws {
        try await apiClient.updateUserProfile(liveStockDetails: liveStockDetails)
    }

    func updateCropDetails(cropDetails: [String]) async throws -> UpdateCropDetailsResponse {
        try await apiClient.updateCropDetails(cropDetails: cropDetails)
    }

    func getUserQuestionCount() async throws -> UserQuestionCountResponse {
        try await apiClient.userQuestionCount()
    }
}
