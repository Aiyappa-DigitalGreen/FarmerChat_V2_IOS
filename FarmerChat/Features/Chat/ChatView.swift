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
private let chatUserBubbleBg = AppColors.adaptiveSecondaryGroupedBackground
private let chatAiBubbleBg = AppColors.adaptiveSecondaryGroupedBackground
private let chatActionGreen = AppColors.authButtonDarkGreen
private let chatActionBarGreen = AppColors.authButtonDarkGreen
private let chatRelatedCardBg = AppColors.adaptiveSecondaryGroupedBackground
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
            // UI_CHAT.md §5.3 — initial fetch error (no messages yet) uses FullScreenMessage;
            // follow-up errors use the inline banner (UI_CHAT.md §5.4) above an existing thread.
            if viewModel.messages.isEmpty, let err = viewModel.errorMessage {
                FullScreenMessage(
                    title: "",
                    mainMessage: "Something went wrong",
                    subtitle: err,
                    primaryCtaLabel: "Try again",
                    primaryCtaState: .chevron,
                    onPrimaryCta: {
                        viewModel.clearError()
                        Task { await viewModel.loadIfNeeded() }
                    },
                    illustration: "farmer_looking_at_sky",
                    enableDebounce: true
                )
            } else {
                messagesList
                if viewModel.isLoading {
                    TipsCarousel(tips: answerGenerationTips())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.adaptiveGroupedBackground)
                }
                inputBar
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
                    .foregroundStyle(AppColors.onboardingWhite)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(chatActionGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .bottom) {
            if pendingPhoto != nil {
                photoInputBar
            }
        }
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
                    TextField("Ask about your farm...", text: $photoCaption, axis: .vertical)
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
                        Image(systemName: "arrow.up")
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
                Button("Try again") {
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
            .background(AppColors.adaptiveGroupedBackground)
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
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.authHeaderGreen)
                            .frame(width: 24, height: 24)
                            .background(AppColors.accentGreen.opacity(0.15))
                            .clipShape(Circle())
                        Text("AI may be wrong. Please double-check.")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.adaptiveFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            if showResponseExtras, let followUps = viewModel.followUps(for: msg.id), !followUps.isEmpty {
                relatedQuestionsSection(followUps: followUps)
            }
            // Android ChatResponseActions.kt:172-178 — hint lives inside ChatResponseActions,
            // so it disappears with everything else while loading.
            if !msg.isUser, !(msg.content ?? "").isEmpty, showResponseExtras {
                let hasFollowUps = !(viewModel.followUps(for: msg.id) ?? []).isEmpty
                Text(hasFollowUps ? "Or ask a follow-up question 👇" : "Ask a follow-up question 👇")
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
            Text("Read full advice")
                .font(AppTypography.labelLarge())
                .foregroundStyle(AppColors.onboardingWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(chatActionGreen)
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
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 14))
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
                    } else {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                    }
                    Text(isThisPlaying ? "Pause" : "Listen")
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
                    Text("Share")
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
                        saveToast.wrappedValue = "Failed to save"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast.wrappedValue = nil }
                        return
                    }
                    let ok = await saveImageToPhotos(image)
                    saveToast.wrappedValue = ok ? "Saved to gallery" : "Failed to save"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast.wrappedValue = nil }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                    Text("Save")
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
            Text("Related questions")
                .font(.system(size: 17, weight: .bold))
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
                            Text("Ask")
                                .font(AppTypography.labelMedium())
                                .foregroundStyle(AppColors.onboardingWhite)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(chatAskButtonGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(chatRelatedCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accentGreen.opacity(0.4), lineWidth: 1))
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
                HStack(spacing: 12) {
                    TextField("Type your question...", text: $inputText, axis: .vertical)
                        .focused($isInputFocused)
                        .textFieldStyle(.plain)
                        .font(AppTypography.bodyMedium())
                        .padding(14)
                        .background(AppColors.adaptiveSecondaryGroupedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.adaptiveSeparator, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .lineLimit(1...4)
                        .onAppear { isInputFocused = true }
                    Button("Send") {
                        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        inputText = ""
                        showTextInput = false
                        Task { await viewModel.send(text) }
                    }
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(AppColors.onboardingWhite)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(chatActionGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.adaptiveSecondaryGroupedBackground)
            }

            HStack(spacing: 12) {
                Menu {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    Button {
                        showPhotoLibrary = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                        Text("Photo")
                            .font(AppTypography.labelSmall())
                    }
                    .foregroundStyle(AppColors.onboardingWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(chatActionBarGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                Button {
                    if PreferencesManager.shared.asrEnabled {
                        showVoiceInput = true
                    } else {
                        let labels = PreferencesManager.shared.languageLabels
                        let message = labels["ASR_DISABLED_FOR_SELECTED_LANGUAGE"]
                            ?? "Voice input is not available for your selected language"
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
                        Text("Speak")
                            .font(AppTypography.labelSmall())
                    }
                    .foregroundStyle(AppColors.onboardingWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(chatActionBarGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                Button {
                    showTextInput = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 24))
                        Text("Type")
                            .font(AppTypography.labelSmall())
                    }
                    .foregroundStyle(AppColors.onboardingWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(chatActionBarGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(chatHeaderGreen)
        }
        .background(AppColors.adaptiveSecondaryGroupedBackground)
        .onChange(of: isInputFocused) { _, focused in
            if !focused && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showTextInput = false
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessageDisplay
    var showListenButton: Bool = false
    var onListen: (() -> Void)? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false

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
                        if let text = message.content, !text.isEmpty {
                            Text(text)
                                .font(AppTypography.bodyMedium())
                                .foregroundStyle(AppColors.adaptiveLabel)
                                .frame(maxWidth: .infinity, alignment: message.wideBannerImage ? .leading : .trailing)
                                .padding(.horizontal, message.wideBannerImage ? 10 : 0)
                                .padding(.bottom, message.wideBannerImage ? 6 : 0)
                        }
                        if message.audioURL != nil {
                            Button {
                                toggleAudioPlayback()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                                        .font(.system(size: 12))
                                    Text(isPlayingAudio ? "Stop" : "Play audio")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(AppColors.authButtonDarkGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColors.accentGreen.opacity(0.15))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(message.image != nil || message.wideBannerImage ? 6 : 16)
                    .background(chatUserBubbleBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                } else {
                    MarkdownTextView(
                        text: message.content ?? "",
                        textColor: AppColors.adaptiveLabel
                    )
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            if !message.isUser { Spacer(minLength: 48) }
        }
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
            if duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                    isPlayingAudio = false
                }
            }
        } catch {
            print("[Chat] Audio playback failed: \(error)")
        }
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
            ProgressView()
                .tint(AppColors.authHeaderGreen)
            Text("Getting your answer...")
                .font(AppTypography.bodySmall())
                .foregroundStyle(AppColors.authHeaderGreen)
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
    private var lastAnswerMessageId: String?
    private var pendingFollowUps: [String: [FollowUpItem]] = [:]
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
            await send(q)
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

        // Android ChatViewModel.kt:784 — client generates a UUID per message for server-side deduplication.
        let messageIdForThisRequest = UUID().uuidString
        let triggeredType = transcriptionId != nil ? "audio" : "text"
        do {
            let res = try await chatUseCase.getAnswerForTextQuery(conversationId: cid, query: queryToSend, messageId: messageIdForThisRequest, triggeredInputType: triggeredType, transcriptionId: transcriptionId, statementId: statementIdToSend, weatherCtaTriggered: weatherCta)
            isLoading = false
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
            isLoading = false
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
        do {
            let res = try await chatUseCase.getAnswerForTextQuery(conversationId: cid, query: text, messageId: UUID().uuidString, triggeredInputType: "audio", transcriptionId: transcriptionId, statementId: nil, weatherCtaTriggered: false)
            isLoading = false
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
            isLoading = false
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

    /// "Read full advice" tap (CHAT_SCREEN.md §2.3 F, §8.6). APPENDS a duplicate user
    /// bubble and loading; does NOT replace the pre-gen pair. Sends
    /// triggered_input_type="read_full_advice" + statement_id=homeStatementId.
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

        // Clear the pre-gen pair so the full-advice request looks like a fresh chat
        // (user asked for "fresh question at the top" — no old summary visible).
        let freshUserMsgId = UUID().uuidString
        messages = [ChatMessageDisplay(id: freshUserMsgId, content: question, isUser: true)]
        isLoading = true
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
            isLoading = false
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
            isLoading = false
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
        Task { @MainActor [weak chatUseCase] in
            guard let chatUseCase else { return }
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
        let userLabel = queryText.isEmpty ? "What's wrong with my crop?" : queryText
        messages = messages + [ChatMessageDisplay(id: UUID().uuidString, content: userLabel, isUser: true, image: originalImage)]
        isLoading = true
        let lat = PreferencesManager.shared.lastKnownLat.map { "\($0)" }
        let lng = PreferencesManager.shared.lastKnownLng.map { "\($0)" }
        do {
            let res = try await chatUseCase.imageAnalysis(conversationId: cid, imageBase64: imageBase64, imageName: imageName, query: queryText.isEmpty ? nil : queryText, latitude: lat, longitude: lng, retry: false)
            isLoading = false
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
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadHistory(_ cid: String) async {
        isLoading = true
        do {
            let res = try await chatUseCase.conversationChatHistory(conversationId: cid, page: 1)
            isLoading = false
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
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ShareCard (Android parity: branded 500×700 card with Q&A, rendered to image for Save/Share)

private let shareCardWidth: CGFloat = 500
private let shareCardHeight: CGFloat = 700
// Brand Green700 (matches Android brand.surfacePrimary used for the footer slab).
private let shareCardFooterGreen = Color(hex: 0xFF115E2B)
private let shareCaption = "Sharing what FarmerChat taught me—super useful. Give it a try on the App Store!"

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

/// Save image to Photos library. Uses PHPhotoLibrary so we actually get a success/failure
/// signal and handle authorization (Android parity: returns Boolean success for toast).
private func saveImageToPhotos(_ image: UIImage) async -> Bool {
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
    guard status == .authorized || status == .limited else { return false }
    return await withCheckedContinuation { cont in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, _ in
            cont.resume(returning: success)
        }
    }
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
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.15, count: 40)
    @State private var elapsedSeconds: Int = 0
    @State private var durationTimer: Timer?
    @State private var meterTimer: Timer?
    @State private var audioFileURL: URL?
    private let maxDuration: Int = 30
    private let chatUseCase = ChatUseCase()

    private var titleText: String {
        if isProcessing { return "Processing..." }
        if isRecording { return "Listening..." }
        return "Tap to speak"
    }

    private var subtitleText: String {
        if isProcessing { return "One second, please." }
        if isRecording { return "Speak now" }
        if let err = errorMessage { return err }
        return "Tap the microphone to start"
    }

    private var durationString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text(titleText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.adaptiveLabel)

                Text(subtitleText)
                    .font(.system(size: 16))
                    .foregroundStyle(errorMessage != nil && !isRecording && !isProcessing ? AppColors.error : AppColors.adaptiveSecondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            HStack(spacing: 12) {
                Button {
                    handleCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.accentGreen)
                        .frame(width: 52, height: 52)
                        .background(AppColors.authButtonDarkGreen)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.gray.opacity(0.12))

                    HStack(spacing: 1.5) {
                        ForEach(0..<audioLevels.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(AppColors.authButtonDarkGreen.opacity(0.6))
                                .frame(width: 2.5, height: max(3, audioLevels[i] * 32))
                        }

                        Spacer().frame(width: 8)

                        Text(durationString)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 48)

                Button {
                    handleConfirm()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.authButtonDarkGreen)
                            .frame(width: 52, height: 52)

                        if isRecording && !isProcessing {
                            Circle()
                                .stroke(AppColors.accentGreen, lineWidth: 3)
                                .frame(width: 58, height: 58)
                                .opacity(0.5)
                        }

                        Image(systemName: isProcessing ? "hourglass" : (isRecording ? "checkmark" : "mic.fill"))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppColors.accentGreen)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
            .padding(.horizontal, 20)

            Spacer().frame(height: 32)

            Text("Speak is a beta feature")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.adaptiveSecondaryLabel)

            Spacer()
        }
        .padding()
        .background(AppColors.adaptiveGroupedBackground)
        .presentationDetents([.medium])
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
                    else { errorMessage = "Microphone permission required." }
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

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                elapsedSeconds += 1
                if elapsedSeconds >= maxDuration { autoStopAndConfirm() }
            }
        }

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            audioRecorder?.updateMeters()
            let power = audioRecorder?.averagePower(forChannel: 0) ?? -160
            let normalizedLevel = max(0.08, min(1.0, CGFloat((power + 50) / 50)))
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.06)) {
                    audioLevels.removeFirst()
                    audioLevels.append(normalizedLevel)
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
                let confidence = res.confidence_score ?? 0
                let heardText = (res.heard_input_query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if confidence > 0.7 && !heardText.isEmpty {
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
                    let msg = heardText.isEmpty ? "Transcription unclear. Please try again." : "Couldn't understand: \"\(heardText)\""
                    onError(msg)
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.transcriptionFailed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatScreen], adjustToken: AnalyticsConstants.AdjustToken.transcriptionFailed)
                deleteAudioFile()
                onError("Transcription failed. Please try again.")
                dismiss()
            }
        }
    }
}
