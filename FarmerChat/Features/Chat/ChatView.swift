//
//  ChatView.swift
//  FarmerChat
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import UIKit

private let chatHeaderGreen = AppColors.authHeaderGreen
private let chatUserBubbleBg = ContentColors.surfaceReadingSecondary       // neutral150 (light) / neutral800 (dark)
private let chatAiBubbleBg = ContentColors.surfaceReadingSecondary
private let chatActionGreen = AppColors.authHeaderGreen                    // #008236 — matches design buttons
private let chatActionBarGreen = AppColors.authButtonDarkGreen             // #08361B — dark bar for input
private let chatRelatedCardBg = ContentColors.surfacePrimary               // neutral150 (light) / neutral900 (dark)
private let chatAskButtonGreen = AppColors.accentGreen
private let chatDisclaimerGray = AppColors.neutral500

struct ChatView: View {
    let question: String?
    let conversationId: String?
    let imageUri: String?
    /// From transcribe_audio response; when set, send get_answer with triggered_input_type "audio" and transcription_id (per QUERY_FLOW_AND_APIS.md).
    let transcriptionId: String?
    let preGeneratedAnswer: String?
    let followUpQuestions: [String]
    let homeStatementId: String?
    let isWeatherAdviceCTA: Bool
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var showVoiceInput = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showChatPhotoSourcePicker = false
    @State private var saveToastMessage: String?
    @State private var shareSheetText: String?
    @State private var showTextInput = false
    @State private var pendingPhoto: UIImage?
    @State private var photoCaption = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isCaptionFocused: Bool

    init(
        question: String? = nil,
        conversationId: String? = nil,
        imageUri: String? = nil,
        transcriptionId: String? = nil,
        audioFileURL: URL? = nil,
        preGeneratedAnswer: String? = nil,
        followUpQuestions: [String] = [],
        homeStatementId: String? = nil,
        isWeatherAdviceCTA: Bool = false
    ) {
        self.question = question
        self.conversationId = conversationId
        self.imageUri = imageUri
        self.transcriptionId = transcriptionId
        self.preGeneratedAnswer = preGeneratedAnswer
        self.followUpQuestions = followUpQuestions
        self.homeStatementId = homeStatementId
        self.isWeatherAdviceCTA = isWeatherAdviceCTA
        _viewModel = State(initialValue: ChatViewModel(
            conversationId: conversationId,
            prefillQuestion: question,
            transcriptionId: transcriptionId,
            prefillAudioURL: audioFileURL,
            preGeneratedAnswer: preGeneratedAnswer,
            followUpQuestions: followUpQuestions,
            homeStatementId: homeStatementId,
            isWeatherAdviceCTA: isWeatherAdviceCTA,
            pregenHeroImageUri: imageUri
        ))
    }

    /// From History = show Menu (pop to root); from Home = show Close (dismiss one level).
    private var isFromHistory: Bool { conversationId != nil }

    var body: some View {
        ZStack {
            // Fills the full screen including safe areas (top status bar + bottom indicator).
            // VStack content sits within safe-area bounds, so the only place this green
            // shows through is the status bar region — matching the LogoAppBar's green.
            // (Same pattern as HomeView.swift.)
            BrandColors.surfacePrimary.ignoresSafeArea()
            VStack(spacing: 0) {
            // UI_CHAT.md §3 — LogoAppBar: entry-source drives left icon,
            // logo fades in only when a thread has content (hidden during initial load + error).
            LogoAppBar(
                showLogo: !viewModel.messages.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil,
                leftIcon: isFromHistory ? "line.3.horizontal" : "xmark",
                onLeft: {
                    if isFromHistory {
                        navigator.showDrawer = true
                    } else {
                        dismiss()
                    }
                }
            )
            // UI_CHAT.md §5.3 — initial fetch error (no messages yet): red circle X + label + grey capsule retry.
            // follow-up errors use the inline banner (UI_CHAT.md §5.4) above an existing thread.
            if viewModel.messages.isEmpty, let _ = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.red500)
                            .frame(width: 64, height: 64)
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColors.white)
                    }
                    Text(PreferencesManager.shared.label("fc_v2_app_label_cant_load_right_now", fallback: "Can't get the answer right now"))
                        .font(AppTypography.titleMedium())
                        .foregroundStyle(ContentColors.foregroundPrimary)
                        .multilineTextAlignment(.center)
                    Button {
                        viewModel.clearError()
                        Task { await viewModel.loadIfNeeded() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text(PreferencesManager.shared.label("fc_v2_app_label_try_again", fallback: "Try again"))
                                .font(AppTypography.labelMedium())
                        }
                        .foregroundStyle(ContentColors.foregroundPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppColors.neutral200)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                Spacer()
                inputBar
            } else {
                messagesList
                if viewModel.isLoading {
                    TipsCarousel(tips: answerGenerationTips())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(ContentColors.surfaceReadingPrimary)
                } else {
                    inputBar
                }
            }
        }
        .id(conversationId ?? "home")
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if let img = navigator.pendingImage {
                navigator.pendingImage = nil
                await sendImageFromUIImage(img)
            }
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            // AnalyticsManager.trackScreenView(screenName: AnalyticsConstants.Screen.chatScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.screenViewed)
        }
        .onDisappear {
            // AnalyticsManager.trackScreenExit(screenName: AnalyticsConstants.Screen.chatScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenExited, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.screenExited)
        }
        .onChange(of: question) { _, new in
            if let q = new, !q.isEmpty { viewModel.prefill(q) }
        }
        .onChange(of: isInputFocused) { _, focused in
            if !focused && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showTextInput = false
            }
        }
        .sheet(isPresented: $showChatPhotoSourcePicker) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Button {
                        showChatPhotoSourcePicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCamera = true }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "camera")
                                .font(.system(size: 28))
                                .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                            Text(PreferencesManager.shared.label("fc_v2_app_label_camera", fallback: "Camera"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.adaptiveLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(AppColors.adaptiveFill)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showChatPhotoSourcePicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showPhotoLibrary = true }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 28))
                                .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                            Text(PreferencesManager.shared.label("fc_v2_app_label_photos", fallback: "Photos"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.adaptiveLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(AppColors.adaptiveFill)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputSheet(
                onTranscribed: { result in
                    showVoiceInput = false
                    Task { await viewModel.sendVoice(text: result.text, transcriptionId: result.transcriptionId, audioURL: result.audioFileURL) }
                },
                onError: { msg in
                    showVoiceInput = false
                    viewModel.showVoiceError(msg)
                },
                onCancel: {
                    showVoiceInput = false
                }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onImagePicked: { image in
                    showCamera = false
                    pendingPhoto = image
                    photoCaption = ""
                },
                onCancel: { showCamera = false }
            )
        }
        .sheet(isPresented: $showPhotoLibrary) {
            LibraryPickerView(
                onImagePicked: { image in
                    showPhotoLibrary = false
                    pendingPhoto = image
                    photoCaption = ""
                },
                onCancel: { showPhotoLibrary = false }
            )
        }
        .overlay(alignment: .bottom) {
            if let msg = saveToastMessage, !msg.isEmpty {
                Text(msg)
                    .font(AppTypography.labelMedium())
                    .foregroundStyle(AppColors.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.neutral800)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .bottom) {
            if pendingPhoto != nil {
                photoInputBar
            }
        }
        } // ZStack
    }

    private func sendImageFromUIImage(_ image: UIImage, query: String? = nil) async {
        guard let jpegData = image.jpegData(compressionQuality: 0.75) else { return }
        let base64 = jpegData.base64EncodedString()
        let name = "image_\(UUID().uuidString).jpg"
        await viewModel.sendImage(imageBase64: base64, imageName: name, query: query, originalImage: image)
    }

    private var photoInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if let img = pendingPhoto {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            pendingPhoto = nil
                            photoCaption = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                }

                HStack(spacing: 10) {
                    TextField(PreferencesManager.shared.label("fc_v2_app_label_ask_about_your_farm", fallback: "Ask about your farm..."), text: $photoCaption, axis: .vertical)
                        .focused($isCaptionFocused)
                        .textFieldStyle(.plain)
                        .font(AppTypography.bodyMedium())
                        .lineLimit(1...3)
                        .onAppear { isCaptionFocused = true }

                    Button {
                        guard let img = pendingPhoto else { return }
                        let caption = photoCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                        pendingPhoto = nil
                        photoCaption = ""
                        Task { await sendImageFromUIImage(img, query: caption.isEmpty ? nil : caption) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(chatActionGreen)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.adaptiveSecondaryGroupedBackground)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: pendingPhoto != nil)
    }

    private func inlineErrorView(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.error)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(AppColors.adaptiveLabel)
                Button(PreferencesManager.shared.label("fc_v2_app_label_try_again", fallback: "Try again")) {
                    viewModel.clearError()
                    Task { await viewModel.loadIfNeeded() }
                }
                .font(AppTypography.labelMedium())
                .foregroundStyle(chatActionGreen)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }
                    if viewModel.isLoading {
                        LoadingPlaceholderView()
                            .id("loading")
                    }
                    if !viewModel.isLoading, !viewModel.messages.isEmpty, let err = viewModel.errorMessage {
                        inlineErrorView(message: err)
                            .id("inline-error")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ContentColors.surfaceReadingPrimary)
            // Android ChatThreadContent.kt:164-208 — when a follow-up user message is sent,
            // anchor it to the TOP of the viewport (not the bottom), pushing the prior AI
            // answer above the fold. Gives the fresh-conversation feel the user expects.
            .onChange(of: lastUserMessageId) { oldId, newId in
                guard let newId, oldId != nil, oldId != newId else { return }
                scrollToTop(proxy: proxy, id: newId)
            }
            .onChange(of: viewModel.messages.count) { _, newCount in
                guard newCount > 0, let last = viewModel.messages.last else { return }
                // Only scroll-to-bottom when the last message is an AI response arriving
                // (user-message scrolls are handled by the follow-up top-anchor above).
                if !last.isUser {
                    scrollToBottom(proxy: proxy, id: last.id)
                }
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if !loading, let last = viewModel.messages.last {
                    scrollToBottom(proxy: proxy, id: last.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Mirrors Android's `lastSeenLastUserMessageId` tracking — lets the scroll effect fire
    /// only when the trailing user message id actually changes (i.e. a new follow-up was sent,
    /// not when history prepends earlier user messages).
    private var lastUserMessageId: String? {
        viewModel.messages.last(where: { $0.isUser })?.id
    }

    private func messageRow(_ msg: ChatMessageDisplay) -> some View {
        let lastAiId = viewModel.messages.last(where: { !$0.isUser })?.id
        let isLastAiMessage = !msg.isUser && lastAiId == msg.id
        // Android ChatThreadContent.kt:315,325 — response actions (Listen/Share/Save + related
        // chips + follow-up hint) only render when this is the last AI message AND not loading.
        // While a new answer is streaming, the prior message's chips must disappear so the new
        // user question looks like a fresh conversation top-of-view.
        let showResponseExtras = isLastAiMessage && !viewModel.isLoading
        return VStack(alignment: .leading, spacing: 12) {
            ChatBubble(
                message: msg,
                showListenButton: false,
                onListen: nil
            )
            if !msg.isUser, !(msg.content ?? "").isEmpty, showResponseExtras {
                let lastUser = viewModel.messages.last(where: { $0.isUser })
                let lastQuestion = lastUser?.content ?? ""
                // §3: show "Read full advice" while the pre-gen answer is unread; once tapped
                // (or for non-pre-gen responses) fall through to the Listen/Share/Save row.
                // Android ChatResponseActions.kt:68-135 — AI warning only renders in the else
                // branch (i.e. never alongside the Read full advice button).
                let showReadFullAdvice = msg.isPreGenerated
                    && !FeatureFlags.shared.hideReadFullAdviceForCampaign
                    && viewModel.canShowReadFullAdvice(for: msg.id)
                if showReadFullAdvice {
                    readFullAdviceButton(pregenMessageId: msg.id)
                } else {
                    chatActionButtonsRow(
                        messageId: msg.backendMessageId ?? msg.id,
                        question: lastQuestion,
                        answer: msg.content ?? "",
                        userImage: lastUser?.image,
                        userImageUrl: lastUser?.imageUrl,
                        saveToast: $saveToastMessage,
                        shareItems: $shareSheetText
                    )
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                        Text(PreferencesManager.shared.label("fc_v2_app_label_tips_ai_may_be_wrong_please_double_check", fallback: "AI may be wrong. Please double-check."))
                            .font(AppTypography.bodySmall())
                            .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if showResponseExtras {
                if viewModel.loadingFollowUpIds.contains(msg.id) {
                    LogoSpinner(
                        type: .horizontal,
                        label: PreferencesManager.shared.label("fc_v2_app_label_loading_more", fallback: "Loading..."),
                        continuous: true
                    )
                    .scaleEffect(0.65)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                } else if let followUps = viewModel.followUps(for: msg.id), !followUps.isEmpty {
                    relatedQuestionsSection(followUps: followUps)
                }
            }
            // Android ChatResponseActions.kt:172-178 — hint lives inside ChatResponseActions,
            // so it disappears with everything else while loading.
            if !msg.isUser, !(msg.content ?? "").isEmpty, showResponseExtras {
                let hasFollowUps = !(viewModel.followUps(for: msg.id) ?? []).isEmpty
                Text(hasFollowUps ? PreferencesManager.shared.label("fc_v2_app_label_or_ask_a_followup_questions", fallback: "Or ask a follow-up question 👇") : PreferencesManager.shared.label("fc_v2_app_label_or_ask_a_followup_questions", fallback: "Ask a follow-up question 👇"))
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(AppColors.adaptiveLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private func readFullAdviceButton(pregenMessageId: String) -> some View {
        Button {
            Task { await viewModel.replacePreGeneratedWithQuestion(pregenMessageId: pregenMessageId) }
        } label: {
            Text(PreferencesManager.shared.label("fc_v2_app_label_read_full_advice", fallback: "Read full advice"))
                .font(AppTypography.labelLarge())
                .foregroundStyle(AppColors.onboardingWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.authButtonDarkGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .attentionWobble(trigger: true, delayMs: 1800, maxAngle: 5)
    }

    private func chatActionButtonsRow(messageId: String, question: String, answer: String, userImage: UIImage? = nil, userImageUrl: String? = nil, saveToast: Binding<String?>, shareItems: Binding<String?>) -> some View {
        let isThisLoading = viewModel.isLoadingSynthesiseAudio && viewModel.currentAudioMessageId == nil
        let isThisPlaying = viewModel.isAudioPlaying && viewModel.currentAudioMessageId == messageId
        return HStack(spacing: 10) {
            Button {
                Task { await viewModel.playTTS(messageId: messageId, text: answer) }
            } label: {
                HStack(spacing: 6) {
                    if isThisLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.onboardingWhite))
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else if isThisPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 14))
                    } else {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                    }
                    Text(isThisPlaying ? "Pause" : PreferencesManager.shared.label("fc_v2_app_label_listen", fallback: "Listen"))
                        .font(AppTypography.labelSmall())
                }
                .foregroundStyle(AppColors.onboardingWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(chatActionGreen)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isThisLoading)
            Button {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.answerShareButtonClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.answerShareButtonClicked)
                Task { @MainActor in
                    let photo = await resolveSharePhoto(image: userImage, url: userImageUrl)
                    guard let image = renderShareCardImage(question: question, answer: answer, photo: photo) else { return }
                    // Share via temp PNG file (Android parity — ACTION_SEND with image/png + text)
                    let url = writeShareCardToCache(image: image)
                    var items: [Any] = [shareCaption]
                    if let url = url { items.insert(url, at: 0) } else { items.insert(image, at: 0) }
                    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        var topVC = root
                        while let presented = topVC.presentedViewController { topVC = presented }
                        vc.popoverPresentationController?.sourceView = topVC.view
                        topVC.present(vc, animated: true)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                    Text(PreferencesManager.shared.label("fc_v2_app_label_share_download", fallback: "Share"))
                        .font(AppTypography.labelSmall())
                }
                .foregroundStyle(AppColors.onboardingWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(chatActionGreen)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.answerSaveButtonClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.answerSaveButtonClicked)
                Task { @MainActor in
                    let photo = await resolveSharePhoto(image: userImage, url: userImageUrl)
                    guard let image = renderShareCardImage(question: question, answer: answer, photo: photo) else {
                        saveToast.wrappedValue = PreferencesManager.shared.label("fc_v2_app_label_failed_to_save", fallback: "Failed to save")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast.wrappedValue = nil }
                        return
                    }
                    switch await saveImageToPhotos(image) {
                    case .saved:
                        saveToast.wrappedValue = PreferencesManager.shared.label("fc_v2_app_label_saved_to_gallery", fallback: "Saved to gallery")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast.wrappedValue = nil }
                    case .denied:
                        saveToast.wrappedValue = PreferencesManager.shared.label("fc_v2_app_label_photo_permission_denied", fallback: "Photo access denied. Enable in Settings.")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            saveToast.wrappedValue = nil
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    case .failed:
                        saveToast.wrappedValue = PreferencesManager.shared.label("fc_v2_app_label_failed_to_save", fallback: "Failed to save")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast.wrappedValue = nil }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                    Text(PreferencesManager.shared.label("fc_v2_app_label_save", fallback: "Save"))
                        .font(AppTypography.labelSmall())
                }
                .foregroundStyle(AppColors.onboardingWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(chatActionGreen)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relatedQuestionsSection(followUps: [FollowUpItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PreferencesManager.shared.label("fc_v2_app_label_related_questions", fallback: "Related questions"))
                .font(AppTypography.titleSmall())
                .foregroundStyle(AppColors.adaptiveLabel)
            VStack(spacing: 10) {
                ForEach(followUps) { item in
                    HStack(spacing: 12) {
                        Text(item.question)
                            .font(AppTypography.bodyMedium())
                            .foregroundStyle(AppColors.adaptiveLabel)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Task { await viewModel.sendFollowUp(question: item.question, followUpQuestionId: item.followUpQuestionId) }
                        } label: {
                            Text(PreferencesManager.shared.label("fc_v2_app_label_ask", fallback: "Ask"))
                                .font(AppTypography.labelMedium())
                                .foregroundStyle(AppColors.onboardingWhite)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(chatAskButtonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(chatRelatedCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    /// Anchors the target message at the top of the viewport — used when a follow-up user
    /// question is sent so the new question looks like the start of a fresh conversation.
    private func scrollToTop(proxy: ScrollViewProxy, id: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, id: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if showTextInput {
                let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                HStack(spacing: 10) {
                    // Camera — hidden when text is present
                    if !hasText {
                        Button { showChatPhotoSourcePicker = true } label: {
                            ZStack {
                                Circle().fill(chatActionBarGreen).frame(width: 48, height: 48)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(AppColors.accentGreen)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    TextField(PreferencesManager.shared.label("fc_v2_app_label_ask_about_your_farm", fallback: "Ask about your farm..."), text: $inputText, axis: .vertical)
                        .focused($isInputFocused)
                        .textFieldStyle(.plain)
                        .font(AppTypography.bodyMedium())
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ContentColors.surfacePrimary)
                        .clipShape(Capsule())

                    // Mic (empty) → Send (typing)
                    Button {
                        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            inputText = ""
                            isInputFocused = false
                            showTextInput = false
                            Task { await viewModel.send(text) }
                        } else {
                            isInputFocused = false
                            showTextInput = false
                            showVoiceInput = true
                        }
                    } label: {
                        ZStack {
                            Circle().fill(chatActionBarGreen).frame(width: 48, height: 48)
                            if hasText {
                                Image("icon_send")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                                    .foregroundStyle(AppColors.accentGreen)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(AppColors.accentGreen)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(hasText && viewModel.isLoading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            } else {
                HStack(spacing: 12) {
                    // Photo — individual dark card
                    Button { showChatPhotoSourcePicker = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AppColors.accentGreen)
                            Text(PreferencesManager.shared.label("fc_v2_app_label_camera", fallback: "Photo"))
                                .font(AppTypography.labelSmall())
                                .foregroundStyle(AppColors.onboardingWhite)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(chatActionBarGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    // Speak — individual dark card
                    Button {
                        if PreferencesManager.shared.asrEnabled {
                            showVoiceInput = true
                        } else {
                            let message = PreferencesManager.shared.label("fc_v2_app_label_asr_is_disabled_for_your_selected_language", fallback: "Voice input is not available for your selected language")
                            saveToastMessage = message
                            Task {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                if saveToastMessage == message { saveToastMessage = nil }
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AppColors.accentGreen)
                            Text(PreferencesManager.shared.label("fc_v2_app_label_speak", fallback: "Speak"))
                                .font(AppTypography.labelSmall())
                                .foregroundStyle(AppColors.onboardingWhite)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(chatActionBarGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    // Type — individual dark card
                    Button {
                        showTextInput = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isInputFocused = true }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 24))
                                .foregroundStyle(AppColors.accentGreen)
                            Text(PreferencesManager.shared.label("fc_v2_app_label_type", fallback: "Type"))
                                .font(AppTypography.labelSmall())
                                .foregroundStyle(AppColors.onboardingWhite)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(chatActionBarGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(BrandColors.surfacePrimary)
            }
        }
    }
}

private let voiceWaveformHeights: [CGFloat] = [
    0.4, 0.6, 0.8, 0.5, 0.9, 0.7, 0.5, 0.3, 0.6, 0.8,
    0.5, 0.7, 0.4, 0.9, 0.6, 0.8, 0.5, 0.3, 0.7, 0.5,
    0.6, 0.4, 0.8, 0.6, 0.4
]

struct ChatBubble: View {
    let message: ChatMessageDisplay
    var showListenButton: Bool = false
    var onListen: (() -> Void)? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var audioDuration: Double = 0

    var body: some View {
        HStack(alignment: .top) {
            // Wide-banner user bubbles (pregen hero image) occupy the full chat column;
            // regular user bubbles are shouldered in from the leading edge.
            if message.isUser && !message.wideBannerImage { Spacer(minLength: 48) }
            VStack(alignment: message.isUser ? (message.wideBannerImage ? .leading : .trailing) : .leading, spacing: 6) {
                if message.isUser {
                    VStack(alignment: message.wideBannerImage ? .leading : .trailing, spacing: 8) {
                        if message.wideBannerImage, let urlStr = message.imageUrl, let url = URL(string: urlStr) {
                            // Android ChatMessage.userBubbleImageWideBanner — fills the bubble width.
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(contentMode: .fill)
                                case .empty:
                                    Rectangle().fill(AppColors.adaptiveFill)
                                        .overlay(ProgressView())
                                case .failure:
                                    Rectangle().fill(AppColors.adaptiveFill)
                                @unknown default:
                                    Rectangle().fill(AppColors.adaptiveFill)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if let img = message.image {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 220, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if message.audioURL != nil {
                            // Android-style voice player: play button + waveform + duration
                            HStack(spacing: 10) {
                                Button { toggleAudioPlayback() } label: {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.accentGreen)
                                            .frame(width: 40, height: 40)
                                        Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                            .offset(x: isPlayingAudio ? 0 : 1)
                                    }
                                }
                                .buttonStyle(.plain)
                                HStack(alignment: .center, spacing: 2) {
                                    ForEach(0..<voiceWaveformHeights.count, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(Color.gray.opacity(0.45))
                                            .frame(width: 2.5, height: voiceWaveformHeights[i] * 28)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                Text(formatAudioDuration(audioDuration))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ContentColors.foregroundSecondary)
                                    .monospacedDigit()
                                    .fixedSize()
                            }
                            if let text = message.content, !text.isEmpty {
                                Text(text)
                                    .font(AppTypography.bodyMedium())
                                    .foregroundStyle(AppColors.adaptiveLabel)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                            }
                        } else {
                            if let text = message.content, !text.isEmpty {
                                Text(text)
                                    .font(AppTypography.bodyMedium())
                                    .foregroundStyle(AppColors.adaptiveLabel)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, message.wideBannerImage ? 10 : 0)
                                    .padding(.bottom, message.wideBannerImage ? 6 : 0)
                            }
                        }
                    }
                    .padding(message.wideBannerImage ? 6 : (message.image != nil && message.audioURL == nil) ? 6 : 16)
                    .background(chatUserBubbleBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                } else {
                    MarkdownTextView(
                        text: message.content ?? "",
                        textColor: AppColors.adaptiveLabel
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer(minLength: 48) }
        }
        .onAppear { loadAudioDuration() }
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            return
        }
        guard let url = message.audioURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlayingAudio = true
            let duration = audioPlayer?.duration ?? 0
            if audioDuration == 0 { audioDuration = duration }
            if duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                    isPlayingAudio = false
                }
            }
        } catch {
            print("[Chat] Audio playback failed: \(error)")
        }
    }

    private func loadAudioDuration() {
        guard audioDuration == 0, let url = message.audioURL,
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        audioDuration = player.duration
    }

    private func formatAudioDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

/// One suggested follow-up: display text and optional id for follow_up_question_click (per FOLLOW_UP_QUESTIONS_FLOW.md).
struct FollowUpItem: Identifiable {
    var id: String { followUpQuestionId ?? question }
    let question: String
    let followUpQuestionId: String?
}

struct FollowUpChips: View {
    let followUps: [FollowUpItem]
    let onTap: (FollowUpItem) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(followUps) { item in
                Button(item.question) { onTap(item) }
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(AppColors.authHeaderGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.adaptiveSecondaryGroupedBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.authHeaderGreen, lineWidth: 1.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingPlaceholderView: View {
    var body: some View {
        HStack(spacing: 10) {
            LogoSpinner(type: .horizontal, color: AppColors.green500, label: PreferencesManager.shared.label("fc_v2_app_label_getting_your_answer", fallback: "Getting your answer..."), continuous: true)
            Spacer()
        }
        .padding(14)
        .background(AppColors.adaptiveSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

struct ChatMessageDisplay: Identifiable {
    let id: String
    let content: String?
    let isUser: Bool
    let backendMessageId: String?
    let image: UIImage?
    /// Android ChatMessage.userBubbleImageWideBanner — remote hero image shown as a
    /// wide banner inside the user bubble (pregen / feed statement cards).
    let imageUrl: String?
    let wideBannerImage: Bool
    let audioURL: URL?
    let isPreGenerated: Bool
    init(id: String, content: String?, isUser: Bool, backendMessageId: String? = nil, image: UIImage? = nil, imageUrl: String? = nil, wideBannerImage: Bool = false, audioURL: URL? = nil, isPreGenerated: Bool = false) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.backendMessageId = backendMessageId
        self.image = image
        self.imageUrl = imageUrl
        self.wideBannerImage = wideBannerImage
        self.audioURL = audioURL
        self.isPreGenerated = isPreGenerated
    }
}

// MARK: - ChatViewModel

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessageDisplay] = []
    var isLoading = false
    var errorMessage: String?
    /// Tracks which pre-generated AI message has already had "Read full advice" tapped
    /// so the button hides on that message (CHAT_SCREEN.md §8.6).
    var readFullAdviceRequestedForMessageId: String?
    private var conversationId: String?
    private let chatUseCase = ChatUseCase()
    private var prefillQuestion: String?
    private var prefillAudioURL: URL?
    private var lastAnswerMessageId: String?
    private var pendingFollowUps: [String: [FollowUpItem]] = [:]
    var loadingFollowUpIds: Set<String> = []
    /// From transcribe_audio; when set, send get_answer with triggered_input_type "audio" and transcription_id.
    private var transcriptionId: String?
    /// Pre-generated content from Home feed card (no API call until user taps "Read full advice" or follow-up).
    private var preGeneratedAnswer: String?
    private var preGeneratedQuestion: String?
    /// Cached follow-up strings for the pre-gen pair — replayed to add_query_to_history.
    private var preGeneratedFollowUps: [String] = []
    private var homeStatementId: String?
    private var isWeatherAdviceCTA: Bool
    /// Remote hero image URL shown as a wide banner on the pregen user bubble
    /// (Android ChatScreen.kt:853 userBubbleImageUri).
    private var pregenHeroImageUri: String?
    /// Listen button state machine (per CHAT_SCREEN.md §6.7 / §8.4).
    var isLoadingSynthesiseAudio: Bool = false
    var isAudioPlaying: Bool = false
    /// messageId whose audio is currently cached/playing. Different messageId → fresh synth.
    var currentAudioMessageId: String?
    private var audioPlaybackUrl: String?
    private var ttsPlayer: AVPlayer?
    private var ttsEndObserver: NSObjectProtocol?

    init(
        conversationId: String?,
        prefillQuestion: String?,
        transcriptionId: String? = nil,
        prefillAudioURL: URL? = nil,
        preGeneratedAnswer: String? = nil,
        followUpQuestions: [String] = [],
        homeStatementId: String? = nil,
        isWeatherAdviceCTA: Bool = false,
        pregenHeroImageUri: String? = nil
    ) {
        self.conversationId = conversationId
        self.pregenHeroImageUri = pregenHeroImageUri
        self.prefillQuestion = prefillQuestion
        self.transcriptionId = transcriptionId
        self.prefillAudioURL = prefillAudioURL
        self.preGeneratedAnswer = preGeneratedAnswer
        self.homeStatementId = homeStatementId
        self.isWeatherAdviceCTA = isWeatherAdviceCTA
        if let q = prefillQuestion, !q.isEmpty {
            self.preGeneratedQuestion = q
        }
        if !followUpQuestions.isEmpty {
            pendingFollowUps["__pregen"] = followUpQuestions.map { FollowUpItem(question: $0, followUpQuestionId: nil) }
            preGeneratedFollowUps = followUpQuestions
        }
    }

    func followUps(for messageId: String) -> [FollowUpItem]? {
        pendingFollowUps[messageId]
    }

    func clearError() {
        errorMessage = nil
    }

    func loadIfNeeded() async {
        if let cid = conversationId {
            // Only fetch from API when we have no messages yet (e.g. opened from drawer).
            // Otherwise we'd overwrite the live conversation and hide the second Q&A.
            if messages.isEmpty {
                await loadHistory(cid)
            }
            return
        }
        // SPLASH_SCREEN.md §5.4: if a qapair payload was stashed sidecar (e.g. push arrived
        // before Chat rendered), adopt it now. Only applies when the destination didn't already
        // carry a pre-gen answer and the stashed question matches the current prefill.
        if preGeneratedAnswer == nil,
           let q = prefillQuestion, !q.isEmpty,
           let pregen = PendingPreGeneratedContentStore.shared.peek(),
           pregen.question == q {
            PendingPreGeneratedContentStore.shared.consume()
            preGeneratedAnswer = pregen.response
            if !pregen.followUps.isEmpty {
                pendingFollowUps["__pregen"] = pregen.followUps.map {
                    FollowUpItem(question: $0, followUpQuestionId: nil)
                }
            }
        }
        // Pre-generated content from Home card: render immediately, then hydrate the
        // backend with new_conversation + add_query_to_history best-effort (CHAT_SCREEN.md §2.3 C).
        if let answer = preGeneratedAnswer, !answer.isEmpty, let q = prefillQuestion, !q.isEmpty {
            let qId = UUID().uuidString
            let ansId = "pregen-\(qId)"
            // Android ChatViewModel.kt:342-363 — when the pregen user bubble carries a hero
            // image URL, render it as a wide banner above the question title.
            let heroUri = pregenHeroImageUri?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasHero = !(heroUri?.isEmpty ?? true)
            messages = messages + [
                ChatMessageDisplay(
                    id: qId,
                    content: q,
                    isUser: true,
                    imageUrl: hasHero ? heroUri : nil,
                    wideBannerImage: hasHero
                ),
                ChatMessageDisplay(id: ansId, content: answer, isUser: false, isPreGenerated: true)
            ]
            if let fu = pendingFollowUps["__pregen"], !fu.isEmpty {
                pendingFollowUps[ansId] = fu
                pendingFollowUps.removeValue(forKey: "__pregen")
            }
            preGeneratedAnswer = nil
            preGeneratedQuestion = q
            hydrateCampaignQAPair(query: q, response: answer)
            return
        }
        if let q = prefillQuestion, !q.isEmpty {
            if let audioURL = prefillAudioURL {
                prefillAudioURL = nil
                await sendVoice(text: q, transcriptionId: transcriptionId, audioURL: audioURL)
            } else {
                await send(q)
            }
        }
    }

    func prefill(_ q: String) {
        prefillQuestion = q
        if !messages.contains(where: { $0.content == q && $0.isUser }) {
            Task { await send(q) }
        }
    }

    func send(_ text: String) async {
        guard !isLoading else { return }
        clearAudioPlayback()
        if conversationId == nil {
            if let fromPrefs = PreferencesManager.shared.newConversationId {
                conversationId = fromPrefs
            } else {
                do {
                    let res = try await chatUseCase.newConversation()
                    conversationId = res.conversation_id
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }
        guard let cid = conversationId else { return }
        let queryToSend = text
        let statementIdToSend: String? = (homeStatementId != nil && queryToSend == preGeneratedQuestion) ? homeStatementId : nil
        let weatherCta = isWeatherAdviceCTA
        if statementIdToSend != nil { homeStatementId = nil }
        if weatherCta { isWeatherAdviceCTA = false }
        let prefs = PreferencesManager.shared
        let isFirstQueryEver = !prefs.firstQueryAsked
        if isFirstQueryEver { prefs.firstQueryAsked = true }
        var sendProps: [String: Any] = [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen, AnalyticsConstants.Property.textQuery: queryToSend]
        if weatherCta { sendProps[AnalyticsConstants.Property.weatherAdviceCta] = true }
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.sendQueryInitiated, properties: sendProps, adjustToken: AnalyticsConstants.AdjustToken.sendQueryInitiated)
        if isFirstQueryEver {
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.firstQueryAsked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.firstQueryAsked)
        }
        messages = messages + [ChatMessageDisplay(id: UUID().uuidString, content: queryToSend, isUser: true)]
        isLoading = true
        defer { isLoading = false }

        // Android ChatViewModel.kt:784 — client generates a UUID per message for server-side deduplication.
        let messageIdForThisRequest = UUID().uuidString
        let triggeredType = transcriptionId != nil ? "audio" : "text"
        do {
            let res = try await chatUseCase.getAnswerForTextQuery(conversationId: cid, query: queryToSend, messageId: messageIdForThisRequest, triggeredInputType: triggeredType, transcriptionId: transcriptionId, statementId: statementIdToSend, weatherCtaTriggered: weatherCta)
            let thisResponseMessageId = (res.message_id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            print("[Chat] get_answer response message_id: \(thisResponseMessageId ?? "nil")")
            lastAnswerMessageId = thisResponseMessageId
            let displayId = thisResponseMessageId ?? UUID().uuidString
            transcriptionId = nil
            let resp = res.response ?? ""
            let trans = res.translated_response ?? ""
            var ans: String
            if !resp.isEmpty && !trans.isEmpty {
                ans = resp.count >= trans.count ? resp : trans
            } else {
                ans = trans.isEmpty ? resp : trans
            }
            if ans.isEmpty { ans = res.message ?? "" }
            if ans.isEmpty {
                ans = String(localized: "No response content was returned. Please try rephrasing or try again later.")
            }
            var successProps = sendProps
            successProps[AnalyticsConstants.Property.validQuery] = true
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.sendQuery, properties: successProps, adjustToken: AnalyticsConstants.AdjustToken.sendQuery)
            messages = messages + [ChatMessageDisplay(id: displayId, content: ans, isUser: false, backendMessageId: thisResponseMessageId)]
            // Step 2–3 (Android flow): fire-and-forget follow-up fetch (matches viewModelScope.launch in Android).
            // Must NOT await — send() returns immediately so isLoading stays false and user can type next question.
            if let mid = thisResponseMessageId, !mid.isEmpty {
                fireFollowUpFetch(messageId: mid, displayId: displayId)
            }
        } catch {
            var failProps = sendProps
            failProps[AnalyticsConstants.Property.validQuery] = false
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.sendQuery, properties: failProps, adjustToken: AnalyticsConstants.AdjustToken.sendQuery)
            errorMessage = error.localizedDescription
        }
    }

    /// Send voice-transcribed text: uses triggered_input_type "audio" and includes transcription_id.
    func sendVoice(text: String, transcriptionId: String?, audioURL: URL?) async {
        self.transcriptionId = transcriptionId
        let qId = UUID().uuidString
        messages = messages + [ChatMessageDisplay(id: qId, content: text, isUser: true, audioURL: audioURL)]

        guard !isLoading else { return }
        if conversationId == nil {
            if let fromPrefs = PreferencesManager.shared.newConversationId {
                conversationId = fromPrefs
            } else {
                do {
                    let res = try await chatUseCase.newConversation()
                    conversationId = res.conversation_id
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }
        guard let cid = conversationId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await chatUseCase.getAnswerForTextQuery(conversationId: cid, query: text, messageId: UUID().uuidString, triggeredInputType: "audio", transcriptionId: transcriptionId, statementId: nil, weatherCtaTriggered: false)
            self.transcriptionId = nil
            let thisResponseMessageId = (res.message_id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            lastAnswerMessageId = thisResponseMessageId
            let displayId = thisResponseMessageId ?? UUID().uuidString
            var ans: String
            let resp = res.response ?? ""
            let trans = res.translated_response ?? ""
            if !resp.isEmpty && !trans.isEmpty {
                ans = resp.count >= trans.count ? resp : trans
            } else {
                ans = trans.isEmpty ? resp : trans
            }
            if ans.isEmpty { ans = res.message ?? "" }
            if ans.isEmpty { ans = String(localized: "No response content was returned. Please try rephrasing or try again later.") }
            messages = messages + [ChatMessageDisplay(id: displayId, content: ans, isUser: false, backendMessageId: thisResponseMessageId)]
            if let mid = thisResponseMessageId, !mid.isEmpty {
                fireFollowUpFetch(messageId: mid, displayId: displayId)
            }
        } catch {
            self.transcriptionId = nil
            errorMessage = error.localizedDescription
        }
    }

    func showVoiceError(_ message: String) {
        errorMessage = message
    }

    /// Whether the last two messages form the pre-gen pair AND the user hasn't
    /// already tapped "Read full advice" on that pre-gen answer. Callers also gate
    /// on `FeatureFlags.shared.hideReadFullAdviceForCampaign` at the view layer.
    func canShowReadFullAdvice(for aiMessageId: String) -> Bool {
        guard let ai = messages.last, !ai.isUser, ai.id == aiMessageId, ai.isPreGenerated else { return false }
        guard readFullAdviceRequestedForMessageId != aiMessageId else { return false }
        guard let lastUser = messages.last(where: { $0.isUser }),
              !(lastUser.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    /// "Read full advice" tap (CHAT_SCREEN.md §2.3 F, §8.6). Removes the pre-gen AI
    /// answer so the original user bubble stays and the full answer loads in its place.
    /// Sends triggered_input_type="read_full_advice" + statement_id=homeStatementId.
    func replacePreGeneratedWithQuestion(pregenMessageId: String) async {
        guard !isLoading else { return }
        guard canShowReadFullAdvice(for: pregenMessageId) else { return }
        guard let lastUser = messages.last(where: { $0.isUser }),
              let question = lastUser.content,
              !question.isEmpty else { return }
        clearAudioPlayback()
        readFullAdviceRequestedForMessageId = pregenMessageId

        if conversationId == nil {
            if let fromPrefs = PreferencesManager.shared.newConversationId {
                conversationId = fromPrefs
            } else {
                do {
                    let res = try await chatUseCase.newConversation()
                    conversationId = res.conversation_id
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }
        guard let cid = conversationId else { return }

        let statementId = homeStatementId
        homeStatementId = nil

        // Drop the pre-gen answer — the original user bubble stays in place.
        // The full answer will be appended below it, giving a clean single Q&A.
        messages = messages.filter { $0.id != pregenMessageId }
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await chatUseCase.getAnswerForTextQuery(
                conversationId: cid,
                query: question,
                messageId: UUID().uuidString,
                triggeredInputType: "read_full_advice",
                transcriptionId: nil,
                statementId: statementId,
                weatherCtaTriggered: false
            )
            let thisResponseMessageId = (res.message_id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            lastAnswerMessageId = thisResponseMessageId
            let displayId = thisResponseMessageId ?? UUID().uuidString
            let resp = res.response ?? ""
            let trans = res.translated_response ?? ""
            var ans: String
            if !resp.isEmpty && !trans.isEmpty {
                ans = resp.count >= trans.count ? resp : trans
            } else {
                ans = trans.isEmpty ? resp : trans
            }
            if ans.isEmpty { ans = res.message ?? "" }
            if ans.isEmpty {
                ans = String(localized: "No response content was returned. Please try rephrasing or try again later.")
            }
            messages = messages + [ChatMessageDisplay(id: displayId, content: ans, isUser: false, backendMessageId: thisResponseMessageId)]
            if let mid = thisResponseMessageId, !mid.isEmpty {
                fireFollowUpFetch(messageId: mid, displayId: displayId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Best-effort campaign hydration: new_conversation then add_query_to_history.
    /// Both errors are logged; neither surfaces to the UI. Skipped when user_id is blank.
    private func hydrateCampaignQAPair(query: String, response: String) {
        let userId = PreferencesManager.shared.userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !userId.isEmpty else { return }
        let followUps = preGeneratedFollowUps
        preGeneratedFollowUps = []
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.conversationId == nil {
                do {
                    let res = try await self.chatUseCase.newConversation()
                    self.conversationId = res.conversation_id
                } catch {
                    print("[Chat] new_conversation (pre-gen) failed: \(error)")
                    return
                }
            }
            guard let cid = self.conversationId else { return }
            do {
                try await self.chatUseCase.addQueryToHistory(
                    conversationId: cid,
                    query: query,
                    response: response,
                    followUps: followUps,
                    triggeredInputType: "push"
                )
            } catch {
                print("[Chat] add_query_to_history failed: \(error)")
            }
        }
    }

    private func fireFollowUpFetch(messageId: String, displayId: String) {
        loadingFollowUpIds.insert(displayId)
        Task { @MainActor [weak chatUseCase] in
            guard let chatUseCase else { return }
            defer { self.loadingFollowUpIds.remove(displayId) }
            do {
                let fuRes = try await chatUseCase.followUpQuestions(messageId: messageId, useLatestPrompt: true)
                let qs = fuRes.questions ?? []
                let items = qs.map { FollowUpItem(question: $0.question, followUpQuestionId: $0.follow_up_question_id) }
                if !items.isEmpty {
                    self.pendingFollowUps[displayId] = items
                }
            } catch {
                print("[Chat] follow_up_questions failed for \(messageId): \(error)")
            }
        }
    }

    /// Follow-up chip tap (per FOLLOW_UP_QUESTIONS_FLOW.md): if followUpQuestionId present, POST follow_up_question_click with that id; then send question as next user message.
    func sendFollowUp(question: String, followUpQuestionId: String?) async {
        if let id = followUpQuestionId, !id.isEmpty {
            do {
                try await chatUseCase.followUpQuestionClick(followUpQuestion: id)
            } catch {
                print("[Chat] follow_up_question_click failed: \(error)")
            }
        }
        await send(question)
    }

    /// TTS Listen (per CHAT_SCREEN.md §6.7 / §8.4):
    /// - First tap on a message: POST synthesise_audio, cache URL, configure audio session, play.
    /// - Subsequent tap on same message: toggle play/pause without re-POSTing.
    /// - Tap on a different message: discard cache and start over.
    /// - On playback end / error: silently reset state (no user banner).
    func playTTS(messageId: String, text: String) async {
        if isLoadingSynthesiseAudio { return }

        if currentAudioMessageId == messageId, audioPlaybackUrl != nil, let player = ttsPlayer {
            if isAudioPlaying {
                player.pause()
                isAudioPlaying = false
            } else {
                player.play()
                isAudioPlaying = true
            }
            return
        }

        clearAudioPlayback()

        let uid = PreferencesManager.shared.userId ?? ""
        guard !uid.isEmpty else { return }

        isLoadingSynthesiseAudio = true
        defer { isLoadingSynthesiseAudio = false }

        do {
            let res = try await chatUseCase.synthesiseAudio(messageId: messageId, text: text, userId: uid)
            guard let urlString = res.audio, !urlString.isEmpty, let url = URL(string: urlString) else { return }
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.startedPlayingResponseAudio, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.startedPlayingResponseAudio)
            // Without .playback category, remote-URL AVPlayer streams silently fail with FigFilePlayer err=-12864 on simulator.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try? AVAudioSession.sharedInstance().setActive(true, options: [])

            let player = AVPlayer(url: url)
            let item = player.currentItem
            ttsEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.clearAudioPlayback()
            }
            ttsPlayer = player
            audioPlaybackUrl = urlString
            currentAudioMessageId = messageId
            isAudioPlaying = true
            player.play()
        } catch {
            print("[Chat] synthesise_audio failed: \(error)")
            clearAudioPlayback()
        }
    }

    /// Reset TTS playback state. Called on new answer, new send, playback end, or error.
    func clearAudioPlayback() {
        ttsPlayer?.pause()
        ttsPlayer = nil
        if let obs = ttsEndObserver {
            NotificationCenter.default.removeObserver(obs)
            ttsEndObserver = nil
        }
        audioPlaybackUrl = nil
        currentAudioMessageId = nil
        isAudioPlaying = false
    }

    /// Send image via image_analysis (Plantix). Optional query (e.g. "What is wrong with my crop?").
    func sendImage(imageBase64: String, imageName: String, query: String?, originalImage: UIImage? = nil) async {
        if conversationId == nil {
            if let fromPrefs = PreferencesManager.shared.newConversationId {
                conversationId = fromPrefs
            } else {
                do {
                    let res = try await chatUseCase.newConversation()
                    conversationId = res.conversation_id
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }
        guard let cid = conversationId else { return }
        let queryText = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userLabel = queryText.isEmpty ? PreferencesManager.shared.label("fc_v2_app_label_ask_about_your_farm", fallback: "What's wrong with my crop?") : queryText
        messages = messages + [ChatMessageDisplay(id: UUID().uuidString, content: userLabel, isUser: true, image: originalImage)]
        isLoading = true
        defer { isLoading = false }
        let lat = PreferencesManager.shared.lastKnownLat.map { "\($0)" }
        let lng = PreferencesManager.shared.lastKnownLng.map { "\($0)" }
        do {
            let res = try await chatUseCase.imageAnalysis(conversationId: cid, imageBase64: imageBase64, imageName: imageName, query: queryText.isEmpty ? nil : queryText, latitude: lat, longitude: lng, retry: false)
            let msgId = res.message_id
            let ans = res.response
            let imageDisplayId = UUID().uuidString
            messages = messages + [ChatMessageDisplay(id: imageDisplayId, content: ans, isUser: false, backendMessageId: msgId)]
            lastAnswerMessageId = msgId
            let mid = msgId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mid.isEmpty {
                fireFollowUpFetch(messageId: mid, displayId: imageDisplayId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadHistory(_ cid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await chatUseCase.conversationChatHistory(conversationId: cid, page: 1)
            conversationId = cid
            var outMessages: [ChatMessageDisplay] = []
            var outIndex = 0
            for item in res.data {
                let mid = item.message_id.trimmingCharacters(in: .whitespacesAndNewlines)
                if let q = item.query_text, !q.isEmpty {
                    let isDup = outMessages.last.flatMap { last in last.isUser ? last.content : nil } == q
                    if !isDup {
                        let qId = "h_\(outIndex)_q"
                        outIndex += 1
                        outMessages.append(ChatMessageDisplay(id: qId, content: q, isUser: true))
                    }
                }
                if let r = item.response_text, !r.isEmpty {
                    let rId = "h_\(outIndex)_r"
                    outIndex += 1
                    outMessages.append(ChatMessageDisplay(id: rId, content: r, isUser: false, backendMessageId: mid.isEmpty ? nil : item.message_id))
                    if let questions = item.questions, !questions.isEmpty {
                        pendingFollowUps[rId] = questions.map { FollowUpItem(question: $0.question, followUpQuestionId: $0.follow_up_question_id) }
                    }
                }
            }
            messages = outMessages
            if let lastWithResponse = res.data.last(where: { $0.response_text != nil }) {
                lastAnswerMessageId = lastWithResponse.message_id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ShareCard (Android parity: branded 500×700 card with Q&A, rendered to image for Save/Share)

private let shareCardWidth: CGFloat = 500
private let shareCardHeight: CGFloat = 700
// Brand Green700 (matches Android brand.surfacePrimary used for the footer slab).
private let shareCardFooterGreen = Color(hex: 0xFF115E2B)
private let shareAppStoreLink = "https://apps.apple.com/app/farmerchat/id6670191002"
private var shareCaption: String {
    let base = PreferencesManager.shared.label("fc_v2_app_label_share_app_message", fallback: "Sharing what FarmerChat taught me—super useful. Give it a try on the App Store!")
    return "\(base)\n\(shareAppStoreLink)"
}

/// Branded share card — Android parity (ShareCard.kt):
/// optional photo banner → large black title → markdown body → green footer with logo + tagline.
private struct ShareCardView: View {
    let question: String
    let answer: String
    let photo: UIImage?

    private var hasPhoto: Bool { photo != nil }
    private var titleLimit: Int { hasPhoto ? 50 : 70 }
    private var bodyLimit: Int { hasPhoto ? 460 : 940 }

    var body: some View {
        VStack(spacing: 0) {
            // Content capped so footer is always visible at the bottom
            VStack(spacing: 0) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: (shareCardWidth - 32) / 1.85) // Android aspectRatio(1.85)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: hasPhoto ? 14 : 16) {
                    Text(String(question.prefix(titleLimit)))
                        .font(.system(size: hasPhoto ? 24 : 28, weight: .semibold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    MarkdownTextView(
                        text: String(answer.prefix(bodyLimit)),
                        textColor: .black
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, hasPhoto ? 20 : 32)
                .padding(.bottom, 32)

                Spacer(minLength: 0)
            }
            .frame(maxHeight: shareCardHeight - 96)
            .clipped()

            // Footer — brand green bar, logo wordmark + tagline (Android ShareCardFooter)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        LogoMarkShape()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                        Text("FarmerChat")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Practical advice for your farm")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(shareCardFooterGreen)
        }
        .frame(width: shareCardWidth, height: shareCardHeight)
        .background(.white)
    }
}

/// If only a remote URL is available, fetch it before rendering the card.
@MainActor
private func resolveSharePhoto(image: UIImage?, url: String?) async -> UIImage? {
    if let image { return image }
    guard let url, let u = URL(string: url) else { return nil }
    do {
        let (data, _) = try await URLSession.shared.data(from: u)
        return UIImage(data: data)
    } catch {
        return nil
    }
}

/// Render a SwiftUI view to UIImage at the given size.
@MainActor
private func renderShareCardImage(question: String, answer: String, photo: UIImage?) -> UIImage? {
    let view = ShareCardView(question: question, answer: answer, photo: photo)
    let controller = UIHostingController(rootView: view)
    let size = CGSize(width: shareCardWidth, height: shareCardHeight)
    controller.view.bounds = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .white
    controller.view.layoutIfNeeded()

    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
}

/// Write the rendered card to the caches dir so UIActivityViewController can share it as a file.
/// Mirrors Android's FileProvider share (png in cache/images/).
private func writeShareCardToCache(image: UIImage) -> URL? {
    guard let data = image.pngData() else { return nil }
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("images", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("farmerchat_share.png")
    do {
        try data.write(to: url, options: .atomic)
        return url
    } catch {
        return nil
    }
}

private enum SavePhotoResult { case saved, denied, failed }

/// Save image to Photos library. Returns .denied when the user has blocked access so the
/// caller can show a targeted toast and redirect to Settings instead of a generic error.
private func saveImageToPhotos(_ image: UIImage) async -> SavePhotoResult {
    let status: PHAuthorizationStatus
    if #available(iOS 14, *) {
        status = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { cont.resume(returning: $0) }
        }
    } else {
        status = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization { cont.resume(returning: $0) }
        }
    }
    guard status == .authorized || status == .limited else { return .denied }
    let ok = await withCheckedContinuation { cont in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, _ in
            cont.resume(returning: success)
        }
    }
    return ok ? .saved : .failed
}

// MARK: - Share sheet

private struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}

private struct ActivitySheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Camera capture

struct CameraPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}

// MARK: - Photo library picker (PHPickerViewController)

struct LibraryPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else {
                onCancel()
                return
            }
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onImagePicked, onCancel] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        onImagePicked(image)
                    } else {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Voice input result

struct VoiceTranscriptionResult {
    let text: String
    let transcriptionId: String?
    let audioFileURL: URL?
}

// MARK: - Voice input sheet (AVAudioRecorder + backend transcription)

struct VoiceInputSheet: View {
    var onTranscribed: (VoiceTranscriptionResult) -> Void
    var onError: (String) -> Void
    var onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.15, count: 36)
    @State private var elapsedSeconds: Int = 0
    @State private var timerBlinkVisible = true
    @State private var durationTimer: Timer?
    @State private var meterTimer: Timer?
    @State private var audioFileURL: URL?
    private let maxDuration: Int = 30
    private let chatUseCase = ChatUseCase()

    private var remaining: Int { maxDuration - elapsedSeconds }

    private var titleText: String {
        if isProcessing { return PreferencesManager.shared.label("fc_v2_app_label_processing", fallback: "Processing...") }
        return PreferencesManager.shared.label("fc_v2_app_label_listening", fallback: "Speak now")
    }

    private var subtitleText: String {
        if isProcessing { return PreferencesManager.shared.label("fc_v2_app_label_one_second_please", fallback: "One second, please...") }
        if let err = errorMessage { return err }
        return PreferencesManager.shared.label("fc_v2_app_label_ask_your_farming_question", fallback: "Ask about your farm or livestock")
    }

    private var durationString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title + subtitle
            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ContentColors.foregroundPrimary)

                Text(subtitleText)
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(errorMessage != nil && !isProcessing ? AppColors.error : ContentColors.foregroundSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            // Controls: Delete | Waveform | Send
            HStack(spacing: 12) {
                // Cancel (wrong mark)
                Button { handleCancel() } label: {
                    ZStack {
                        Circle().fill(AppColors.authButtonDarkGreen).frame(width: 40, height: 40)
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.accentGreen)
                    }
                }
                .buttonStyle(.plain)

                // Waveform + timer
                ZStack {
                    Capsule()
                        .fill(ContentColors.surfacePrimary)

                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<audioLevels.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isProcessing ? Color(.systemGray4) : AppColors.accentGreen)
                                .frame(width: 3, height: max(6, audioLevels[i] * 30))
                        }
                        Text(durationString)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(isProcessing ? ContentColors.foregroundSecondary.opacity(0.5) : ContentColors.foregroundSecondary)
                            .opacity(remaining <= 5 && isRecording ? (timerBlinkVisible ? 1 : 0) : 1)
                            .frame(minWidth: 36, alignment: .trailing)
                            .padding(.leading, 6)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 50)

                // Confirm (tick)
                Button { handleConfirm() } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.authButtonDarkGreen)
                            .frame(width: 40, height: 40)
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accentGreen))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.accentGreen)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || !isRecording)
            }
            .padding(.horizontal, 20)

            Spacer().frame(height: 32)

            // Footer
            HStack(spacing: 6) {
                Text(PreferencesManager.shared.label("fc_v2_app_label_voice_input_is_still_improving", fallback: "Voice feature is still improving,please record clear audio"))
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isProcessing)
        .onAppear { startRecording() }
        .onDisappear { cleanupTimers() }
    }

    // MARK: - Actions

    private func handleCancel() {
        stopRecording()
        cleanupTimers()
        deleteAudioFile()
        dismiss()
        onCancel()
    }

    private func handleConfirm() {
        guard isRecording, !isProcessing else { return }
        stopRecording()
        isProcessing = true
        Task { await transcribeAndDeliver() }
    }

    private func autoStopAndConfirm() {
        guard isRecording, !isProcessing else { return }
        stopRecording()
        isProcessing = true
        Task { await transcribeAndDeliver() }
    }

    // MARK: - Recording

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        guard session.recordPermission == .granted else {
            session.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed { startRecording() }
                    else { errorMessage = PreferencesManager.shared.label("fc_v2_app_label_microphone_permission_is_required_for_voice_input", fallback: "Microphone permission required.") }
                }
            }
            return
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "audio_recording_\(timestamp).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        audioFileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            return
        }

        isRecording = true
        isProcessing = false
        errorMessage = nil
        elapsedSeconds = 0

        var halfTicks = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                halfTicks += 1
                if halfTicks % 2 == 0 {
                    elapsedSeconds += 1
                    if elapsedSeconds >= maxDuration { autoStopAndConfirm() }
                }
                if (maxDuration - elapsedSeconds) <= 5 {
                    timerBlinkVisible.toggle()
                } else {
                    timerBlinkVisible = true
                }
            }
        }

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            audioRecorder?.updateMeters()
            let power = audioRecorder?.averagePower(forChannel: 0) ?? -160
            let normalizedLevel = max(0.08, min(1.0, CGFloat((power + 50) / 50)))
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.06)) {
                    audioLevels.removeLast()
                    audioLevels.insert(normalizedLevel, at: 0)
                }
            }
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        cleanupTimers()
    }

    private func cleanupTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func deleteAudioFile() {
        guard let url = audioFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        audioFileURL = nil
    }

    // MARK: - Transcription

    private func transcribeAndDeliver() async {
        guard let url = audioFileURL else {
            await MainActor.run {
                onError("No audio recorded.")
                dismiss()
            }
            return
        }

        guard let audioData = try? Data(contentsOf: url) else {
            await MainActor.run {
                deleteAudioFile()
                onError("Could not read audio file.")
                dismiss()
            }
            return
        }

        let base64 = audioData.base64EncodedString()

        var conversationId: String
        if let existing = PreferencesManager.shared.newConversationId {
            conversationId = existing
        } else {
            do {
                let res = try await chatUseCase.newConversation()
                conversationId = res.conversation_id
            } catch {
                await MainActor.run {
                    deleteAudioFile()
                    onError("Failed to start conversation.")
                    dismiss()
                }
                return
            }
        }

        do {
            let res = try await chatUseCase.transcribeAudio(conversationId: conversationId, audioBase64: base64, format: "aac")

            await MainActor.run {
                let heardText = (res.heard_input_query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if !heardText.isEmpty {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.transcriptionSuccess, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.transcriptionSuccess)
                    let result = VoiceTranscriptionResult(
                        text: heardText,
                        transcriptionId: res.transcription_id,
                        audioFileURL: url
                    )
                    onTranscribed(result)
                    dismiss()
                } else {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.transcriptionFailed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.transcriptionFailed)
                    deleteAudioFile()
                    onError(PreferencesManager.shared.label("fc_v2_app_label_transcription_unclear", fallback: "Transcription unclear. Please try again."))
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.transcriptionFailed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.transcriptionFailed)
                deleteAudioFile()
                onError(PreferencesManager.shared.label("fc_v2_app_label_transcription_failed_please_try_again", fallback: "Transcription failed. Please try again."))
                dismiss()
            }
        }
    }
}
