//
//  AppDrawer.swift
//  FarmerChat
//
//  Side drawer matching Android DrawerContent: logo, nav (Home, Language, Settings, Help),
//  divider, then Recent chats (auth) or Sign up card (anonymous). Uses brand green background.
//

import SwiftUI
import Network

private let drawerWidth: CGFloat = 320
private let rowHeight: CGFloat = 52
private let recentChatRowHeight: CGFloat = 40
private let recentChatRowSpacing: CGFloat = 2
private let radiusMD: CGFloat = 12
private let radiusLG: CGFloat = 16
private let navHorizontalPadding: CGFloat = 12
private let iconSize: CGFloat = 24
private let iconSizeSmall: CGFloat = 18

private let drawerBackground = Color(hex: 0xFF08361B)
private let drawerRowBackground = Color(hex: 0xFF0D4A23)
private let drawerSeeAllGreen = Color(hex: 0xFF008236)
private let drawerSignUpGreen = Color(hex: 0xFF389B3D)
private let drawerForegroundPrimary = AppColors.white
private let drawerForegroundSecondary = AppColors.white.opacity(0.9)
private let drawerDivider = AppColors.white.opacity(0.2)

struct AppDrawer: View {
    @Environment(AppNavigator.self) private var navigator
    @Binding var isPresented: Bool
    @ObservedObject private var prefs = PreferencesManager.shared

    @State private var historyState: Loadable<[ConversationListItem]> = .idle
    @State private var historyItems: [ConversationListItem] = []

    /// Match Android: show Sign up when not OTP-verified; show Recent chats only after phone/OTP login.
    private var isAuthenticated: Bool { prefs.isOtpVerified }
    private var currentLanguageLabel: String {
        prefs.selectedLanguageDisplayName ?? prefs.selectedLanguageId ?? "Language"
    }

    var body: some View {
        HStack(spacing: 0) {
            drawerContent
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 24,
                        topTrailingRadius: 24
                    )
                    .fill(drawerBackground)
                )
                .ignoresSafeArea()
            Color.black.opacity(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task {
            if isAuthenticated { await loadHistory() }
        }
        .onChange(of: isPresented) { _, show in
            if show, isAuthenticated { Task { await loadHistory() } }
        }
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            logoSection
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, 20)

            VStack(spacing: 4) {
                drawerRow(icon: "house.fill", label: prefs.label("fc_v2_app_label_home", fallback: "Home"), selected: isCurrentRouteHome) {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.menuOptionClickEvent, properties: [AnalyticsConstants.Property.optionKey: "home"], adjustToken: AnalyticsConstants.AdjustToken.menuOptionClickEvent)
                    navigator.popToHome()
                    isPresented = false
                }
                drawerRow(icon: "globe", label: "\(prefs.label("fc_v2_app_label_language", fallback: "Language")) (\(currentLanguageLabel))", selected: isCurrentRouteLanguage) {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.menuOptionClickEvent, properties: [AnalyticsConstants.Property.optionKey: "settings/language"], adjustToken: AnalyticsConstants.AdjustToken.menuOptionClickEvent)
                    navigator.navigateDrawerRoute(.settingsLanguage)
                    isPresented = false
                }
                drawerRow(icon: "gearshape.fill", label: prefs.label("fc_v2_app_label_settings", fallback: "Settings"), selected: isCurrentRouteSettings) {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.menuOptionClickEvent, properties: [AnalyticsConstants.Property.optionKey: "settings"], adjustToken: AnalyticsConstants.AdjustToken.menuOptionClickEvent)
                    navigator.navigateDrawerRoute(.settings)
                    isPresented = false
                }
                drawerRow(icon: "questionmark.circle.fill", label: prefs.label("fc_v2_app_label_help_support", fallback: "Help & Support"), selected: isCurrentRouteHelp) {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.menuOptionClickEvent, properties: [AnalyticsConstants.Property.optionKey: "help"], adjustToken: AnalyticsConstants.AdjustToken.menuOptionClickEvent)
                    navigator.navigateDrawerRoute(.help)
                    isPresented = false
                }
            }
            .padding(.horizontal, navHorizontalPadding)

            Spacer(minLength: 8)

            Divider()
                .background(drawerDivider)
                .padding(.horizontal, 0)

            if isAuthenticated {
                recentChatsSection
            } else {
                signUpSection
            }
        }
        .id(isAuthenticated)
    }

    private var logoSection: some View {
        Group {
            if let img = UIImage(named: "LogoWordmark") {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                    .foregroundStyle(drawerForegroundPrimary)
            } else {
                Text("FarmerChat")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(drawerForegroundPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func drawerRow(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.accentGreen)
                    .frame(width: iconSize, height: iconSize)
                Text(label)
                    .font(AppTypography.labelMedium())
                    .foregroundStyle(drawerForegroundPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? drawerRowBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: radiusMD))
        }
        .buttonStyle(.plain)
    }

    private var recentChatsSection: some View {
        VStack(spacing: 0) {
            // Section header always visible — present during loading, error, and populated states.
            Text(prefs.label("fc_v2_app_label_past_advice", fallback: "Past Advice"))
                .font(AppTypography.labelLarge())
                .foregroundStyle(drawerForegroundPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 4)

            if case .loading = historyState {
                VStack(spacing: 12) {
                    LogoSpinner(type: .vertical, continuous: true)
                    Text(prefs.label("fc_v2_app_label_loading_chats", fallback: "Loading chats…"))
                        .font(AppTypography.labelMedium())
                        .foregroundStyle(drawerForegroundSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if case .error(let msg) = historyState {
                errorRetryView(message: msg)
            } else if historyItems.isEmpty {
                Text(prefs.label("fc_v2_app_label_no_chats_yet", fallback: "No chats yet."))
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(drawerForegroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {

                            ForEach(Array(historyItems.prefix(8).enumerated()), id: \.offset) { idx, item in
                                recentChatRow(item: item, index: idx)
                            }
                        }
                        .padding(.horizontal, navHorizontalPadding)
                        .padding(.bottom, 62)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.clear, drawerBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 14)
                        Button {
                            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.chatHistoryClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.menu], adjustToken: AnalyticsConstants.AdjustToken.chatHistoryClick)
                            isPresented = false
                            Task { await navigateToChatHistoryIfOnline() }
                        } label: {
                            HStack(spacing: 6) {
                                Text(prefs.label("fc_v2_app_label_see_all", fallback: "See all"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .font(AppTypography.labelLarge())
                            .foregroundStyle(drawerForegroundPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(drawerSeeAllGreen)
                            .clipShape(RoundedRectangle(cornerRadius: radiusMD))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                    .background(drawerBackground)
                }
            }
            Spacer(minLength: 6)
            Color.clear
                .frame(height: 6)
                .background(drawerBackground)
        }
        .background(drawerBackground)
    }

    private func navigateToChatHistoryIfOnline() async {
        let available = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                cont.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
        await MainActor.run {
            if available {
                navigator.navigateDrawerRoute(.chatHistory)
            } else {
                ErrorNavigationManager.shared.emit(isNetworkError: true, fromScreen: "chatHistory") {
                    ErrorNavigationManager.shared.clear()
                    await MainActor.run { navigator.navigateDrawerRoute(.chatHistory) }
                }
            }
        }
    }

    private static func drawerMessageIcon(_ type: String?) -> String {
        switch type?.lowercased() {
        case "image": return "camera.fill"
        case "audio", "voice": return "mic.fill"
        case "text": return "keyboard"
        default: return "bubble.left.fill"
        }
    }

    private func recentChatRow(item: ConversationListItem, index: Int) -> some View {
        Button {
            let cid = item.displayId.trimmingCharacters(in: .whitespacesAndNewlines)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.chatHistoryClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.sideMenu, "conversation_id": cid, AnalyticsConstants.Property.questionIndex: index], adjustToken: AnalyticsConstants.AdjustToken.chatHistoryClick)
            guard !cid.isEmpty else {
                print("[Drawer] chat item missing conversation_id for title:", item.displayTitle ?? "Chat")
                return
            }
            navigator.navigateDrawerRoute(.chat(conversationId: cid))
            isPresented = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: Self.drawerMessageIcon(item.message_type))
                    .font(.system(size: iconSizeSmall))
                    .foregroundStyle(drawerForegroundPrimary)
                    .frame(width: iconSizeSmall + 4, height: iconSizeSmall + 4)
                Text(item.displayTitle ?? "Chat")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(drawerForegroundPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func errorRetryView(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message.contains("network") || message.contains("internet") ? prefs.label("fc_v2_app_label_no_internet_connection", fallback: "No internet connection") : prefs.label("fc_v2_app_label_failed_to_load_chats", fallback: "Failed to load chats"))
                .font(AppTypography.titleSmall())
                .foregroundStyle(drawerForegroundSecondary)
                .multilineTextAlignment(.center)
            Text(prefs.label("fc_v2_app_label_please_connect_internet_try_again", fallback: "Check your connection and try again"))
                .font(AppTypography.bodySmall())
                .foregroundStyle(drawerForegroundPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(prefs.label("fc_v2_app_label_try_again", fallback: "Try again")) {
                Task { await loadHistory() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private var signUpSection: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(prefs.label("fc_v2_app_label_save_your_questions_answers", fallback: "Save your past questions"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.accentGreen)
                        .multilineTextAlignment(.center)
                    Text(prefs.label("fc_v2_app_label_well_save_your_chats_you_continue", fallback: "Keep your answers\nand come back anytime"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(drawerForegroundPrimary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    navigator.performSignUpGate(viaDrawer: true)
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Text(prefs.label("fc_v2_app_label_sign_up", fallback: "Sign up"))
                            .font(AppTypography.labelLarge())
                            .foregroundStyle(drawerForegroundPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(drawerForegroundPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: 0xFF008236))
                    .clipShape(RoundedRectangle(cornerRadius: radiusMD))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(drawerRowBackground)
        }
        .background(drawerBackground)
    }

    private var isCurrentRouteHome: Bool {
        navigator.path.isEmpty && navigator.lastDrawerSelection == nil
    }
    private var isCurrentRouteLanguage: Bool {
        guard !navigator.path.isEmpty, let sel = navigator.lastDrawerSelection else { return false }
        if case .settingsLanguage = sel { return true }
        return false
    }
    private var isCurrentRouteSettings: Bool {
        guard !navigator.path.isEmpty, let sel = navigator.lastDrawerSelection else { return false }
        if case .settings = sel { return true }
        return false
    }
    private var isCurrentRouteHelp: Bool {
        guard !navigator.path.isEmpty, let sel = navigator.lastDrawerSelection else { return false }
        if case .help = sel { return true }
        return false
    }

    private func loadHistory() async {
        historyState = .loading
        do {
            let res = try await GetConversationListUseCase().execute(page: 1)
            // Filter out invalid/empty ids and dedupe to avoid SwiftUI ForEach id collisions.
            var seen: Set<String> = []
            let list = res.getItems
                .filter { !$0.displayId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { item in
                    let key = item.displayId.trimmingCharacters(in: .whitespacesAndNewlines)
                    return seen.insert(key).inserted
                }
            await MainActor.run {
                historyItems = list
                historyState = .success(list)
            }
        } catch {
            await MainActor.run {
                historyState = .error(error.localizedDescription)
            }
        }
    }

    private func logout() async {
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.logoutClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.settingsScreen], adjustToken: AnalyticsConstants.AdjustToken.logoutClick)
        do {
            try await LogoutUseCase().execute()
        } catch {}
        await MainActor.run {
            prefs.clearOnLogout()
            KeychainManager.shared.clearAll()
            // AnalyticsManager.reset()
            LocationPromptManager.shared.resetAfterLogout()
            // Drop any pending GPS campaign trigger captured from a deep link / push pre-logout.
            navigator.pendingGpsCampaignAction = nil
            navigator.pendingGpsTriggerSource = nil
            isPresented = false
            navigator.setRoot(.splash)
            navigator.routeFromSplash()
        }
    }
}

