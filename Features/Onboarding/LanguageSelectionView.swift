//
//  LanguageSelectionView.swift
//  FarmerChat
//
//  Onboarding design: tractor icon, "Select your language", card grid (light green when selected),
//  Get started button. Existing logic: loadLanguages, submitAndNavigate (accept terms, set language, get labels).
//

import SwiftUI

/// LANGUAGE_SCREEN.md §12 / UI_LANGUAGE.md §3 — first N languages on main screen;
/// the rest appear in AllLanguagesSelectionView.
private let languagePreviewLimit = 5

struct LanguageSelectionView: View {
    @Environment(AppNavigator.self) private var navigator
    @State private var viewModel: LanguageSelectionViewModel
    @State private var showAllLanguages = false

    init(apiClient: APIClient = APIClient(), prefs: PreferencesManager = .shared) {
        _viewModel = State(initialValue: LanguageSelectionViewModel(apiClient: apiClient, prefs: prefs))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    // UI_LANGUAGE.md §1 — 32pt logo tinted borderActive.
                    LogoMarkShape()
                        .fill(ContentColors.borderActive)
                        .frame(width: 32, height: 32)
                        .padding(.top, 32)

                    Text("Choose your language")
                        .font(AppTypography.titleLarge())
                        .foregroundStyle(ContentColors.foregroundPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)

                    Text("You can change this later")
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(ContentColors.foregroundSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    contentArea
                        .padding(.top, 24)

                    // 220pt spacer so list scrolls clear of bottom panel (UI_LANGUAGE.md §2).
                    Spacer().frame(height: 220)
                }
                .padding(.horizontal, 24)
            }
            .background(ContentColors.surfacePrimary)

            bottomPanel
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showAllLanguages) {
            AllLanguagesSelectionView(viewModel: viewModel, onSelect: {})
        }
        .task { await viewModel.loadLanguages() }
    }

    /// LANGUAGE_SCREEN.md §3 / UI_LANGUAGE.md §3 — state → shown content.
    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.languageState {
        case .idle, .loading:
            LogoSpinner(type: .vertical, label: "Loading languages...")
                .padding(.vertical, 40)
        case .error:
            LogoSpinner(type: .vertical, label: "Loading languages...")
                .padding(.vertical, 40)
        case .success(let langs):
            LazyVStack(spacing: 6) {
                ForEach(Array(langs.prefix(languagePreviewLimit)), id: \.id) { lang in
                    SharedRadioButton(
                        label: lang.display_name,
                        isSelected: viewModel.selectedLanguageId == String(lang.id),
                        background: ContentColors.surfacePrimary,
                        onTap: {
                            viewModel.selectedLanguageId = String(lang.id)
                        }
                    )
                }
                if langs.count > languagePreviewLimit {
                    SecondaryButton(
                        label: "More languages",
                        height: 54,
                        action: { showAllLanguages = true }
                    )
                    .padding(.top, 6)
                }
            }
        }
    }

    /// UI_LANGUAGE.md §1 — bottom panel with 24pt top-rounded corners, surfaceSecondary bg.
    private var bottomPanel: some View {
        VStack(spacing: 20) {
            Text("FarmerChat: Practical advice\nfor your crops & animals")
                .font(AppTypography.titleLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)
                .multilineTextAlignment(.center)

            let canSubmit = !viewModel.selectedLanguageId.isEmpty && !viewModel.isSubmitting
            PrimaryButton(
                label: viewModel.isSubmitting ? "Saving…" : "Start using FarmerChat",
                state: canSubmit ? .chevron : .default,
                height: 56,
                isEnabled: canSubmit,
                action: {
                    Task { await viewModel.submitAndNavigate(onSuccess: { navigator.routeFromSplash() }) }
                }
            )

            legalText
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: Radius.xxl,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Radius.xxl,
                style: .continuous
            )
            .fill(ContentColors.surfaceSecondary)
        )
    }

    private var legalText: some View {
        VStack(spacing: 2) {
            Text("By continuing, you agree to our")
                .font(AppTypography.caption())
                .foregroundStyle(ContentColors.foregroundSecondary)
            HStack(spacing: 4) {
                if let terms = viewModel.legalLinks?.termsUrl, let url = URL(string: terms) {
                    Button("Terms of Use") {
                        navigator.navigate(to: .legalContent(url: url, title: "Terms of Use"))
                    }
                    .font(AppTypography.caption())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                    .underline()
                }
                Text("also see")
                    .font(AppTypography.caption())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                if let privacy = viewModel.legalLinks?.privacyUrl, let url = URL(string: privacy) {
                    Button("Privacy Policy.") {
                        navigator.navigate(to: .legalContent(url: url, title: "Privacy Policy"))
                    }
                    .font(AppTypography.caption())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                    .underline()
                }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 260)
    }
}

// MARK: - ViewModel

@Observable
final class LanguageSelectionViewModel {
    var languageState: Loadable<[SupportedLanguage]> = .idle
    var selectedLanguageId = ""
    var searchText = ""
    var isSubmitting = false
    var legalLinks: (termsUrl: String?, privacyUrl: String?)?
    private var allGroups: [SupportedLanguageGroup] = []
    private let authUseCase: AuthUseCase
    private let getSupportedLanguagesUseCase: GetSupportedLanguagesUseCase
    private let setPreferredLanguageUseCase: SetPreferredLanguageUseCase
    private let getLanguageLabelsUseCase: GetLanguageLabelsUseCase
    private let getHelpSupportUseCase: GetHelpSupportUseCase
    private let prefs: PreferencesManager

    init(apiClient: APIClient = APIClient(), prefs: PreferencesManager = .shared) {
        self.prefs = prefs
        let authRepo = AuthRepository(apiClient: apiClient)
        let langRepo = LanguageRepository(apiClient: apiClient)
        self.authUseCase = AuthUseCase(repository: authRepo)
        self.getSupportedLanguagesUseCase = GetSupportedLanguagesUseCase(repository: langRepo, preferences: prefs)
        self.setPreferredLanguageUseCase = SetPreferredLanguageUseCase(repository: langRepo, preferences: prefs)
        self.getLanguageLabelsUseCase = GetLanguageLabelsUseCase(repository: langRepo)
        self.getHelpSupportUseCase = GetHelpSupportUseCase()
    }

    var filteredLanguages: [SupportedLanguage] {
        let all = allGroups.flatMap { $0.languages ?? [] }
        if searchText.isEmpty { return all }
        return all.filter { $0.display_name.localizedCaseInsensitiveContains(searchText) || String($0.id).localizedCaseInsensitiveContains(searchText) || $0.code.localizedCaseInsensitiveContains(searchText) }
    }

    private func ensureGuestUserId() async throws {
        let uid = prefs.userId ?? ""
        if !uid.isEmpty { return }
        let response = try await authUseCase.initializeUser(deviceId: prefs.resolvedDeviceId)
        await MainActor.run {
            if let id = response.user_id { prefs.userId = id }
            if let access = response.access_token {
                prefs.accessToken = access
                KeychainManager.shared.set(value: access, forKey: "APP_ACCESS_TOKEN")
            }
            if let refresh = response.refresh_token {
                prefs.refreshToken = refresh
                KeychainManager.shared.set(value: refresh, forKey: "APP_REFRESH_TOKEN")
            }
            if let cc = response.country_code?.trimmingCharacters(in: .whitespacesAndNewlines), !cc.isEmpty {
                prefs.userCountryCode = cc.uppercased()
            }
            if let name = response.country?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                prefs.userCountryName = name
            }
        }
        if prefs.userId ?? "" == "" {
            throw NSError(domain: "LanguageSelection", code: -2, userInfo: [NSLocalizedDescriptionKey: "Guest init did not return user_id"])
        }
    }

    func loadLanguages() async {
        print("[Language] loadLanguages() called")
        languageState = .loading
        do {
            // Per INITIALIZE_USER_API.md: initialize_user first (sets user_id/tokens + country_code), then fetch languages for that country.
            try await ensureGuestUserId()
            let groups = try await getSupportedLanguagesUseCase.execute(countryCode: prefs.userCountryCode)
            allGroups = groups
            let all = groups.flatMap { $0.languages ?? [] }
            await MainActor.run {
                languageState = .success(all)
                if let first = all.first, selectedLanguageId.isEmpty {
                    selectedLanguageId = String(first.id)
                }
                // Keep display name in sync when we have an id (e.g. from previous session)
                if let id = prefs.selectedLanguageId, let lang = all.first(where: { String($0.id) == id }) {
                    prefs.selectedLanguageDisplayName = lang.display_name
                }
            }
            print("[Language] loadLanguages() success, \(all.count) languages")
            if let help = try? await getHelpSupportUseCase.execute(limit: 5) {
                await MainActor.run {
                    legalLinks = (
                        help.legalResolved?.terms_of_use?.webview_url,
                        help.legalResolved?.privacy_policy?.webview_url
                    )
                }
            }
        } catch {
            print("[Language] loadLanguages() FAILED: \(error)")
            await MainActor.run { languageState = .error(error.localizedDescription) }
        }
    }

    func submitAndNavigate(onSuccess: @escaping () -> Void) async {
        guard !selectedLanguageId.isEmpty else {
            print("[Language] Get started: selectedLanguageId empty, aborting")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        print("[Language] Get started — selectedLanguageId: \(selectedLanguageId), prefs.userId: \(prefs.userId ?? "nil")")
        do {
            try await ensureGuestUserId()
            print("[Language] Calling acceptTerms()...")
            try? await authUseCase.acceptTerms()
            print("[Language] acceptTerms() done")
            print("[Language] Calling setPreferredLanguage(\(selectedLanguageId))...")
            try await setPreferredLanguageUseCase.execute(languageId: selectedLanguageId)
            print("[Language] setPreferredLanguage() done")
            prefs.selectedLanguageId = selectedLanguageId
            let selected = filteredLanguages.first(where: { String($0.id) == selectedLanguageId })
            prefs.selectedLanguageDisplayName = selected?.display_name
            prefs.selectedLanguageCode = selected?.code
            if let displayName = selected?.display_name {
                // UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.preferredLanguage, attributeValue: displayName)
            }
            print("[Language] Calling getLabels(languageId: \(selectedLanguageId))...")
            let labels = try await getLanguageLabelsUseCase.execute(languageId: selectedLanguageId)
            prefs.languageLabels = labels
            prefs.languageLabelsLoaded = true
            print("[Language] getLabels() done, labels count: \(labels.count)")
            prefs.firstTimeOnboardingCompleted = false
            prefs.onboardingLanguageDone = true
            print("[Language] Calling onSuccess() to navigate...")
            await MainActor.run { onSuccess() }
            print("[Language] onSuccess() completed — should have navigated away")
        } catch {
            print("[Language] Get started FAILED: \(error)")
            if let apiError = error as? APIError, case .server(let code, let body) = apiError {
                print("[Language] API error — status: \(code), body: \(body ?? "nil")")
            }
            await MainActor.run {
                languageState = .error(error.localizedDescription)
            }
        }
    }
}
