//
//  SettingsView.swift
//  FarmerChat
//
//  UI_SETTINGS.md §1 — DefaultAppBar with Menu, AppearanceModeSelector,
//  ListCard → ListItem("Your name"), SecondaryButton for Logout/Sign up.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppNavigator.self) private var navigator
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var profile: FarmerProfile?
    @State private var toastMessage: String? = nil
    @State private var toastState: ToastState = .success

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: prefs.label("fc_v2_app_label_settings", fallback: "Settings"),
                leftIcon: "line.3.horizontal",
                onLeft: { navigator.showDrawer = true }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    appearanceSection
                    accountDetailsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }
            .background(ContentColors.surfacePrimary)
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toastHost(message: $toastMessage, state: $toastState)
        .task {
            if prefs.isOtpVerified { await loadProfile() }
        }
        .onAppear { checkNameUpdatedToast() }
    }

    // MARK: - Appearance section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prefs.label("fc_v2_app_label_display", fallback: "Display"))
                .font(AppTypography.labelLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)

            AppearanceModeSelector(
                selected: prefs.appearanceMode,
                onSelect: { mode in
                    prefs.appearanceMode = mode
                    prefs.darkThemeEnabled = (mode == .night)
                }
            )

            Text(appearanceCaption)
                .font(AppTypography.caption())
                .foregroundStyle(ContentColors.foregroundSecondary)
        }
    }

    private var appearanceCaption: String {
        switch prefs.appearanceMode {
        case .day: return prefs.label("fc_v2_app_label_farmerchat_always_light_mode", fallback: "FarmerChat is always in light mode")
        case .night: return prefs.label("fc_v2_app_label_farmerchat_always_dark_mode", fallback: "FarmerChat is always in dark mode")
        case .auto: return prefs.label("fc_v2_app_label_farmerchat_adjusts_your_phone_settings", fallback: "FarmerChat adjusts with your phone settings")
        }
    }

    // MARK: - Account details section

    private var accountDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prefs.label("fc_v2_app_label_your_information", fallback: "Your information"))
                .font(AppTypography.labelLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)

            ListCard {
                if prefs.isOtpVerified, !formattedPhone.isEmpty {
                    ListItem(
                        label: "Your phone",
                        rightLabel: formattedPhone,
                        showChevron: false,
                        showDivider: true,
                        action: {}
                    )
                }
                ListItem(
                    label: prefs.label("fc_v2_app_label_your_name", fallback: "Your name"),
                    rightLabel: profileName,
                    showChevron: true,
                    showDivider: false,
                    action: { navigator.navigate(to: .settingsName) }
                )
            }

            Spacer().frame(height: 8)

            if prefs.isOtpVerified {
                SecondaryButton(
                    label: prefs.label("fc_v2_app_label_logout", fallback: "Logout"),
                    height: 48,
                    background: ContentColors.surfaceSecondary,
                    foreground: ContentColors.foregroundPrimary,
                    action: { Task { await logout() } }
                )
            } else {
                PrimaryButton(
                    label: prefs.label("fc_v2_app_label_sign_up", fallback: "Sign up"),
                    state: .chevron,
                    height: 48,
                    action: { navigator.performSignUpGate(viaDrawer: false) }
                )
            }
        }
    }

    private var formattedPhone: String {
        guard let p = profile?.user_profile else { return "" }
        let code = p.phone_country_code?.trimmingCharacters(in: .whitespaces) ?? ""
        let num = p.phone?.trimmingCharacters(in: .whitespaces) ?? ""
        if num.isEmpty { return "" }
        if code.isEmpty { return num }
        let prefix = code.hasPrefix("+") ? code : "+\(code)"
        return "\(prefix) \(num)"
    }

    private var profileName: String {
        if let p = profile {
            let apiName = EnterNameView.sanitizeNameForUi(p.user_profile.name ?? "")
            if !apiName.isEmpty { return apiName }
            let firstLast = EnterNameView.sanitizeNameForUi(
                [p.user_profile.first_name, p.user_profile.last_name]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            )
            if !firstLast.isEmpty { return firstLast }
        }
        let n = EnterNameView.sanitizeNameForUi(prefs.userName ?? "")
        return n.isEmpty ? "—" : n
    }

    // MARK: - Toast trigger

    private func checkNameUpdatedToast() {
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.pendingNameUpdatedToast) else { return }
        UserDefaults.standard.set(false, forKey: PreferenceKeys.pendingNameUpdatedToast)
        // UI_SETTINGS.md §1 — 500ms delay so page transition settles before toast.
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                toastState = .success
                toastMessage = prefs.label("fc_v2_app_label_your_name_has_updated", fallback: "Your name has been updated.")
            }
        }
    }

    // MARK: - Network

    private func loadProfile() async {
        do {
            let p = try await GetProfileUseCase().execute()
            await MainActor.run {
                profile = p
                let apiName = (p.user_profile.name ?? "").trimmingCharacters(in: .whitespaces)
                let raw = apiName.isEmpty
                    ? [p.user_profile.first_name, p.user_profile.last_name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                    : apiName
                let sanitized = EnterNameView.sanitizeNameForUi(raw)
                if !sanitized.isEmpty { prefs.userName = sanitized }
            }
        } catch {}
    }

    private func logout() async {
        do { try await LogoutUseCase().execute() } catch {}
        await MainActor.run {
            prefs.clearOnLogout()
            KeychainManager.shared.clearAll()
            LocationPromptManager.shared.resetAfterLogout()
            navigator.popToRoot()
            navigator.setRoot(.splash)
            navigator.routeFromSplash()
        }
    }
}

// MARK: - AppearanceModeSelector (UI_SETTINGS.md §1)

private struct AppearanceModeSelector: View {
    let selected: AppearanceMode
    let onSelect: (AppearanceMode) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                button(mode)
            }
        }
    }

    private func button(_ mode: AppearanceMode) -> some View {
        let isSelected = selected == mode
        return Button(action: { onSelect(mode) }) {
            VStack(spacing: 10) {
                Image(systemName: icon(for: mode))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .frame(width: 18, height: 18)
                Text(label(for: mode))
                    .font(AppTypography.labelSmall())
                    .foregroundStyle(ContentColors.foregroundPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .background(ContentColors.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected ? ContentColors.borderActive : Color.clear,
                        lineWidth: 2
                    )
            )
            .smoothCorner(Radius.lg)
        }
        .buttonStyle(.plain)
    }

    private func label(for mode: AppearanceMode) -> String {
        let prefs = PreferencesManager.shared
        switch mode {
        case .day: return prefs.label("fc_v2_app_label_day", fallback: "Day")
        case .night: return prefs.label("fc_v2_app_label_night", fallback: "Night")
        case .auto: return prefs.label("fc_v2_app_label_auto", fallback: "Auto")
        }
    }

    private func icon(for mode: AppearanceMode) -> String {
        switch mode {
        case .day: return "sun.max.fill"
        case .night: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }
}
