//
//  HomeView.swift
//  FarmerChat
//
//  Matches Android HomeScreen: app bar (menu + weather button), greeting, feed cards, input row (Photo/Speak/Type).
//

import SwiftUI
import AVFoundation
import UIKit

private let appBarHeight: CGFloat = 64
private let inputButtonHeight: CGFloat = 78
private let radiusMD: CGFloat = 12
private let radiusLG: CGFloat = 16
private let homeHeaderLightGreen = Color(hex: 0xFF08361B)
private let homeCardGreen = Color(hex: 0xFF08361B)
private let homeSelectionGreen = Color(hex: 0xFF00C950)

struct HomeView: View {
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: HomeViewModel
    @State private var locationPromptManager = LocationPromptManager.shared
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var weatherAlpha: Double = 0
    @State private var showHomeVoice = false
    @State private var showHomeCamera = false
    @State private var showHomePhotoLibrary = false
    @State private var showHomeTextInput = false
    @State private var homeInputText = ""
    @State private var showPhotoSourcePicker = false
    @State private var pendingHomePhoto: UIImage?
    @State private var homePhotoCaption = ""
    @FocusState private var isHomeInputFocused: Bool
    @FocusState private var isHomeCaptionFocused: Bool

    init(apiClient: APIClient = APIClient(), prefs: PreferencesManager = .shared) {
        _viewModel = State(initialValue: HomeViewModel(apiClient: apiClient, prefs: prefs))
    }

    private var leadingToolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .cancellationAction
        #endif
    }


    var body: some View {
        ZStack {
            // Sits behind everything — fills the full screen including safe areas.
            // NavigationStack content starts at the safe-area boundary, so the only
            // region this green is visible is the status bar area above it.
            BrandColors.surfacePrimary.ignoresSafeArea()

            NavigationStack(path: Binding(get: { navigator.path }, set: { navigator.path = $0 })) {
                content
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
        }
        .id(navigator.drawerPathVersion)
        .overlay {
            if locationPromptManager.state.shouldShowOverlay {
                LocationPromptView(manager: locationPromptManager)
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                locationPromptManager.onSceneBecameActive()
            }
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
        .task(id: navigator.homeRefreshTrigger) {
            await viewModel.load()
            // SDKEventHooks.requestPushPermissionOnHome()
        }
        .onChange(of: viewModel.feedState.isLoading) { _, loading in
            withAnimation(.easeInOut(duration: 0.4)) {
                let weatherLoading = viewModel.weatherState.isLoading
                weatherAlpha = (loading || weatherLoading) ? 0 : 1
            }
        }
        .onChange(of: viewModel.weatherState.isLoading) { _, weatherLoading in
            withAnimation(.easeInOut(duration: 0.4)) {
                let screenLoading = viewModel.feedState.isLoading
                weatherAlpha = (screenLoading || weatherLoading) ? 0 : 1
            }
        }
        .onAppear {
            let isWeatherLoading = viewModel.weatherState.isLoading
            weatherAlpha = (viewModel.feedState.isLoading || isWeatherLoading) ? 0 : 1
        }
        .onAppear {
            if let (action, source) = navigator.consumePendingGpsCampaign() {
                LocationPromptManager.shared.triggerFromCampaign(action: action, triggerSource: source)
            }
            // AnalyticsManager.trackScreenView(screenName: AnalyticsConstants.Screen.dashboardScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.screenViewed)
            if !(PreferencesManager.shared.dashboardFirstTimeViewed) {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.firstTimeDashboardViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.firstTimeDashboardViewed)
                PreferencesManager.shared.dashboardFirstTimeViewed = true
            }
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.dashboardViewed, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.dashboardViewed)
        }
        .onDisappear {
            // AnalyticsManager.trackScreenExit(screenName: AnalyticsConstants.Screen.dashboardScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenExited, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.screenExited)
        }
        // LOCATION_SCREEN.md §7 — campaign-sourced location update fires LocationUpdatedFromWidget;
        // show the "Location updated" toast and refetch the feed so any location-dependent cards refresh.
        .onReceive(NotificationCenter.default.publisher(for: LocationPromptManager.locationUpdatedFromWidgetNotification)) { _ in
            viewModel.showToast(PreferencesManager.shared.label("fc_v2_app_label_location_updated", fallback: "Location updated"), isError: false)
            navigator.homeRefreshTrigger += 1
        }
        // Android parity: drawer/in-app nav must dismiss the Type input and any pending photo bar
        // so they don't hover over pushed destinations (Settings, History, etc.).
        .onChange(of: navigator.path) { _, newPath in
            if !newPath.isEmpty {
                showHomeTextInput = false
                homeInputText = ""
                isHomeInputFocused = false
                pendingHomePhoto = nil
                homePhotoCaption = ""
            }
        }
        .sheet(isPresented: $showPhotoSourcePicker) {
            HomePhotoSourcePicker(
                onCamera: {
                    showPhotoSourcePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showHomeCamera = true }
                },
                onLibrary: {
                    showPhotoSourcePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showHomePhotoLibrary = true }
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showHomeCamera) {
            CameraPickerView(
                onImagePicked: { image in
                    showHomeCamera = false
                    pendingHomePhoto = image
                    homePhotoCaption = ""
                },
                onCancel: { showHomeCamera = false }
            )
        }
        .sheet(isPresented: $showHomePhotoLibrary) {
            LibraryPickerView(
                onImagePicked: { image in
                    showHomePhotoLibrary = false
                    pendingHomePhoto = image
                    homePhotoCaption = ""
                },
                onCancel: { showHomePhotoLibrary = false }
            )
        }
        .sheet(isPresented: $showHomeVoice) {
            VoiceInputSheet(
                onTranscribed: { result in
                    showHomeVoice = false
                    navigator.navigate(to: .chat(question: result.text, transcriptionId: result.transcriptionId, audioFileURL: result.audioFileURL))
                },
                onError: { msg in
                    showHomeVoice = false
                    viewModel.showToast(msg, isError: true)
                },
                onCancel: { showHomeVoice = false }
            )
        }
        .overlay(alignment: .bottom) {
            if showHomeTextInput {
                homeTextInputBar
            }
        }
        .overlay(alignment: .bottom) {
            if pendingHomePhoto != nil {
                homePhotoInputBar
            }
        }
    }

    private func navigateWithImage(_ image: UIImage, caption: String?) {
        let question = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        navigator.pendingImage = image
        navigator.navigate(to: .chat(question: (question?.isEmpty ?? true) ? PreferencesManager.shared.label("fc_v2_app_label_what_is_wrong_with_my_crop", fallback: "What's wrong with my crop?") : question))
    }

    private var homeTextInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button {
                    showHomeTextInput = false
                    homeInputText = ""
                    showPhotoSourcePicker = true
                } label: {
                    ZStack {
                        Circle().fill(homeCardGreen).frame(width: 48, height: 48)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColors.onboardingWhite)
                    }
                }
                .buttonStyle(.plain)

                TextField(prefs.label("fc_v2_app_label_ask_about_your_farm", fallback: "Ask about your farm..."), text: $homeInputText, axis: .vertical)
                    .focused($isHomeInputFocused)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyMedium())
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColors.adaptiveSecondaryGroupedBackground)
                    .clipShape(Capsule())
                    .onAppear { isHomeInputFocused = true }

                Button {
                    let text = homeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        homeInputText = ""
                        showHomeTextInput = false
                        navigator.navigate(to: .chat(question: text))
                    } else {
                        showHomeTextInput = false
                        homeInputText = ""
                        showHomeVoice = true
                    }
                } label: {
                    ZStack {
                        Circle().fill(homeCardGreen).frame(width: 48, height: 48)
                        Image(systemName: homeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColors.onboardingWhite)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.adaptiveSecondaryGroupedBackground)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: showHomeTextInput)
    }

    private var homePhotoInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if let img = pendingHomePhoto {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            pendingHomePhoto = nil
                            homePhotoCaption = ""
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
                    TextField(prefs.label("fc_v2_app_label_ask_about_your_farm", fallback: "Ask about your farm..."), text: $homePhotoCaption, axis: .vertical)
                        .focused($isHomeCaptionFocused)
                        .textFieldStyle(.plain)
                        .font(AppTypography.bodyMedium())
                        .lineLimit(1...3)
                        .onAppear { isHomeCaptionFocused = true }

                    Button {
                        guard let img = pendingHomePhoto else { return }
                        let caption = homePhotoCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                        pendingHomePhoto = nil
                        homePhotoCaption = ""
                        navigateWithImage(img, caption: caption.isEmpty ? nil : caption)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(AppColors.accentGreen)
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
        .animation(.easeOut(duration: 0.2), value: pendingHomePhoto != nil)
    }

    private var toastOverlay: some View {
        Group {
            if let msg = viewModel.toastMessage, !msg.isEmpty {
                Text(msg)
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(viewModel.toastIsError ? AppColors.error : AppColors.green700)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: viewModel.toastMessage)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                homeAppBarRow
                greetingStrip
                inputButtonsRow
                feedBody
            }
            .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height, alignment: .top)
            .background(ContentColors.surfacePrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surfacePrimary.ignoresSafeArea(edges: .top))
    }

    // UI_HOME.md §4 — hamburger + weather, brand green slab + yellow Glow.
    // Scrolls away beneath the sticky input row.
    private var homeAppBarRow: some View {
        ZStack {
            Glow(type: .yellow)
                .frame(height: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            HStack(spacing: 12) {
                ActionButton(icon: "line.3.horizontal", radius: Radius.md) {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.hamburgerMenuClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.hamburgerMenuClicked)
                    navigator.showDrawer = true
                }
                Spacer(minLength: 0)
                if let img = UIImage(named: "LogoWordmark") {
                    Image(uiImage: img)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .foregroundStyle(BrandColors.foregroundPrimary)
                }
                Spacer(minLength: 0)
                weatherButtonHeader
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 64)
        // Extend the brand-green background up behind the status bar so iOS shows
        // white status bar icons on the dark green surface (matching Figma).
        .background(BrandColors.surfacePrimary.ignoresSafeArea(edges: .top))
    }

    // UI_HOME.md §3 — Crossfade(300ms) between GreetingSkeleton and the real text.
    // Wobble fires 1000ms after mount when the real greeting is showing.
    private var greetingStrip: some View {
        let text = prefs.label(
            "fc_v2_app_label_get_started_by_clicking_on_photo_speak_or_type_to_ask_your_question",
            fallback: "Get started by clicking on Photo, Speak, or Type to ask your question"
        )
        return ZStack {
            BrandColors.surfacePrimary
            Text(text)
                .font(AppTypography.titleMedium())
                .foregroundStyle(BrandColors.foregroundPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
        }
        .frame(height: 48)
    }

    // UI_HOME.md §5 — sticky Photo/Speak/Type row. `pinnedViews` on the parent
    // LazyVStack pins this under the status bar when the feed scrolls up.
    private var inputButtonsRow: some View {
        HStack(spacing: 8) {
            inputButton(icon: "camera.fill", label: prefs.label("fc_v2_app_label_photo", fallback: "Photo")) {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.chatIconClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.icon: "Image"], adjustToken: AnalyticsConstants.AdjustToken.chatIconClicked)
                showPhotoSourcePicker = true
            }
            inputButton(icon: "mic.fill", label: prefs.label("fc_v2_app_label_speak", fallback: "Speak")) {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.microphoneClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.microphoneClickEvent)
                showHomeVoice = true
            }
            inputButton(icon: "keyboard", label: prefs.label("fc_v2_app_label_type", fallback: "Type")) {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.chatIconClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.icon: "Text"], adjustToken: AnalyticsConstants.AdjustToken.chatIconClicked)
                showHomeTextInput = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(BrandColors.surfacePrimary)
        .disabled(contentLoadingBlocked)
    }

    private var contentLoadingBlocked: Bool {
        if viewModel.feedState.isLoading && viewModel.feedState.value == nil { return true }
        return locationPromptManager.state.isFetchingSilently
    }

    // UI_HOME.md §1, §4 — feed loader | error | success body. Matches Android: plain spinner while loading, content at full opacity when ready.
    @ViewBuilder
    private var feedBody: some View {
        if case .error = viewModel.feedState {
            homeFeedErrorView
        } else if viewModel.feedState.value != nil {
            VStack(alignment: .leading, spacing: 0) {
                FeedHeader(title: prefs.label("fc_v2_app_label_for_your_farm_today", fallback: "For your farm today..."))
                    .attentionWobble(trigger: true, delayMs: 1600)
                feedSectionCards
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                FeedFooter(tagline: prefs.label("fc_v2_app_label_have_a_great_day_come_back_tomorrow", fallback: "Have a great day, come back tomorrow"))
                    .padding(.horizontal, 24)
            }
        } else {
            homeFeedLoader
        }
    }

    private var homeFeedLoader: some View {
        // UI_HOME.md §7 — widget-triggered GPS uses a different label.
        let label = locationPromptManager.state.isFetchingSilently
            ? prefs.label("fc_v2_app_label_getting_your_location", fallback: "Getting your location...")
            : prefs.label("fc_v2_app_label_getting_todays_advice", fallback: "Getting today's advice")
        return VStack(spacing: 12) {
            LogoSpinner(type: .vertical, color: AppColors.green500, label: label)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 420)
        .padding(.top, 32)
    }

    private var homeFeedErrorView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.red500)
                    .frame(width: 64, height: 64)
                Image(systemName: "xmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.white)
            }
            Text(prefs.label("fc_v2_app_label_cant_load_right_now", fallback: "Can't load right now"))
                .font(AppTypography.titleMedium())
                .foregroundStyle(ContentColors.foregroundPrimary)
                .multilineTextAlignment(.center)
            Button {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.contentTryAgainClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.contentTryAgainClicked)
                Task { await viewModel.load() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text(prefs.label("fc_v2_app_label_try_again", fallback: "Try again"))
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
        .frame(maxWidth: .infinity)
        .frame(minHeight: 420)
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private var weatherButtonHeader: some View {
        Button {
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.weatherForecastViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen], adjustToken: AnalyticsConstants.AdjustToken.weatherForecastViewed)
            guard locationPromptManager.state == .idle else { return }
            let weatherNav = {
                navigator.navigate(to: .chat(question: PreferencesManager.shared.label("fc_v2_app_label_what_is_the_present_weather", fallback: "What is the present weather?"), conversationId: nil, isWeatherAdviceCTA: true))
            }
            if !PreferencesManager.shared.isLocationEnabledOnce {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.locationUpdateTriggered, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.trigger: "Weather", AnalyticsConstants.Property.attempt: 1], adjustToken: AnalyticsConstants.AdjustToken.locationUpdateTriggered)
            }
            locationPromptManager.triggerInterstitial(pendingNavigation: weatherNav)
        } label: {
            Group {
                if case .loading = viewModel.weatherState {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.green500)
                            .frame(width: 7, height: 7)
                        Text(prefs.label("fc_v2_app_label_loading", fallback: "Loading"))
                            .font(AppTypography.labelMedium())
                            .foregroundStyle(AppColors.onboardingWhite)
                    }
                } else if let w = viewModel.weatherState.value {
                    HStack(spacing: 6) {
                        if let iconUrlStr = w.weather_icon, !iconUrlStr.isEmpty, let iconUrl = URL(string: iconUrlStr) {
                            AsyncImage(url: iconUrl) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFit()
                                } else {
                                    Image("weather_sunclouds").resizable().scaledToFit()
                                }
                            }
                            .frame(width: 22, height: 22)
                        } else {
                            Image("weather_sunclouds")
                                .resizable().scaledToFit()
                                .frame(width: 22, height: 22)
                        }
                        Text(w.current_temp ?? "\(Int(w.current?.temp ?? 0))°")
                            .font(AppTypography.labelMedium())
                            .foregroundStyle(AppColors.onboardingWhite)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.onboardingWhite.opacity(0.7))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image("weather_sunclouds")
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                        Text("--°")
                            .font(AppTypography.labelMedium())
                            .foregroundStyle(AppColors.onboardingWhite)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.onboardingWhite.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(homeHeaderLightGreen)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.weatherState.isLoading)
        .opacity(weatherAlpha)
    }

    // UI_HOME.md §2 — feed cards only (FeedHeader/FeedFooter are rendered in feedBody).
    // First rendered card gets a 2200ms wobble per §3.
    @ViewBuilder
    private var feedSectionCards: some View {
        if case .success(let res) = viewModel.feedState {
            // HOME_SCREEN.md §4.5 — plotline_widget cards have no iOS surface (no SDK integration).
            // §4.4 — dismissedSectionKeys hides question cards 6s after successful submit.
            let dedupedSections = Self.deduplicateSections(res.sections ?? [])
                .filter { ($0.type ?? "").lowercased() != "plotline_widget" }
                .filter { !viewModel.isDismissed(section: $0) }
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(dedupedSections.enumerated()), id: \.offset) { index, section in
                    Group {
                        if viewModel.isSelectionSection(section) {
                            selectionCard(section: section)
                                .padding(.bottom, 6)
                        } else {
                            let isImageType = section.type?.lowercased() == "image"
                            let options = Self.deduplicateOptions(section.options ?? [])
                            if options.isEmpty {
                                if let title = (section.title ?? section.statement ?? section.meta?.title), !title.isEmpty {
                                    let chatQuestion = section.question_text ?? title
                                    feedCardButton(section: section, title: title, payload: chatQuestion) {
                                        handleContentCardTap(section: section, question: chatQuestion)
                                    }
                                    .onAppear {
                                        if isImageType, let sid = section.statementIdString { viewModel.markViewed(statementId: sid) }
                                    }
                                }
                            } else {
                                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                                    let cardTitle = option.displayText ?? option.text ?? ""
                                    feedCardButton(section: section, title: cardTitle, payload: option.payload ?? option.displayText ?? option.text) {
                                        viewModel.trackCardClicked(section: section, option: option)
                                        handleContentCardTap(section: section, question: option.payload ?? option.displayText ?? option.text ?? "")
                                    }
                                    .onAppear {
                                        if isImageType, let sid = section.statementIdString { viewModel.markViewed(statementId: sid) }
                                        viewModel.trackCardViewed(section: section, option: option)
                                    }
                                }
                            }
                        }
                    }
                    .attentionWobble(trigger: index == 0, delayMs: 2200)
                    .onAppear { viewModel.trackCardShown(section: section) }
                }
            }
            .padding(.vertical, 8)
        } else {
            EmptyView()
        }
    }

    private func selectionCard(section: SectionDto) -> some View {
        let prompt = (section.question_text ?? section.statement ?? section.title ?? section.meta?.subtitle ?? section.meta?.title ?? "")
        let options = section.options ?? []
        let mode = viewModel.selectionMode(for: section)
        let isSubmitting = viewModel.isSubmitting(section: section)
        let showSubmit = viewModel.shouldShowSubmit(section: section)
        let canSubmit = viewModel.canSubmit(section: section)
        let submitTitle = viewModel.submitButtonTitle(for: section)
        let isTagStyle = mode == .multi
        return VStack(alignment: .leading, spacing: 12) {
            // UI_HOME.md §2 — explicit dismiss: delay(3000) then dismiss card.
            if !prompt.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(prompt)
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(AppColors.adaptiveLabel)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        viewModel.scheduleDismissExplicit(section: section)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.adaptiveSecondaryLabel)
                            .frame(width: 28, height: 28)
                            .background(AppColors.adaptiveFill)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }
            if isTagStyle {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                            let title = option.displayText ?? option.text ?? ""
                            let selected = viewModel.isSelected(section: section, option: option)
                            Button {
                                viewModel.toggleSelection(section: section, option: option)
                            } label: {
                                Text(title)
                                    .font(AppTypography.bodyMedium())
                                    .foregroundStyle(selected ? homeSelectionGreen : AppColors.adaptiveLabel)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 13)
                                    .background(selected ? homeSelectionGreen.opacity(0.10) : AppColors.adaptiveFill)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(selected ? homeSelectionGreen : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 260)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                            let title = option.displayText ?? option.text ?? ""
                            let selected = viewModel.isSelected(section: section, option: option)
                            Button {
                                viewModel.toggleSelection(section: section, option: option)
                            } label: {
                                Text(title)
                                    .font(AppTypography.bodyMedium())
                                    .foregroundStyle(selected ? homeSelectionGreen : AppColors.adaptiveLabel)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 13)
                                    .background(selected ? homeSelectionGreen.opacity(0.10) : AppColors.adaptiveFill)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(selected ? homeSelectionGreen : Color.clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            if showSubmit {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        Task { await viewModel.submitSelection(section: section) }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.85)
                                    .tint(AppColors.buttonPrimaryForeground)
                            }
                            Text(submitTitle)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.adaptiveSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadii.xl))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private func selectionIcon(isSelected: Bool, mode: HomeViewModel.SelectionMode) -> String {
        switch mode {
        case .single:
            return isSelected ? "circle.inset.filled" : "circle"
        case .multi:
            return isSelected ? "checkmark.square.fill" : "square"
        }
    }

    private func handleContentCardTap(section: SectionDto, question: String) {
        let imageUrl = section.image_url
        Task {
            let statementId = section.statementIdString
            let cardType = section.type ?? "statement"
            if let sid = statementId, !sid.isEmpty {
                do {
                    let res = try await viewModel.fetchImageStatement(statementId: sid, triggeredInputType: cardType)
                    await MainActor.run {
                        navigator.navigate(to: .chat(
                            question: question,
                            conversationId: nil,
                            imageUri: imageUrl,
                            preGeneratedAnswer: res.answer,
                            followUpQuestions: res.followUps ?? [],
                            homeStatementId: sid
                        ))
                    }
                } catch {
                    await MainActor.run {
                        navigator.navigate(to: .chat(question: question, conversationId: nil))
                    }
                }
            } else {
                navigator.navigate(to: .chat(question: question, conversationId: nil))
            }
        }
    }

    private func feedCardButton(section: SectionDto, title: String, payload: String?, action: @escaping () -> Void) -> some View {
        let imageURL: URL? = {
            guard let urlStr = section.image_url, !urlStr.isEmpty else { return nil }
            return URL(string: urlStr)
        }()
        let badge = section.badge
        let badgeCount = Int(badge?.count ?? "") ?? 0
        let showBadge = badge?.show == true && badgeCount > 0
        let questionText = section.question_text ?? ""

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL {
                    ZStack(alignment: .topTrailing) {
                        RetryableAsyncImage(url: imageURL, reloadId: navigator.homeRefreshTrigger)

                        if showBadge {
                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(badgeCountString(badgeCount))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(10)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(!questionText.isEmpty ? questionText : title)
                        .font(AppTypography.bodyLarge())
                        .foregroundStyle(AppColors.adaptiveLabel)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Spacer()
                        Text("Learn more")
                            .font(AppTypography.onboardingButtonText())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(AppColors.onboardingWhite)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(homeCardGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.adaptiveSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private func badgeCountString(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return thousands.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(thousands)),\(String(format: "%03d", count % 1000))"
                : String(format: "%.1fK", thousands)
        }
        return "\(count)"
    }

    private static func deduplicateSections(_ sections: [SectionDto]) -> [SectionDto] {
        var seenKeys = Set<String>()
        return sections.filter { section in
            let title = (section.title ?? section.statement ?? section.meta?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let question = (section.question_text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let compositeKey = "\(title)||\(question)"
            guard !compositeKey.isEmpty, compositeKey != "||" else { return true }
            return seenKeys.insert(compositeKey).inserted
        }
    }

    private static func deduplicateOptions(_ options: [OptionDto]) -> [OptionDto] {
        var seen = Set<String>()
        return options.filter { option in
            let text = (option.displayText ?? option.text ?? option.payload ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }
            return seen.insert(text).inserted
        }
    }

    private func inputButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(AppColors.onboardingWhite)
                Text(label)
                    .font(AppTypography.labelSmall())
                    .foregroundStyle(AppColors.onboardingWhite)
            }
            .frame(maxWidth: .infinity)
            .frame(height: inputButtonHeight)
            .background(homeHeaderLightGreen)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(_ dest: AppDestination) -> some View {
        switch dest {
        case .chat(_, let question, let conversationId, let imageUri, let transcriptionId, let audioFileURL, let preGeneratedAnswer, let followUpQuestions, let homeStatementId, let isWeatherAdviceCTA):
            ChatView(
                question: question,
                conversationId: conversationId,
                imageUri: imageUri,
                transcriptionId: transcriptionId,
                audioFileURL: audioFileURL,
                preGeneratedAnswer: preGeneratedAnswer,
                followUpQuestions: followUpQuestions ?? [],
                homeStatementId: homeStatementId,
                isWeatherAdviceCTA: isWeatherAdviceCTA
            )
        case .chatHistory:
            ChatHistoryView()
        case .settings:
            SettingsView()
        case .settingsName:
            SettingsNameView()
        case .settingsLanguage:
            LanguageChooserView()
        case .help:
            HelpView()
        case .accountBenefits:
            AccountBenefitsView()
        case .auth:
            AuthView()
        case .accountSuccess:
            AccountSuccessView()
        default:
            EmptyView()
        }
    }
}

// MARK: - HomeViewModel

@Observable
final class HomeViewModel {
    var feedState: Loadable<HomeUdfResponse> = .idle
    var weatherState: Loadable<WeatherResponse> = .idle
    var userName: String? { prefs.userName }
    var profile: FarmerProfile?
    var selectedOptionKeysBySection: [String: Set<String>] = [:]
    private var lastSubmittedOptionKeysBySection: [String: Set<String>] = [:]
    private var submittingSectionKeys: Set<String> = []
    /// HOME_SCREEN.md §4.4 — question cards (gender/crop/livestock) vanish 6s after a successful submit.
    /// Cleared on feed refresh so the card can reappear if the backend still returns it.
    var dismissedSectionKeys: Set<String> = []
    var toastMessage: String?
    var toastIsError: Bool = false
    private let homeUseCase: HomeUseCase
    private let prefs: PreferencesManager
    /// Track statement_ids we've already sent to PATCH viewed (per HOME_AND_CHAT_COMPLETE_APIS.md).
    private var viewedStatementIds: Set<String> = []
    /// Track cards we've already sent Card_Viewed for (once per card).
    private var cardViewedIds: Set<String> = []

    /// Greeting from daily feed API, or fallback to time-based (per HOME_AND_CHAT_COMPLETE_APIS.md).
    var greetingFromFeed: String? { feedState.value?.greeting }

    var greetingTitle: String {
        if let g = greetingFromFeed, !g.isEmpty { return g }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    init(apiClient: APIClient = APIClient(), prefs: PreferencesManager = .shared) {
        self.homeUseCase = HomeUseCase(repository: HomeRepository(apiClient: apiClient), preferences: prefs)
        self.prefs = prefs
    }

    /// Home load (per HOME_AND_CHAT_COMPLETE_APIS.md): new_conversation first, then daily feed, weather, view_user_profile.
    func load() async {
        do {
            _ = try await homeUseCase.newConversation()
        } catch {
            print("[Home] new_conversation failed: \(error)")
        }
        async let feed: () = loadFeed()
        async let weather: () = loadWeather()
        async let profile: () = loadUserProfileIfNeeded()
        _ = await (feed, weather, profile)
    }

    /// Mark image card viewed (PATCH api/images/v2/viewed/). Call when card is visible; once per statement_id (per MD).
    func markViewed(statementId: String) {
        guard !viewedStatementIds.contains(statementId) else { return }
        guard let uid = prefs.userId, !uid.isEmpty else { return }
        viewedStatementIds.insert(statementId)
        Task {
            do {
                try await homeUseCase.markImageViewed(statementId: statementId, userId: uid, status: "viewed")
            } catch {
                viewedStatementIds.remove(statementId)
            }
        }
    }

    private func loadUserProfileIfNeeded() async {
        guard let uid = prefs.userId, !uid.isEmpty else { return }
        do {
            let profile = try await homeUseCase.fetchUserProfile()
            await MainActor.run {
                self.profile = profile
                let apiName = (profile.user_profile.name ?? "").trimmingCharacters(in: .whitespaces)
                let firstLast = [profile.user_profile.first_name, profile.user_profile.last_name]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                let raw = apiName.isEmpty ? firstLast : apiName
                let sanitized = EnterNameView.sanitizeNameForUi(raw)
                if !sanitized.isEmpty {
                    prefs.userName = sanitized
                    prefs.userNameAdded = true
                }
                if let roleText = profile.user_profile.role?.first?.text ?? profile.user_profile.role?.first?.id, !roleText.isEmpty {
                    prefs.userRole = roleText
                }
                trackProfileAttributes(profile: profile)
            }
        } catch {
            print("[Home] view_user_profile failed: \(error)")
        }
    }

    private func trackProfileAttributes(profile: FarmerProfile) {
        let p = profile.user_profile
        // if let v = p.first_name { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.FIRST_NAME, attributeValue: v) }
        // if let v = p.name { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.NAME, attributeValue: v) }
        // if let v = p.gender { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.GENDER, attributeValue: v) }
        // if let v = p.age { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.AGE, attributeValue: v) }
        // if let v = p.llm_model { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.LLM_MODEL, attributeValue: v) }
        // if let v = p.preferred_language { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.PREFERRED_LANGUAGE, attributeValue: v) }
        // if let phone = p.phone { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.PHONE_NO, attributeValue: phone) }
        // if let v = p.receive_com_via_whatsapp { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.CONSENT_WHATSAPP, attributeValue: v) }
        if let roleNames = p.role?.compactMap({ $0.text ?? $0.id }), !roleNames.isEmpty { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.ROLE, attributeValue: roleNames.joined(separator: ",")) }
        if let crops = p.crop_details?.compactMap({ $0.text ?? $0.id }), !crops.isEmpty { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.CROPS, attributeValue: crops) }
        // if let live = p.live_stock_details, !live.isEmpty, let data = try? JSONEncoder().encode(live) { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.LIVESTOCK, attributeValue: String(data: data, encoding: .utf8) ?? "[]") }
        // if let mem = p.memory, let data = try? JSONEncoder().encode(mem) { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.MEMORY, attributeValue: String(data: data, encoding: .utf8) ?? "{}") }
        if let a = p.address {
            // if let v = a.country { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.country, attributeValue: v) }
            // if let v = a.state { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.state, attributeValue: v) }
            // if let v = a.level_2 { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.district, attributeValue: v) }
            // if let v = a.level_3 { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.block, attributeValue: v) }
            // if let v = a.level_4 { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.village, attributeValue: v) }
            // if let v = a.level_5 ?? a.level_6 ?? a.city { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.locality, attributeValue: v) }
        }
        // if let v = p.country_name { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.country, attributeValue: v) }
        // if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.APP_VERSION, attributeValue: version) }
        // if let code = Bundle.main.infoDictionary?["CFBundleVersion"] as? String { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.APP_VERSION_CODE, attributeValue: code) }
        // UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.BUILD_VERSION, attributeValue: "V2")
    }

    func trackCardShown(section: SectionDto) {
        var props: [String: Any] = [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen]
        if let t = section.type { props[AnalyticsConstants.Property.cardType] = t }
        if let t = section.title ?? section.meta?.title { props[AnalyticsConstants.Property.cardCategory] = t }
        if let sid = section.statementIdString { props["sentence_id"] = sid; props["image_id"] = sid }
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.cardShown, properties: props, adjustToken: AnalyticsConstants.AdjustToken.cardShown)
    }

    func trackCardViewed(section: SectionDto, option: OptionDto) {
        let id = "\(sectionKey(section))_\(optionKey(option))"
        guard cardViewedIds.insert(id).inserted else { return }
        var props: [String: Any] = [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen]
        if let t = section.type { props[AnalyticsConstants.Property.cardType] = t }
        if let t = section.title ?? section.meta?.title { props[AnalyticsConstants.Property.cardCategory] = t }
        if let sid = section.statementIdString { props["sentence_id"] = sid; props["image_id"] = sid }
        if let text = option.displayText ?? option.text { props[AnalyticsConstants.Property.text] = text }
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.cardViewed, properties: props, adjustToken: AnalyticsConstants.AdjustToken.cardViewed)
    }

    func trackCardClicked(section: SectionDto, option: OptionDto) {
        var props: [String: Any] = [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen]
        if let t = section.type { props[AnalyticsConstants.Property.cardType] = t }
        if let t = section.title ?? section.meta?.title { props[AnalyticsConstants.Property.cardCategory] = t }
        if let sid = section.statementIdString { props["sentence_id"] = sid; props["image_id"] = sid }
        if let text = option.displayText ?? option.text { props[AnalyticsConstants.Property.text] = text }
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.cardClicked, properties: props, adjustToken: AnalyticsConstants.AdjustToken.cardClicked)
    }

    /// Fetch short_answer + follow_up_questions for a content card (mirrors Android FetchImageStatement).
    func fetchImageStatement(statementId: String, triggeredInputType: String) async throws -> (answer: String?, followUps: [String]?) {
        let res = try await homeUseCase.getImageStatement(statementId: statementId, triggeredInputType: triggeredInputType)
        let followUps = res.follow_up_questions?
            .sorted { $0.sequence < $1.sequence }
            .map { $0.question }
        return (res.short_answer, followUps)
    }

    private func loadFeed() async {
        feedState = .loading
        // HOME_SCREEN.md §4.4 — clear dismissals on refresh so backend can re-serve cards if still relevant.
        dismissedSectionKeys.removeAll()
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.apiCallInitiated, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.apiName: "Dashboard Content"], adjustToken: AnalyticsConstants.AdjustToken.apiCallInitiated)
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = TimeZone.current
            let timeStr = formatter.string(from: Date())
            let res = try await homeUseCase.getHomeFeed(userDeviceTime: timeStr, userId: prefs.userId)
            let sectionCount = res.sections?.count ?? 0
            let sectionTitles = (res.sections ?? []).map { $0.title ?? $0.statement ?? $0.meta?.title ?? "(no title)" }
            print("[Home] daily feed: \(sectionCount) sections, titles: \(sectionTitles)")
            for (i, s) in (res.sections ?? []).enumerated() {
                print("[Home] section[\(i)]: type=\(s.type ?? "nil"), image_url=\(s.image_url != nil ? "YES" : "nil"), options=\(s.options?.count ?? 0), question_text=\(s.question_text ?? "nil")")
            }
            await MainActor.run {
                feedState = .success(res)
                // HOME_SCREEN.md §7.1 — cache successful feed JSON for offline fallback.
                if let data = try? JSONEncoder().encode(res), let json = String(data: data, encoding: .utf8) {
                    prefs.cachedHomeFeedResponse = json
                }
            }
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.apiCallSuccess, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.apiName: "Dashboard Content"], adjustToken: AnalyticsConstants.AdjustToken.apiCallSuccess)
        } catch {
            // HOME_SCREEN.md §13 — on API failure with cached feed, show cached data silently; else error UI.
            if let cachedJson = prefs.cachedHomeFeedResponse,
               let data = cachedJson.data(using: .utf8),
               let cached = try? JSONDecoder().decode(HomeUdfResponse.self, from: data) {
                await MainActor.run { feedState = .success(cached) }
            } else {
                await MainActor.run { feedState = .error(error.localizedDescription) }
            }
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.apiCallFailed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.apiName: "Dashboard Content"], adjustToken: AnalyticsConstants.AdjustToken.apiCallFailed)
        }
    }

    private func loadWeather() async {
        // Guest: skip weather call when no user_id (mirrors Android; avoids 404 "User profile not found").
        let uid = prefs.userId ?? ""
        if uid.trimmingCharacters(in: .whitespaces).isEmpty {
            await MainActor.run { weatherState = .idle }
            return
        }
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.apiCallInitiated, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.apiName: "Weather"], adjustToken: AnalyticsConstants.AdjustToken.apiCallInitiated)
        do {
            let res = try await homeUseCase.getWeather()
            await MainActor.run { weatherState = .success(res) }
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.apiCallSuccess, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.apiName: "Weather"], adjustToken: AnalyticsConstants.AdjustToken.apiCallSuccess)
        } catch {
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.apiCallFailed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.dashboardScreen, AnalyticsConstants.Property.apiName: "Weather"], adjustToken: AnalyticsConstants.AdjustToken.apiCallFailed)
            if let apiError = error as? APIError,
               case let .server(code, _) = apiError,
               code == 404,
               (apiError.errorDescription ?? "").lowercased().contains("profile") {
                // Guest without profile (no location yet): show default instead of error (matches Android behavior).
                await MainActor.run { weatherState = .success(WeatherResponse(current_temp: nil, precipitation_probability: nil, weather_icon: nil, current: nil, forecast: nil)) }
            } else {
                await MainActor.run { weatherState = .error(error.localizedDescription) }
            }
        }
    }

    enum SelectionMode {
        case single
        case multi
    }

    enum SelectionKind {
        case gender
        case livestock
        case crop
        case unknown
    }

    func isSelectionSection(_ section: SectionDto) -> Bool {
        let hasOptions = (section.options?.isEmpty == false)
        let st = (section.selection_type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return hasOptions && !st.isEmpty
    }

    func selectionMode(for section: SectionDto) -> SelectionMode {
        if selectionKind(for: section) == .gender { return .single }
        let st = (section.selection_type ?? "").lowercased()
        if st.contains("single") { return .single }
        if st.contains("radio") { return .single }
        return .multi
    }

    func selectionKind(for section: SectionDto) -> SelectionKind {
        // Primary matching per GENDER_LIVESTOCK_CROP_API.md (Android behavior)
        // - gender: section.id == "question" and selection_type == "single"
        // - livestock: section.id == "livestock"
        // - crop: section.id == "crop"
        let sectionId = section.id?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let st = (section.selection_type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if sectionId == "livestock" { return .livestock }
        if sectionId == "crop" { return .crop }
        if sectionId == "question", st == "single" || st.contains("single") || st.contains("radio") { return .gender }

        let blob = [
            section.selection_type,
            section.statement_type,
            section.type,
            section.title,
            section.question_text,
            section.statement,
            section.meta?.title,
            section.meta?.subtitle
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        if blob.contains("gender") { return .gender }
        if blob.contains("livestock") || blob.contains("live_stock") || blob.contains("live stock") || blob.contains("animal") { return .livestock }
        if blob.contains("crop") || blob.contains("crops") || blob.contains("cultiv") { return .crop }

        let optionTexts = (section.options ?? []).compactMap { ($0.payload ?? $0.displayText ?? $0.text)?.lowercased() }
        let joined = optionTexts.joined(separator: " ")
        if joined.contains("female") || joined.contains("male") || joined.contains("other") { return .gender }
        if joined.contains("cow") || joined.contains("goat") || joined.contains("sheep") || joined.contains("buffalo") || joined.contains("poultry") { return .livestock }
        if joined.contains("rice") || joined.contains("wheat") || joined.contains("maize") || joined.contains("chilli") || joined.contains("tomato") { return .crop }

        return .unknown
    }

    func isSelected(section: SectionDto, option: OptionDto) -> Bool {
        let sKey = sectionKey(section)
        let oKey = optionKey(option)
        return selectedOptionKeysBySection[sKey]?.contains(oKey) == true
    }

    func toggleSelection(section: SectionDto, option: OptionDto) {
        let sKey = sectionKey(section)
        let oKey = optionKey(option)
        var current = selectedOptionKeysBySection[sKey] ?? []
        switch selectionMode(for: section) {
        case .single:
            // Match Android radio UX: selecting again doesn't clear.
            if current.contains(oKey) { return }
            current = [oKey]
        case .multi:
            if current.contains(oKey) { current.remove(oKey) } else { current.insert(oKey) }
        }
        selectedOptionKeysBySection[sKey] = current
    }

    func submitButtonTitle(for section: SectionDto) -> String {
        let st = (section.selection_type ?? "").lowercased()
        if st.contains("gender") { return "Submit" }
        if st.contains("livestock") { return "Submit" }
        if st.contains("crop") { return "Submit" }
        return "Submit"
    }

    func isSubmitting(section: SectionDto) -> Bool {
        submittingSectionKeys.contains(sectionKey(section))
    }

    func shouldShowSubmit(section: SectionDto) -> Bool {
        let sKey = sectionKey(section)
        let selected = selectedOptionKeysBySection[sKey] ?? []
        let last = lastSubmittedOptionKeysBySection[sKey] ?? []
        return selected != last || submittingSectionKeys.contains(sKey)
    }

    func canSubmit(section: SectionDto) -> Bool {
        let sKey = sectionKey(section)
        let st = (section.selection_type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !st.isEmpty else { return false }

        let selected = selectedOptionKeysBySection[sKey] ?? []
        let last = lastSubmittedOptionKeysBySection[sKey] ?? []
        if selected == last { return false }

        // Gender requires a non-empty selection.
        if st.contains("gender") { return !selected.isEmpty }
        // Livestock / crop can submit empty to clear.
        return true
    }

    @MainActor
    func submitSelection(section: SectionDto) async {
        let uid = (prefs.userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty, prefs.isOtpVerified else {
            showToast("Please sign in to save your details.", isError: true)
            return
        }
        let st = (section.selection_type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !st.isEmpty else { return }

        let sKey = sectionKey(section)
        guard !submittingSectionKeys.contains(sKey) else { return }
        submittingSectionKeys.insert(sKey)
        defer { submittingSectionKeys.remove(sKey) }

        let selectedOptions: [OptionDto] = (section.options ?? []).filter { isSelected(section: section, option: $0) }

        do {
            switch selectionKind(for: section) {
            case .gender:
                // Per MD: send option.id as-is (e.g. "gender_male")
                let raw = (selectedOptions.first?.id?.stringValue ?? selectedOptions.first?.payload ?? selectedOptions.first?.displayText ?? selectedOptions.first?.text ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else {
                    showToast("Please select a gender.", isError: true)
                    return
                }
                try await homeUseCase.updateUserProfile(gender: raw)
            case .livestock:
                let details: [LiveStockDetail] = selectedOptions.compactMap { opt in
                    // Per MD: type uses option.id as-is (e.g. "livestock_cow")
                    let raw = (opt.id?.stringValue ?? opt.payload ?? opt.displayText ?? opt.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !raw.isEmpty else { return nil }
                    return LiveStockDetail(count: 1, type: raw)
                }
                try await homeUseCase.updateUserProfile(liveStockDetails: details)
            case .crop:
                // Per MD: crop_details uses option.id as-is (crop IDs)
                let cropIds: [String] = Array(Set(selectedOptions.compactMap { opt in
                    (opt.id?.stringValue ?? opt.payload ?? opt.displayText ?? opt.text)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                })).filter { !$0.isEmpty }
                _ = try await homeUseCase.updateCropDetails(cropDetails: cropIds)
            case .unknown:
                print("[Home] submitSelection unsupported. selection_type=\(section.selection_type ?? "nil"), statement_type=\(section.statement_type ?? "nil"), title=\(section.title ?? section.question_text ?? section.statement ?? "nil")")
                showToast("Unsupported selection type.", isError: true)
                return
            }

            lastSubmittedOptionKeysBySection[sKey] = selectedOptionKeysBySection[sKey] ?? []
            switch selectionKind(for: section) {
            case .gender:
                // if let v = selectedOptions.first.flatMap({ $0.displayText ?? $0.payload ?? $0.text }) { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.gender, attributeValue: v) }
                break
            case .livestock:
                let arr = selectedOptions.compactMap { $0.displayText ?? $0.payload ?? $0.text }
                // if !arr.isEmpty { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.livestock, attributeValue: arr) }
            case .crop:
                let arr = selectedOptions.compactMap { $0.id?.stringValue ?? $0.payload ?? $0.displayText ?? $0.text }
                // if !arr.isEmpty { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.crops, attributeValue: arr) }
            case .unknown: break
            }
            showToast("Saved.", isError: false)
            // HOME_SCREEN.md §4.4 — after success show checkmark/toast, then dismiss the card 6 s later.
            scheduleDismiss(sectionKey: sKey)
        } catch {
            showToast(error.localizedDescription, isError: true)
        }
    }

    /// Returns true if this section was dismissed (e.g. after a successful selection submit).
    func isDismissed(section: SectionDto) -> Bool {
        dismissedSectionKeys.contains(sectionKey(section))
    }

    private func scheduleDismiss(sectionKey: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            dismissedSectionKeys.insert(sectionKey)
        }
    }

    /// UI_HOME.md §2 — explicit dismiss (X button): delay(3000) then remove card.
    /// Android MultiSelectCard/SingleSelectCard commit b0b9b47: onDismissed fires after 3s.
    func scheduleDismissExplicit(section: SectionDto) {
        let key = sectionKey(section)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dismissedSectionKeys.insert(key)
        }
    }

    func showToast(_ message: String, isError: Bool) {
        toastIsError = isError
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { self.toastMessage = nil }
            }
        }
    }

    private func sectionKey(_ section: SectionDto) -> String {
        if let s = section.id?.stringValue, !s.isEmpty { return "id:\(s)" }
        if let s = section.statementIdString, !s.isEmpty { return "sid:\(s)" }
        if let t = section.type, !t.isEmpty { return "type:\(t)" }
        if let t = section.title ?? section.meta?.title, !t.isEmpty { return "title:\(t)" }
        // Deterministic fallback (must be stable across renders)
        let st = (section.selection_type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prompt = (section.question_text ?? section.statement ?? section.meta?.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let optionSig = (section.options ?? []).prefix(8).map { opt in
            (opt.id?.stringValue ?? opt.payload ?? opt.displayText ?? opt.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }.joined(separator: "|")
        return "sel:\(st)|prompt:\(prompt)|opts:\(optionSig)"
    }

    private func optionKey(_ option: OptionDto) -> String {
        if let s = option.id?.stringValue, !s.isEmpty { return "id:\(s)" }
        if let p = option.payload, !p.isEmpty { return "payload:\(p)" }
        if let t = option.displayText, !t.isEmpty { return "text:\(t)" }
        return UUID().uuidString
    }
}

private extension AnyCodable {
    var stringValue: String? {
        if let s = value as? String { return s }
        if let i = value as? Int { return "\(i)" }
        if let d = value as? Double { return "\(d)" }
        if let b = value as? Bool { return b ? "true" : "false" }
        return nil
    }
}

// MARK: - Retryable image loader

private struct RetryableAsyncImage: View {
    let url: URL
    let reloadId: Int
    @State private var retryCount = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(height: 180)
                    .overlay(ProgressView())
                    .task(id: retryCount) {
                        guard retryCount < 5 else { return }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        retryCount += 1
                    }
            default:
                Rectangle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(height: 180)
                    .overlay(ProgressView())
            }
        }
        .id("\(url.absoluteString)-\(reloadId)-\(retryCount)")
        .onChange(of: reloadId) { _, _ in retryCount = 0 }
    }
}

// MARK: - Photo source picker (Home screen)

private struct HomePhotoSourcePicker: View {
    var onCamera: () -> Void
    var onLibrary: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button(action: onCamera) {
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

                Button(action: onLibrary) {
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
            .padding(.top, 20)
        }
    }
}

// MARK: - Section statement_id (API can return Int or String)
private extension SectionDto {
    var statementIdString: String? {
        guard let v = statement_id?.value else { return nil }
        if let s = v as? String, !s.isEmpty { return s }
        if let i = v as? Int { return "\(i)" }
        return nil
    }
}
