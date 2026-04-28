//
//  SettingsNameView.swift
//  FarmerChat
//
//  UI_SETTINGS.md §2 — DefaultAppBar "Name" + back arrow, FormTextInput,
//  56pt PrimaryButton (Chevron/Loading), Toast for validation.
//

import SwiftUI

struct SettingsNameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isLoading = false
    @State private var toastMessage: String? = nil
    @State private var toastState: ToastState = .error
    @FocusState private var isFocused: Bool
    private let prefs = PreferencesManager.shared

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var buttonEnabled: Bool {
        let c = trimmed.count
        return c >= 1 && c <= 100
    }
    private var primaryState: PrimaryButtonState {
        if isLoading { return .loading }
        return buttonEnabled ? .chevron : .default
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: PreferencesManager.shared.label("fc_v2_app_label_name", fallback: "Name"),
                leftIcon: "arrow.backward",
                onLeft: { dismiss() },
                background: ContentColors.surfaceSecondary,
                foreground: ContentColors.foregroundPrimary,
                iconBackground: ContentColors.foregroundPrimary.opacity(0.1)
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormTextInput(
                        text: $name,
                        placeholder: PreferencesManager.shared.label("fc_v2_app_label_enter_your_name", fallback: "Enter your name"),
                        label: PreferencesManager.shared.label("fc_v2_app_label_your_name_or_nickname", fallback: "Your name or nickname"),
                        state: isLoading ? .disabled : .active,
                        autocapitalization: .words,
                        isFocused: isFocused
                    )
                    .focused($isFocused)
                    .onChange(of: name) { _, newValue in
                        let normalized = EnterNameView.normalizeNameInput(newValue)
                        if normalized != newValue { name = normalized }
                    }

                    PrimaryButton(
                        label: isLoading ? PreferencesManager.shared.label("fc_v2_app_label_saving", fallback: "Saving") : PreferencesManager.shared.label("fc_v2_app_label_save_name", fallback: "Save name"),
                        state: primaryState,
                        height: 56,
                        isEnabled: buttonEnabled && !isLoading,
                        action: {
                            isFocused = false
                            Task { await save() }
                        }
                    )
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
        .onAppear {
            // UI_SETTINGS.md §2 — pre-fill from prefs, sanitize "No Name"/"null".
            let raw = (prefs.userName ?? "").trimmingCharacters(in: .whitespaces)
            name = EnterNameView.sanitizeNameForUi(raw)
            prefs.nameScreenSeenOnce = true
        }
    }

    private func save() async {
        let n = trimmed
        if n.count < 3 {
            toastState = .error
            toastMessage = "\(PreferencesManager.shared.label("fc_v2_app_label_name_must_be_at_least", fallback: "Name must be at least")) 3 \(PreferencesManager.shared.label("fc_v2_app_label_characters", fallback: "characters"))"
            return
        }
        if n.count > 100 {
            toastState = .error
            toastMessage = "\(PreferencesManager.shared.label("fc_v2_app_label_name_must_be_at_most", fallback: "Name must be at most")) 100 \(PreferencesManager.shared.label("fc_v2_app_label_characters", fallback: "characters"))"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await UpdateUserNameUseCase().execute(name: n)
            await MainActor.run {
                let fromApi = (res.user_profile.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !fromApi.isEmpty {
                    prefs.userName = fromApi
                } else {
                    let firstLast = [res.user_profile.first_name, res.user_profile.last_name]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    prefs.userName = firstLast.isEmpty ? n : firstLast
                }
                prefs.userNameAdded = true
                UserDefaults.standard.set(true, forKey: PreferenceKeys.pendingNameUpdatedToast)
                dismiss()
            }
        } catch {
            await MainActor.run {
                toastState = .error
                toastMessage = error.localizedDescription
            }
        }
    }
}
