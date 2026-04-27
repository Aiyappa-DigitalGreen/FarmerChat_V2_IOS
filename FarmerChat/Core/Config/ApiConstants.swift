//
//  ApiConstants.swift
//  FarmerChat
//
//  API paths and headers per API_KEYS_AND_CONFIG.md (Android ApiConstants.kt).
//

import Foundation

enum ApiConstants {
    // MARK: - Paths (relative to BASE_URL)

    static let authRefresh = "api/user/get_new_access_token/"
    static let initializeGuestUser = "api/user/initialize_user/"
    static let getCountryWiseSupportedLanguages = "api/language/v2/country_wise_supported_languages/"
    static let getLanguageLabels = "api/language/v2/get_labels/"
    static let getPrivacyPolicy = "api/user/privacy_policy/"
    static let postSetPreferredLanguage = "api/user/set_preferred_language/"
    static let acceptPpAndTc = "api/user/accept_terms/"
    static let updateUserName = "api/user/update_user_profile/"
    static let updateCropDetails = "api/user/update_crop_details/"
    static let getUserProfile = "api/user/view_user_profile/"
    static let updateUserLocation = "api/user/update_user_location/"
    static let home = "api/images/v2/daily/"
    static let weather = "api/weather/v2/weather_forecast_lite/"
    static let newConversation = "api/chat/new_conversation/"
    static let getConversationList = "api/chat/conversation_list/"
    static let postLogoutApp = "api/user/logout/"
    static let getHelpSupport = "api/faqs/"
    static let sendOtp = "api/user/generate_otp/"
    static let verifyOtp = "api/user/verify_otp/"
    static let getAllCountries = "api/geography/get_all_countries/"
    static let getCommunicationChannel = "api/geography/communication_channel/"
    static let getTextPrompt = "api/chat/get_answer_for_text_query/"
    static let getChatHistory = "api/chat/conversation_chat_history/"
    static let transcribeAudio = "api/chat/transcribe_audio/"
    static let followUpQuestions = "api/chat/follow_up_questions/"
    static let imageAnalysis = "api/chat/image_analysis/"
    static let imageStatement = "api/images/v2/statement/"
    static let imageViewed = "api/images/v2/viewed/"
    static let followUpQuestionClick = "api/chat/follow_up_question_click/"
    static let synthesiseAudio = "api/chat/synthesise_audio/"
    static let addQueryToHistory = "api/chat/add_query_to_history/"

    // MARK: - Headers

    static let headerAuth = "Authorization"
    static let headerLanguage = "Accept-Language"
    static let headerApiKey = "API-Key"

    // MARK: - Timeouts (seconds)

    static let connectTimeout: TimeInterval = 15
    static let readTimeout: TimeInterval = 30
    static let writeTimeout: TimeInterval = 30
}
