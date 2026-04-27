//
//  APIModels.swift
//  FarmerChat
//
//  Codable request/response models per API_Models_Kotlin_to_Swift_Codable.md.
//

import Foundation

// MARK: - 1. Auth Module

struct CountryItem: Codable, Identifiable {
    let code: String
    let display_name: String
    let flag: String
    let id: Int
    let name: String
    let phone_country_code: String
    let phone_length: Int
    let phone_number_pattern: String?
}

struct GetOtpModeResponseItem: Codable {
    let sms_enabled: Bool?
    let whatsapp_enabled: Bool?
}

struct LogoutResponse: Codable {
    let message: String?
}

struct SendOtpRequest: Codable {
    let phone: String
    let phone_country_code: String
    let channel: [String]
    let device_id: String
    let user_id: String
}

struct SendOtpResponse: Codable {
    let message: String?
    let detail: String?
    let phone: String?
    let phone_country_code: String?
    let device_id: String?
    let otp: String?
    let user_id: String?
}

struct VerifyOtpRequest: Codable {
    let otp: String
    let phone: String
    let phone_country_code: String
    let guest_onboarding: String
    let user_id: String
}

/// Some backends return verify_otp success as { "data": { "access_token": ..., "id": ... } }.
struct VerifyOtpDataWrapper: Codable {
    let data: VerifyOtpResponse
}

struct PreferredLanguage: Codable {
    let asr_bcp_code: String?
    let asr_enabled: Bool?
    let asr_inference_model: AnyCodable?
    let asr_service_provider: String?
    let code: String?
    let created_by: AnyCodable?
    let created_on: String?
    let display_name: String?
    let id: Int?
    let is_active: Bool?
    let is_deleted: Bool?
    let latn_code: String?
    let name: String?
    let primary_speaking_countries: [String]?
    let translation_inference_model: AnyCodable?
    let translation_service_provider: String?
    let tts_bcp_code: String?
    let tts_enabled: Bool?
    let tts_inference_model: AnyCodable?
    let tts_service_provider: String?
    let tts_voice_name: AnyCodable?
    let updated_by: AnyCodable?
    let updated_on: String?
}

struct VerifyOtpResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let crop_selection_enabled: Bool?
    let crop_id: Int?
    let id: String?
    let phone: String?
    let email: String?
    let role: String?
    let phone_country_code: String?
    let message: String?
    let otp: String?
    let preferred_language: PreferredLanguage?
    let lat: String?
    let existing_user: Bool?
    let name: String?
    /// When true, backend indicates verification failed (e.g. invalid OTP) even with 200.
    let error: Bool?
    /// Error detail from backend (e.g. "Invalid OTP").
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case access_token, refresh_token, crop_selection_enabled, crop_id, phone, email, role
        case phone_country_code, message, otp, preferred_language, lat, existing_user, name
        case id
        case error
        case detail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try c.decodeIfPresent(String.self, forKey: .access_token)
        refresh_token = try c.decodeIfPresent(String.self, forKey: .refresh_token)
        crop_selection_enabled = try c.decodeIfPresent(Bool.self, forKey: .crop_selection_enabled)
        crop_id = try c.decodeIfPresent(Int.self, forKey: .crop_id)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        phone_country_code = try c.decodeIfPresent(String.self, forKey: .phone_country_code)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        otp = try c.decodeIfPresent(String.self, forKey: .otp)
        preferred_language = try c.decodeIfPresent(PreferredLanguage.self, forKey: .preferred_language)
        lat = try c.decodeIfPresent(String.self, forKey: .lat)
        existing_user = try c.decodeIfPresent(Bool.self, forKey: .existing_user)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        error = try c.decodeIfPresent(Bool.self, forKey: .error)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        // Backend may return id as Int or String.
        if let s = try c.decodeIfPresent(String.self, forKey: .id) {
            id = s
        } else if let i = try c.decodeIfPresent(Int.self, forKey: .id) {
            id = "\(i)"
        } else {
            id = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(access_token, forKey: .access_token)
        try c.encodeIfPresent(refresh_token, forKey: .refresh_token)
        try c.encodeIfPresent(crop_selection_enabled, forKey: .crop_selection_enabled)
        try c.encodeIfPresent(crop_id, forKey: .crop_id)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(phone_country_code, forKey: .phone_country_code)
        try c.encodeIfPresent(message, forKey: .message)
        try c.encodeIfPresent(otp, forKey: .otp)
        try c.encodeIfPresent(preferred_language, forKey: .preferred_language)
        try c.encodeIfPresent(lat, forKey: .lat)
        try c.encodeIfPresent(existing_user, forKey: .existing_user)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(error, forKey: .error)
        try c.encodeIfPresent(detail, forKey: .detail)
    }
}

struct WhatsappVerificationRequest: Codable {
    let phone_country_code: String
    let phone: String
    let token: String
}

struct CheckDeviceRequest: Codable {
    let device_id: String
    let phone: String
    let phone_country_code: String
}

// MARK: - 2. Chat Module

struct TextPromptRequest: Codable {
    let query: String
    let conversation_id: String
    let message_id: String
    let weather_cta_triggered: Bool
    let triggered_input_type: String
    let ssfr_crop: String?
    let use_entity_extraction: Bool
    let transcription_id: String?
    let retry: Bool
    /// From Home card "Read full advice"; sent as statement_id in get_answer_for_text_query.
    let statement_id: String?
    /// Optional ISO country code (e.g. "IN"). Used for guest flows when backend can't infer country from profile.
    let country_code: String?

    enum CodingKeys: String, CodingKey {
        case query, conversation_id, message_id, weather_cta_triggered, triggered_input_type
        case ssfr_crop, use_entity_extraction, transcription_id, retry, statement_id
        case country_code
    }

    init(query: String, conversation_id: String, message_id: String, weather_cta_triggered: Bool = false,
         triggered_input_type: String, ssfr_crop: String? = nil, use_entity_extraction: Bool = true,
         transcription_id: String? = nil, retry: Bool = false, statement_id: String? = nil, country_code: String? = nil) {
        self.query = query
        self.conversation_id = conversation_id
        self.message_id = message_id
        self.weather_cta_triggered = weather_cta_triggered
        self.triggered_input_type = triggered_input_type
        self.ssfr_crop = ssfr_crop
        self.use_entity_extraction = use_entity_extraction
        self.transcription_id = transcription_id
        self.retry = retry
        self.statement_id = statement_id
        self.country_code = country_code
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        query = try c.decode(String.self, forKey: .query)
        conversation_id = try c.decode(String.self, forKey: .conversation_id)
        message_id = try c.decode(String.self, forKey: .message_id)
        weather_cta_triggered = try c.decode(Bool.self, forKey: .weather_cta_triggered)
        triggered_input_type = try c.decode(String.self, forKey: .triggered_input_type)
        ssfr_crop = try c.decodeIfPresent(String.self, forKey: .ssfr_crop)
        use_entity_extraction = try c.decode(Bool.self, forKey: .use_entity_extraction)
        transcription_id = try c.decodeIfPresent(String.self, forKey: .transcription_id)
        retry = try c.decode(Bool.self, forKey: .retry)
        statement_id = try c.decodeIfPresent(String.self, forKey: .statement_id)
        country_code = try c.decodeIfPresent(String.self, forKey: .country_code)
    }

    /// Encode only non-nil optionals so request matches backend expectation (no null keys for optional fields).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(conversation_id, forKey: .conversation_id)
        try c.encode(message_id, forKey: .message_id)
        try c.encode(query, forKey: .query)
        try c.encode(retry, forKey: .retry)
        try c.encode(triggered_input_type, forKey: .triggered_input_type)
        try c.encode(use_entity_extraction, forKey: .use_entity_extraction)
        try c.encode(weather_cta_triggered, forKey: .weather_cta_triggered)
        try c.encodeIfPresent(ssfr_crop, forKey: .ssfr_crop)
        try c.encodeIfPresent(transcription_id, forKey: .transcription_id)
        try c.encodeIfPresent(statement_id, forKey: .statement_id)
        try c.encodeIfPresent(country_code, forKey: .country_code)
    }
}

/// Response for get_answer_for_text_query. Fields optional so decoding succeeds when stage API omits or nulls them.
struct TextPromptResponse: Codable {
    let error: Bool?
    let message: String?
    let message_id: String?
    let query: String?
    let response: String?
    let resource_url: String?
    let resource_id: String?
    let translated_response: String?
    let follow_up_questions: [FollowUpQuestionOption]?
    let section_message_id: String?
    let actual_content_provider: String?
    let content_provider_logo: String?
    let hide_feedback_icons: Bool?
    let hide_follow_up_question: Bool?
    let hide_share_icon: Bool?
    let hide_tts_speaker: Bool?
    let hide_source: Bool?
    let points: Int?
    let intent_classification_output: IntentClassificationOutput?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error = try c.decodeIfPresent(Bool.self, forKey: .error)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        message_id = try c.decodeIfPresent(String.self, forKey: .message_id)
        query = try c.decodeIfPresent(String.self, forKey: .query)
        response = try c.decodeIfPresent(String.self, forKey: .response)
        resource_url = try c.decodeIfPresent(String.self, forKey: .resource_url)
        resource_id = try c.decodeIfPresent(String.self, forKey: .resource_id)
        translated_response = try c.decodeIfPresent(String.self, forKey: .translated_response)
        follow_up_questions = try c.decodeIfPresent([FollowUpQuestionOption].self, forKey: .follow_up_questions)
        section_message_id = try c.decodeIfPresent(String.self, forKey: .section_message_id)
        actual_content_provider = try c.decodeIfPresent(String.self, forKey: .actual_content_provider)
        content_provider_logo = try c.decodeIfPresent(String.self, forKey: .content_provider_logo)
        hide_feedback_icons = try c.decodeIfPresent(Bool.self, forKey: .hide_feedback_icons)
        hide_follow_up_question = try c.decodeIfPresent(Bool.self, forKey: .hide_follow_up_question)
        hide_share_icon = try c.decodeIfPresent(Bool.self, forKey: .hide_share_icon)
        hide_tts_speaker = try c.decodeIfPresent(Bool.self, forKey: .hide_tts_speaker)
        hide_source = try c.decodeIfPresent(Bool.self, forKey: .hide_source)
        points = (try? c.decodeIfPresent(Int.self, forKey: .points))
            ?? (try? c.decodeIfPresent(String.self, forKey: .points)).flatMap { Int($0) }
        intent_classification_output = (try? c.decodeIfPresent(IntentClassificationOutput.self, forKey: .intent_classification_output)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(error, forKey: .error)
        try c.encodeIfPresent(message, forKey: .message)
        try c.encodeIfPresent(message_id, forKey: .message_id)
        try c.encodeIfPresent(query, forKey: .query)
        try c.encodeIfPresent(response, forKey: .response)
        try c.encodeIfPresent(resource_url, forKey: .resource_url)
        try c.encodeIfPresent(resource_id, forKey: .resource_id)
        try c.encodeIfPresent(translated_response, forKey: .translated_response)
        try c.encodeIfPresent(follow_up_questions, forKey: .follow_up_questions)
        try c.encodeIfPresent(section_message_id, forKey: .section_message_id)
        try c.encodeIfPresent(actual_content_provider, forKey: .actual_content_provider)
        try c.encodeIfPresent(content_provider_logo, forKey: .content_provider_logo)
        try c.encodeIfPresent(hide_feedback_icons, forKey: .hide_feedback_icons)
        try c.encodeIfPresent(hide_follow_up_question, forKey: .hide_follow_up_question)
        try c.encodeIfPresent(hide_share_icon, forKey: .hide_share_icon)
        try c.encodeIfPresent(hide_tts_speaker, forKey: .hide_tts_speaker)
        try c.encodeIfPresent(hide_source, forKey: .hide_source)
        try c.encodeIfPresent(points, forKey: .points)
        try c.encodeIfPresent(intent_classification_output, forKey: .intent_classification_output)
    }

    /// Minimal init for fallback when full JSON decode fails (e.g. unexpected types from backend).
    init(response: String?, message_id: String?, translated_response: String? = nil, follow_up_questions: [FollowUpQuestionOption]? = nil) {
        self.error = nil
        self.message = nil
        self.message_id = message_id
        self.query = nil
        self.response = response
        self.resource_url = nil
        self.resource_id = nil
        self.translated_response = translated_response
        self.follow_up_questions = follow_up_questions
        self.section_message_id = nil
        self.actual_content_provider = nil
        self.content_provider_logo = nil
        self.hide_feedback_icons = nil
        self.hide_follow_up_question = nil
        self.hide_share_icon = nil
        self.hide_tts_speaker = nil
        self.hide_source = nil
        self.points = nil
        self.intent_classification_output = nil
    }

    private enum CodingKeys: String, CodingKey {
        case error, message, message_id, query, response, resource_url, resource_id, translated_response
        case follow_up_questions, section_message_id, actual_content_provider, content_provider_logo
        case hide_feedback_icons, hide_follow_up_question, hide_share_icon, hide_tts_speaker, hide_source, points
        case intent_classification_output
    }
}

struct IntentClassificationOutput: Codable {
    let asset_name: String?
    let asset_status: String?
    let asset_type: String?
    let clarification_needed: ClarificationNeeded?
    let concern: String?
    let confidence: String?
    /// Backend may send "intent" as String ("False") or Bool (false); decode both so we never fail the parent response.
    let intent: String?
    let likely_activity: String?
    let rephrased_query: String?
    let seasonal_relevance: String?
    let stage: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        asset_name = try c.decodeIfPresent(String.self, forKey: .asset_name)
        asset_status = try c.decodeIfPresent(String.self, forKey: .asset_status)
        asset_type = try c.decodeIfPresent(String.self, forKey: .asset_type)
        clarification_needed = try c.decodeIfPresent(ClarificationNeeded.self, forKey: .clarification_needed)
        concern = try c.decodeIfPresent(String.self, forKey: .concern)
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence)
        if let s = try? c.decodeIfPresent(String.self, forKey: .intent) {
            intent = s
        } else if let b = try? c.decodeIfPresent(Bool.self, forKey: .intent) {
            intent = b ? "true" : "false"
        } else {
            intent = nil
        }
        likely_activity = try c.decodeIfPresent(String.self, forKey: .likely_activity)
        rephrased_query = try c.decodeIfPresent(String.self, forKey: .rephrased_query)
        seasonal_relevance = try c.decodeIfPresent(String.self, forKey: .seasonal_relevance)
        stage = try c.decodeIfPresent(String.self, forKey: .stage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(asset_name, forKey: .asset_name)
        try c.encodeIfPresent(asset_status, forKey: .asset_status)
        try c.encodeIfPresent(asset_type, forKey: .asset_type)
        try c.encodeIfPresent(clarification_needed, forKey: .clarification_needed)
        try c.encodeIfPresent(concern, forKey: .concern)
        try c.encodeIfPresent(confidence, forKey: .confidence)
        try c.encodeIfPresent(intent, forKey: .intent)
        try c.encodeIfPresent(likely_activity, forKey: .likely_activity)
        try c.encodeIfPresent(rephrased_query, forKey: .rephrased_query)
        try c.encodeIfPresent(seasonal_relevance, forKey: .seasonal_relevance)
        try c.encodeIfPresent(stage, forKey: .stage)
    }

    private enum CodingKeys: String, CodingKey {
        case asset_name, asset_status, asset_type, clarification_needed, concern, confidence
        case intent, likely_activity, rephrased_query, seasonal_relevance, stage
    }
}

struct ClarificationNeeded: Codable {
    let additional_context: String?
    let asset: Bool?
    let concern: Bool?
}

struct FollowUpQuestionOption: Codable {
    let follow_up_question_id: String?
    let sequence: Int?
    let question: String?
}

struct PlantixRequest: Codable {
    let conversation_id: String
    let image: String
    let triggered_input_type: String
    let query: String?
    let latitude: String?
    let longitude: String?
    let image_name: String
    let retry: Bool

    init(conversation_id: String, image: String, triggered_input_type: String = "image",
         query: String? = nil, latitude: String? = nil, longitude: String? = nil,
         image_name: String, retry: Bool = false) {
        self.conversation_id = conversation_id
        self.image = image
        self.triggered_input_type = triggered_input_type
        self.query = query
        self.latitude = latitude
        self.longitude = longitude
        self.image_name = image_name
        self.retry = retry
    }
}

struct PlantixResponse: Codable {
    let audio: String?
    let error: Bool
    let hide_tts_speaker: Bool?
    let message: String
    let message_id: String
    let response: String
    let section_message_id: String
    let actual_content_provider: String?
    let content_provider_logo: String?
    let points: Int?
    let follow_up_questions: [FollowUpQuestionOption]?
}

struct SynthesiseAudioRequest: Codable {
    let message_id: String
    let text: String
    let user_id: String
}

struct SynthesiseAudioResponse: Codable {
    let message: String?
    let error: Bool
    let audio: String?
    let text: String?
    let section_message_id: String?
}

struct FollowUpQuestionClickRequest: Codable {
    let follow_up_question: String
}

struct FollowUpQuestionClickResponse: Codable {
    let message: String?
}

/// Follow-up payload shape used by add_query_to_history. Distinct from
/// FollowUpQuestionOption — the Moengage/campaign flow uses `{message}` only.
struct FollowUpQuestionMessage: Codable {
    let message: String?
}

/// Video resource payload for add_query_to_history. Kept minimal — campaign flow
/// currently sends `[]` so the nullable fields mirror Android's data class.
struct VideoResourceMessage: Codable {
    let resource_string: String?
    let resource_type: String?
}

/// POST api/chat/add_query_to_history/ – Plotline/MoEngage QAPair (per HOME_AND_CHAT_COMPLETE_APIS.md).
struct AddQueryToHistoryRequest: Codable {
    let conversation_id: String?
    let query: String?
    let response: String?
    let follow_up_questions: [FollowUpQuestionMessage]?
    let video_resources: [VideoResourceMessage]?
    let triggered_input_type: String?
}

struct FollowUpQuestionsResponse: Codable {
    let message_id: String
    let questions: [Question]?
    /// Optional so decoding succeeds if API omits or nulls it.
    let section_message_id: String?
}

struct Question: Codable {
    let follow_up_question_id: String
    let question: String
    let sequence: Int
}

struct ConversationChatHistoryResponse: Codable {
    let conversation_id: String
    let data: [ConversationChatHistoryMessageItem]
}

struct ConversationChatHistoryQuestion: Codable {
    let follow_up_question_id: String
    let sequence: Int
    let question: String
}

struct ConversationChatHistoryMessageItem: Codable {
    let message_type_id: Int
    let message_type: String
    let message_id: String
    let message_input_time: String?
    let section_message_id: String?
    let query_text: String?
    let heard_query_text: String?
    let response_text: String?
    let questions: [ConversationChatHistoryQuestion]?
    let query_media_file_url: String?
    let reaction: String?
    let response_media_file_url: String?
    let resource_id: String?
    let resource_url: String?
    let actual_content_provider: String?
    let content_provider_logo: String?
    let hide_source: Bool?
    let hide_tts_speaker: Bool?
}

struct ChatHistoryRequest: Codable {
    let conversation_id: String
    let page: Int
    init(conversation_id: String, page: Int = 1) {
        self.conversation_id = conversation_id
        self.page = page
    }
}

struct ChatHistoryResponse: Codable {
    let conversation_id: String
    let messages: [ChatHistoryMessage]
}

struct ChatHistoryMessage: Codable {
    let id: String
    let type: String
    let content: String
    let audio_uri: String?
    let image_uri: String?
    let timestamp: String?
    let follow_up_questions: [String]?
}

// MARK: - 3. Conversation Module

/// Request for new_conversation (per QUERY_FLOW_AND_APIS.md).
struct NewConversationRequest: Codable {
    let user_id: String
    let content_provider_id: String?

    enum CodingKeys: String, CodingKey { case user_id, content_provider_id }

    init(user_id: String, content_provider_id: String? = nil) {
        self.user_id = user_id
        self.content_provider_id = content_provider_id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try c.decode(String.self, forKey: .user_id)
        content_provider_id = try c.decodeIfPresent(String.self, forKey: .content_provider_id)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id, forKey: .user_id)
        try c.encodeIfPresent(content_provider_id, forKey: .content_provider_id)
    }
}

struct NewConversationResponse: Codable {
    let conversation_id: String
    let message: String?
    let show_popup: Bool?
}

// MARK: - 4. Crops Module

struct SetCultivatedCropsRequest: Codable {
    let crop_ids: [String]
}

/// API: update_crop_details
struct UpdateCropDetailsRequest: Codable {
    let user_id: String
    let crop_details: [String]
}

struct UpdateCropDetailsResponse: Codable {
    let message: String?
}

struct CropResponse: Codable {
    let id: String
    let text: String
}

// MARK: - 5. Geolocation Module

struct GeoRequestBody: Codable {
    let lat: Double
    let long: Double
}

struct GeoResponse: Codable {
    let display_name: String?
    let address: GeoLocation?
}

struct GeoLocation: Codable {
    let village: String?
    let state_district: String?
    let state: String?
    let postcode: String?
    let country: String?
    let country_code: String?
}

// MARK: - 6. Help Module
// Backend can return either { "status", "data": { "faqs", "legal" } } or flat { "faq", "legal" }.

struct HelpSupportResponse: Decodable {
    let status: String?
    let data: HelpSupportData?
    /// Legacy flat keys (if backend returns faq/legal at top level).
    let faq: [FaqItem]?
    let legal: HelpLegal?
    let support: HelpSupportData?
    /// Resolved FAQs from either data.faqs or faq.
    var faqs: [FaqItem] { data?.faqs ?? faq ?? [] }
    /// Resolved legal from either data.legal or legal.
    var legalResolved: HelpLegal? { data?.legal ?? legal }
}

struct HelpSupportData: Decodable {
    let faqs: [FaqItem]?
    let legal: HelpLegal?
    let webview_url: String?
    let open_mode: String?
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

struct FaqItem: Decodable {
    let id: String?
    let title: String?
    let question: String?
    let answer: String?
    /// URL to open in WebView for full HTML content from API.
    let webview_url: String?
    let open_mode: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        func key(_ s: String) -> DynamicCodingKey { DynamicCodingKey(stringValue: s)! }

        id = try? c.decodeIfPresent(String.self, forKey: key("id"))
        title = try? c.decodeIfPresent(String.self, forKey: key("title"))
        question = try? c.decodeIfPresent(String.self, forKey: key("question"))
        answer = try? c.decodeIfPresent(String.self, forKey: key("answer"))
        webview_url =
            (try? c.decodeIfPresent(String.self, forKey: key("webview_url")))
            ?? (try? c.decodeIfPresent(String.self, forKey: key("webview-url")))
        open_mode =
            (try? c.decodeIfPresent(String.self, forKey: key("open_mode")))
            ?? (try? c.decodeIfPresent(String.self, forKey: key("open-mode")))
    }
}

struct HelpLegal: Decodable {
    let privacy_policy: HelpWebLink?
    let terms_of_use: HelpWebLink?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        func key(_ s: String) -> DynamicCodingKey { DynamicCodingKey(stringValue: s)! }

        privacy_policy =
            (try? c.decodeIfPresent(HelpWebLink.self, forKey: key("privacy_policy")))
            ?? (try? c.decodeIfPresent(HelpWebLink.self, forKey: key("privacy-policy")))
        terms_of_use =
            (try? c.decodeIfPresent(HelpWebLink.self, forKey: key("terms_of_use")))
            ?? (try? c.decodeIfPresent(HelpWebLink.self, forKey: key("terms-of-use")))
    }
}

struct HelpWebLink: Decodable {
    let title: String?
    let webview_url: String?
    let open_mode: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        func key(_ s: String) -> DynamicCodingKey { DynamicCodingKey(stringValue: s)! }

        title = try? c.decodeIfPresent(String.self, forKey: key("title"))
        webview_url =
            (try? c.decodeIfPresent(String.self, forKey: key("webview_url")))
            ?? (try? c.decodeIfPresent(String.self, forKey: key("webview-url")))
        open_mode =
            (try? c.decodeIfPresent(String.self, forKey: key("open_mode")))
            ?? (try? c.decodeIfPresent(String.self, forKey: key("open-mode")))
    }
}

// MARK: - 7. History Module

struct ConversationListItem: Codable {
    /// Backend may use conversation_id or id.
    let conversation_id: String?
    let id: String?
    let conversation_title: String?
    let title: String?
    let last_message: String?
    let last_message_time: String?
    let created_on: String?
    let created_at: String?
    /// Server-driven section key (e.g. "Today", "Yesterday", "Jan-2026", "Week 4-2026").
    /// Group the list by this value verbatim — never compute sections from timestamps.
    let grouping: String?
    /// Drives the leading row icon (UI_CHAT_HISTORY.md §3): "image"→camera, "audio"/"voice"→mic,
    /// "text"→keyboard, anything else/nil→generic card. Matched case-insensitively.
    let message_type: String?
    var displayId: String { conversation_id ?? id ?? "" }
    var displayTitle: String? { conversation_title ?? title }
    var displayTime: String? { last_message_time ?? created_at ?? created_on }
}

struct ConversationListResponse: Codable {
    /// Paginated format (Android): results, has_more.
    let results: [ConversationListItem]?
    let has_more: Bool?
    /// Legacy: items, can_load_more.
    let items: [ConversationListItem]?
    let can_load_more: Bool?
    var getItems: [ConversationListItem] { results ?? items ?? [] }
    var canLoadMore: Bool { has_more ?? can_load_more ?? false }
}

// MARK: - 8. Home Module

struct HomeUdfResponse: Codable {
    let greeting: String?
    let sections: [SectionDto]?
}

struct SectionDto: Codable {
    let id: AnyCodable?
    let type: String?
    /// Title shown above options/cards (per HOME_AND_CHAT_COMPLETE_APIS.md).
    let title: String?
    /// Question/prompt text for selection sections (e.g. gender/crops).
    let question_text: String?
    /// Statement/prompt text (alternate key used by backend).
    let statement: String?
    /// Selection type (e.g. "single_select", "multi_select").
    let selection_type: String?
    /// Statement type (backend-specific; may hint gender/crop/livestock).
    let statement_type: String?
    let is_viewed: Bool?
    /// Some backends put badge/cta at top-level; others nest under meta.
    let badge: BadgeDto?
    let cta: CtaDto?
    /// Legacy/meta container (some backends nest title/badge/cta here).
    let meta: SectionMetaDto?
    let image_url: String?
    let statement_id: AnyCodable?
    let options: [OptionDto]?
}

struct SectionMetaDto: Codable {
    let title: String?
    let subtitle: String?
    let badge: BadgeDto?
    let cta: CtaDto?
}

struct BadgeDto: Codable {
    let icon: String?
    /// Per API_MODELS.md §5.1 — backend returns string (e.g. "0"), not Int.
    let count: String?
    let show: Bool?
}

struct CtaDto: Codable {
    let text: String?
    let type: String?
    let action: String?
    let payload: String?
}

struct OptionDto: Codable {
    let id: AnyCodable?
    let text: String?
    let title: String?
    let label: String?
    let type: String?
    let payload: String?
    /// Display text: prefer text, then title, then label (API may use any of these).
    var displayText: String? { text ?? title ?? label }
}

struct ImageStatementRequest: Codable {
    let statement_id: String
    let triggered_input_type: String
}

struct ImageStatementFollowUpQuestion: Codable {
    let follow_up_question_id: String
    let sequence: Int
    let question: String
}

struct ImageStatementResponse: Codable {
    let short_answer: String?
    let follow_up_questions: [ImageStatementFollowUpQuestion]?
    let message_id: String?
    let conversation_id: String?
    let image_url: String?
}

/// PATCH api/images/v2/viewed/ – statement_id, user_id, status (per HOME_AND_CHAT_COMPLETE_APIS.md).
struct ImageViewedRequest: Codable {
    let statement_id: String
    let user_id: String
    let status: String
}

struct ImageViewedResponse: Codable {
    let image_id: String?
    let statement_id: String?
    let view_count: Int?
    let status: String?
}

// MARK: - 9. Initialize Guest User Module
// Request matches Android: only device_id (no user_id).
struct InitializeGuestUserRequest: Codable {
    let device_id: String
    let lat: Double?
    let long: Double?
    let accuracy: Double?
    let utm_source: String?
    let utm_medium: String?
    let utm_campaign: String?
    let moengage_id: String?
    let google_advertise_id: String?

    enum CodingKeys: String, CodingKey {
        case device_id, lat, long, accuracy
        case utm_source, utm_medium, utm_campaign
        case moengage_id, google_advertise_id
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(device_id, forKey: .device_id)
        try c.encodeIfPresent(lat, forKey: .lat)
        try c.encodeIfPresent(long, forKey: .long)
        try c.encodeIfPresent(accuracy, forKey: .accuracy)
        try c.encodeIfPresent(utm_source, forKey: .utm_source)
        try c.encodeIfPresent(utm_medium, forKey: .utm_medium)
        try c.encodeIfPresent(utm_campaign, forKey: .utm_campaign)
        try c.encodeIfPresent(moengage_id, forKey: .moengage_id)
        try c.encodeIfPresent(google_advertise_id, forKey: .google_advertise_id)
    }
}

struct InitializeGuestUserResponse: Decodable {
    let message: String?
    let user_id: String?
    let access_token: String?
    let refresh_token: String?
    let show_crops_livestocks: Bool?
    let last_location_fetch_threshold: String?
    let display_address: String?
    let created_on: String?
    let location_source: String?
    let country_code: String?
    let country: String?
    let state: String?
    let dashboard: Bool?
    let created_now: Bool?
    let geography_level3: String?
    let geography_level4: String?
    let geography_level5: String?
    let geography_level6: String?
    let ip_location_fallback_time_limit: Int?

    enum CodingKeys: String, CodingKey {
        case message, user_id, access_token, refresh_token
        case show_crops_livestocks
        case last_location_fetch_threshold, display_address, created_on, location_source
        case country_code, country, state
        case dashboard, created_now
        case geography_level3, geography_level4, geography_level5, geography_level6
        case ip_location_fallback_time_limit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func decodeBoolFlexible(_ key: CodingKeys) -> Bool? {
            if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b }
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i != 0 }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "t", "1", "yes", "y"].contains(t) { return true }
                if ["false", "f", "0", "no", "n"].contains(t) { return false }
            }
            return nil
        }

        func decodeIntFlexible(_ key: CodingKeys) -> Int? {
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return Int(t)
            }
            return nil
        }

        message = try c.decodeIfPresent(String.self, forKey: .message)
        user_id = try c.decodeIfPresent(String.self, forKey: .user_id)
        access_token = try c.decodeIfPresent(String.self, forKey: .access_token)
        refresh_token = try c.decodeIfPresent(String.self, forKey: .refresh_token)

        show_crops_livestocks = decodeBoolFlexible(.show_crops_livestocks)
        last_location_fetch_threshold = try c.decodeIfPresent(String.self, forKey: .last_location_fetch_threshold)
        display_address = try c.decodeIfPresent(String.self, forKey: .display_address)
        created_on = try c.decodeIfPresent(String.self, forKey: .created_on)
        location_source = try c.decodeIfPresent(String.self, forKey: .location_source)
        country_code = try c.decodeIfPresent(String.self, forKey: .country_code)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        state = try c.decodeIfPresent(String.self, forKey: .state)

        dashboard = decodeBoolFlexible(.dashboard)
        created_now = decodeBoolFlexible(.created_now)

        geography_level3 = try c.decodeIfPresent(String.self, forKey: .geography_level3)
        geography_level4 = try c.decodeIfPresent(String.self, forKey: .geography_level4)
        geography_level5 = try c.decodeIfPresent(String.self, forKey: .geography_level5)
        geography_level6 = try c.decodeIfPresent(String.self, forKey: .geography_level6)
        ip_location_fallback_time_limit = decodeIntFlexible(.ip_location_fallback_time_limit)
    }
}

// MARK: - 10. Language Module

struct AcceptPPandTCRequest: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct AcceptPPandTCResponse: Codable {
    let message: String
    let success: Bool
    let termsAccepted: Bool
    let termsAcceptedAt: String

    enum CodingKeys: String, CodingKey {
        case message, success
        case termsAccepted = "terms_accepted"
        case termsAcceptedAt = "terms_accepted_at"
    }
}

struct SetPreferredLanguageRequest: Codable {
    let languageId: Int
    let userId: String

    enum CodingKeys: String, CodingKey {
        case languageId = "language_id"
        case userId = "user_id"
    }
}

struct SetPreferredLanguageResponse: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct SupportedLanguage: Codable {
    let code: String
    let display_name: String
    let id: Int
}

struct SupportedLanguageGroup: Codable {
    let languages: [SupportedLanguage]?
    let group_name: String?
    let country_code: String?
    let state_code: String?
}

// LanguageLabelsResponse = [String: String] (decode in client)

// MARK: - 11. Location Module

struct UpdateLocationRequest: Codable {
    let user_id: String
    let lat: String
    let long: String
    let geography_level2: String?
    let geography_level3: String?
    let geography_level4: String?
    let geography_level5: String?
    let geography_level6: String?
    let address: String?
}

struct OsmResponse: Codable {
    let display_name: String?
    let address: OsmAddress?
}

struct OsmAddress: Codable {
    let village: String?
    let state_district: String?
    let state: String?
    let postcode: String?
    let country: String?
    let country_code: String?
}

struct GetLocationResponse: Codable {
    let user_profile: LocationUserProfile?
}

struct LocationUserProfile: Codable {
    let lat: String?
    let long: String?
    let geography_level2: String?
    let geography_level3: String?
    let geography_level4: String?
    let geography_level5: String?
    let geography_level6: String?
    let address: String?
}

// MARK: - 12. Name Module

/// API: update_user_profile
struct UserNameRequest: Codable {
    let user_id: String
    let name: String?
    let first_name: String?
    let last_name: String?
    let gender: String?
    let age: Int?
    let land_holding: String?
    let live_stock_details: [LiveStockDetail]?
    let farmer_reach_count: Int?
    let profile_picture: String?
    /// Android sends this as a non-null boolean (defaults to false).
    let receive_com_via_whatsapp: Bool
    let role: String?
    let specialization: String?

    init(
        user_id: String,
        name: String? = nil,
        first_name: String? = nil,
        last_name: String? = nil,
        gender: String? = nil,
        age: Int? = nil,
        land_holding: String? = nil,
        live_stock_details: [LiveStockDetail]? = nil,
        farmer_reach_count: Int? = nil,
        profile_picture: String? = nil,
        receive_com_via_whatsapp: Bool? = nil,
        role: String? = nil,
        specialization: String? = nil
    ) {
        self.user_id = user_id
        self.name = name
        self.first_name = first_name
        self.last_name = last_name
        self.gender = gender
        self.age = age
        self.land_holding = land_holding
        self.live_stock_details = live_stock_details
        self.farmer_reach_count = farmer_reach_count
        self.profile_picture = profile_picture
        self.receive_com_via_whatsapp = receive_com_via_whatsapp ?? false
        self.role = role
        self.specialization = specialization
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id, forKey: .user_id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(first_name, forKey: .first_name)
        try c.encodeIfPresent(last_name, forKey: .last_name)
        try c.encodeIfPresent(gender, forKey: .gender)
        try c.encodeIfPresent(age, forKey: .age)
        try c.encodeIfPresent(land_holding, forKey: .land_holding)
        try c.encodeIfPresent(live_stock_details, forKey: .live_stock_details)
        try c.encodeIfPresent(farmer_reach_count, forKey: .farmer_reach_count)
        try c.encodeIfPresent(profile_picture, forKey: .profile_picture)
        try c.encode(receive_com_via_whatsapp, forKey: .receive_com_via_whatsapp)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(specialization, forKey: .specialization)
    }
}

struct UserNameResponse: Codable {
    let message: String
    let user_profile: UpdateUserName
}

/// GET api/images/v2/user_question_count/ — gate for AccountBenefits (AUTH_FLOW.md §6.1).
/// When `bypass_interstitial == true`, skip interstitial and go straight to Auth.
struct UserQuestionCountResponse: Codable {
    let total_questions_asked: Int?
    let bypass_interstitial: Bool?
}

/// Decodes and discards any JSON object (e.g. address with status/results from backend).
fileprivate struct AnyAddressValue: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        for k in c.allKeys {
            _ = try? c.decode(AnyCodable.self, forKey: k)
        }
    }
    func encode(to encoder: Encoder) throws {}
}

struct UpdateUserName: Codable {
    fileprivate let address: AnyAddressValue?
    let age: Int?
    let country: Int?
    let crop_details: [String]?
    let farmer_reach_count: Int?
    /// Some backends return a single display name field in addition to first/last.
    let name: String?
    let first_name: String?
    let gender: String?
    /// Backend may return Int (e.g. 18) or String; we decode Int to match update_user_profile response.
    let geography_level2: Int?
    let geography_level3: String?
    let geography_level4: String?
    let geography_level5: String?
    let geography_level6: String?
    let id: String?
    let land_holding: String?
    let last_name: String?
    let lat: String?
    let live_stock_details: [LiveStockDetail]?
    let long: String?
    let preferred_language: String?
    let phone: String?
    let phone_country_code: String?
    let profile_picture: String?
    let role: String?
    let specialization: String?
    let user_id: String?
}

struct LiveStockDetail: Codable {
    let count: Int?
    let type: String?
}

struct NameAddress: Codable {
    let address_line1: String?
    let address_line2: String?
    let village: String?
    let district: String?
    let state: String?
    let pincode: String?
}

// MARK: - 13. Privacy Policy Module

struct LegalLinks: Codable {
    let privacyPolicyUrl: String?
    let termsOfUseUrl: String?
}

struct PrivacyPolicyResponse: Codable {
    let url: String?
    let leaderboard_privacy_policy_url: String?
    let farmerchat_terms_of_use: String?
    let leaderboard_terms_of_use: String?
}

// MARK: - 14. Profile Module

struct FarmerProfile: Codable {
    let user_profile: ProfileUserProfile
    let role_assigned: RoleAssigned?
}

struct RoleAssigned: Codable {
    let id: Int?
    let role_name: String?
    let role_display_name: String?
}

struct ProfileUserProfile: Codable {
    let address: ProfileAddress?
    let age: Int?
    let country: Int?
    let country_name: String?
    let crop_details: [ProfileCrop]?
    let farmland_details: [ProfileFarmlandDetails]?
    let farmer_reach_count: Int?
    let first_name: String?
    let gender: String?
    /// Single name field when API returns it instead of first_name/last_name.
    let name: String?
    let geography_display_address: String?
    let geography_level2: Int?
    let geography_level2_name: String?
    let geography_level3: String?
    let geography_level4: String?
    let geography_level5: String?
    let geography_level6: String?
    let id: String?
    let land_holding: String?
    let last_name: String?
    let lat: String?
    let live_stock_details: [ProfileLiveStockDetail]?
    let llm_model: String?
    let long: String?
    let memory: [ProfileMemory]?
    let preferred_language: String?
    let phone: String?
    let phone_country_code: String?
    let profile_picture: String?
    let receive_com_via_whatsapp: Bool?
    let role: [ProfileRole]?
    let show_feedback_prompt: Bool?
    let specialization: String?
    let user_id: String?
}

struct ProfileAddress: Codable {
    let country: String?
    let level_2: String?
    let level_3: String?
    let level_4: String?
    let level_5: String?
    let level_6: String?
    let city: String?
    let state: String?
    let state_district: String?
}

struct ProfileCrop: Codable {
    let id: String?
    let text: String?
}

struct ProfileFarmlandDetails: Codable {
    let country_name: String?
    let crops_grown: [String]?
    let display_address: String?
    let farm_name: String?
    let id: String?
    let land_holding: String?
    let lat: String?
    let long: String?
    let geography_level2_name: String?
    let geography_level2_other: String?
    let geography_level3: String?
    let geography_level4: String?
    let geography_level5: String?
    let geography_level6: String?
    let user_id: String?
}

struct ProfileLiveStockDetail: Codable {
    let count: Int?
    let type: String?
}

struct ProfileMemory: Codable {
    let concerns: [String]?
    let last_known_stage: String?
    let last_known_stage_time: String?
    let last_queried_time: String?
    let name: String?
    let time_added: String?
    let type: String?
}

struct ProfileRole: Codable {
    let id: String?
    let text: String?
}

// UI_PROFILE.md §1.1 — port of UserProfileViewModel.displayName() logic verbatim.
extension ProfileUserProfile {
    func displayName() -> String {
        func clean(_ s: String?) -> String {
            let t = s?.trimmingCharacters(in: .whitespaces) ?? ""
            if t.caseInsensitiveCompare("No Name") == .orderedSame { return "" }
            if t.caseInsensitiveCompare("null") == .orderedSame { return "" }
            return t
        }
        let parts = [clean(first_name), clean(last_name)].filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return clean(name)
    }
}

// MARK: - 15. Token Module

struct RefreshTokenRequest: Codable {
    let refresh_token: String
}

struct RefreshTokenResponse: Codable {
    let access_token: String?
    let refresh_token: String?
}

struct SendNewTokenRequest: Codable {
    let device_id: String
    let user_id: String
}

// MARK: - 16. Voice Module

struct SetVoiceRequest: Codable {
    let conversation_id: String
    let query: String
    let message_reference_id: String
    let input_audio_encoding_format: String
    let triggered_input_type: String
    let editable_transcription: String
    init(conversation_id: String, query: String, message_reference_id: String,
         input_audio_encoding_format: String, triggered_input_type: String,
         editable_transcription: String = "True") {
        self.conversation_id = conversation_id
        self.query = query
        self.message_reference_id = message_reference_id
        self.input_audio_encoding_format = input_audio_encoding_format
        self.triggered_input_type = triggered_input_type
        self.editable_transcription = editable_transcription
    }
}

struct GetVoiceResponse: Codable {
    let message: String?
    let heard_input_query: String?
    let confidence_score: Double?
    let error: Bool
    let message_id: String?
    let section_message_id: String?
    let message_reference_id: String?
    let points: Int?
    let transcription_id: String?
}

// MARK: - 17. Weather Module

/// POST body for weather_forecast_lite. Mirrors Android: user_id required; lat/long optional.
struct WeatherRequest: Encodable {
    let user_id: String
    let lat: String?
    let long: String?
}

struct WeatherResponse: Codable {
    let current_temp: String?
    let precipitation_probability: String?
    let weather_icon: String?
    /// Alternative shape from some endpoints (e.g. v2): current object with temp/condition
    let current: WeatherCurrent?
    let forecast: [WeatherDay]?
}

struct WeatherCurrent: Codable {
    let temp: Double?
    let condition: String?
}

struct WeatherDay: Codable {
    let date: String?
    let temp_max: Double?
    let temp_min: Double?
    let condition: String?
}
