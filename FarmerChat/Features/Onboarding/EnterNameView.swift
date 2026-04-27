//
//  EnterNameView.swift
//  FarmerChat
//
//  UI_NAME.md — 32pt logo, titleLarge + bodyMedium subtitle, TextInput with autofocus,
//  56pt PrimaryButton (Chevron/Loading), SecondaryButton "Skip for now" when empty.
//  Validation errors surface via Toast.
//

import SwiftUI

struct EnterNameView: View {
    @Environment(AppNavigator.self) private var navigator
    @State private var name = ""
    @State private var isLoading = false
    @State private var toastMessage: String? = nil
    @State private var toastState: ToastState = .error
    @FocusState private var isNameFieldFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var hasName: Bool { !trimmedName.isEmpty }

    /// UI_NAME.md §4 — primary enabled when 1…100 chars (taps with 1–2 show error toast).
    private var buttonEnabled: Bool {
        let c = trimmedName.count
        return c >= 1 && c <= 100
    }

    private var primaryState: PrimaryButtonState {
        if isLoading { return .loading }
        return buttonEnabled ? .chevron : .default
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                LogoMarkShape()
                    .fill(ContentColors.borderActive)
                    .frame(width: 32, height: 32)
                    .padding(.top, 32)

                Text(PreferencesManager.shared.label("fc_v2_app_label_what_should_we_call_you", fallback: "What should we call you?"))
                    .font(AppTypography.titleLarge())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                Text(PreferencesManager.shared.label("fc_v2_app_label_we_greet_you_name", fallback: "So we can greet you by name"))
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .padding(.top, 8)

                FormTextInput(
                    text: $name,
                    placeholder: PreferencesManager.shared.label("fc_v2_app_label_your_name_or_nickname", fallback: "Your name"),
                    state: isLoading ? .disabled : .default,
                    autocapitalization: .words,
                    isFocused: isNameFieldFocused
                )
                .focused($isNameFieldFocused)
                .padding(.top, 24)
                .onChange(of: name) { _, newValue in
                    let normalized = Self.normalizeNameInput(newValue)
                    if normalized != newValue { name = normalized }
                }

                PrimaryButton(
                    label: isLoading ? PreferencesManager.shared.label("fc_v2_app_label_saving", fallback: "Saving") : PreferencesManager.shared.label("fc_v2_app_label_save_name", fallback: "Save name"),
                    state: primaryState,
                    height: 56,
                    isEnabled: buttonEnabled && !isLoading,
                    action: {
                        isNameFieldFocused = false
                        Task { await submit() }
                    }
                )
                .padding(.top, 16)

                if !hasName {
                    Button(action: skip) {
                        Text(PreferencesManager.shared.label("fc_v2_app_label_skip_for_now", fallback: "Skip for now"))
                            .font(AppTypography.labelLarge())
                            .foregroundStyle(ContentColors.foregroundPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.2), value: hasName)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ContentColors.surfacePrimary)
        .toastHost(message: $toastMessage, state: $toastState)
        .onAppear {
            PreferencesManager.shared.nameScreenSeenOnce = true
            // UI_NAME.md §2 / acceptance — keyboard pops up on appear.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadProfileIfNeeded() }
    }

    // MARK: - Input sanitation

    /// UI_NAME.md §3 — letters + whitespace only, strip leading whitespace, collapse runs.
    static func normalizeNameInput(_ s: String) -> String {
        let filtered = s.unicodeScalars.filter { CharacterSet.letters.contains($0) || CharacterSet.whitespaces.contains($0) }
        var result = String(String.UnicodeScalarView(filtered))
        while result.first?.isWhitespace == true { result.removeFirst() }
        result = result.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if s.hasSuffix(" ") && !result.isEmpty && !result.hasSuffix(" ") {
            result.append(" ")
        }
        if result.count > 100 { result = String(result.prefix(100)) }
        return result
    }

    /// UI_NAME.md §5 — never surface "No Name" / "null" backend placeholders.
    static func sanitizeNameForUi(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.caseInsensitiveCompare("No Name") == .orderedSame { return "" }
        if t.caseInsensitiveCompare("null") == .orderedSame { return "" }
        return String(t.prefix(100))
    }

    // MARK: - Actions

    private func loadProfileIfNeeded() async {
        guard name.isEmpty else { return }
        do {
            let profile = try await GetProfileUseCase().execute()
            await MainActor.run {
                let first = profile.user_profile.first_name ?? ""
                let last = profile.user_profile.last_name ?? ""
                let joined = [first, last].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                let sanitized = Self.sanitizeNameForUi(joined)
                if !sanitized.isEmpty { name = sanitized }
            }
        } catch {}
    }

    private func skip() {
        PreferencesManager.shared.onboardingNameDone = true
        PreferencesManager.shared.userNameAdded = true
        navigator.routeFromSplash()
    }

    private func submit() async {
        let n = trimmedName
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
                    PreferencesManager.shared.userName = fromApi
                } else {
                    let firstLast = [res.user_profile.first_name, res.user_profile.last_name]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    PreferencesManager.shared.userName = firstLast.isEmpty ? n : firstLast
                }
                PreferencesManager.shared.userNameAdded = true
                PreferencesManager.shared.onboardingNameDone = true
                navigator.routeFromSplash()
            }
        } catch {
            toastState = .error
            toastMessage = error.localizedDescription
        }
    }
}
