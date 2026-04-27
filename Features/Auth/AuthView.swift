//
//  AuthView.swift
//  FarmerChat
//
//  UI_AUTH.md §§1-3, §6, §7 — DefaultAppBar "Sign up" (Close, no glow), two-step FSM
//  (PhoneEntry ↔ OtpEntry). CountryCodeSelector + FormTextInput on phone step, OtpInput
//  + 180s timer + Start over/Resend labels on OTP step. 56pt PrimaryButton (Loading/Default).
//

import SwiftUI
import Combine

private let otpDigitCount = 4

struct AuthView: View {
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @State private var step: AuthStep = .phone
    @State private var countries: [CountryItem] = []
    @State private var selectedCountry: CountryItem?
    @State private var phoneLocal = ""
    @State private var otp: String = ""
    @State private var sendState: Loadable<SendOtpResponse> = .idle
    @State private var verifyState: Loadable<VerifyOtpResponse> = .idle
    @State private var phoneError: String?
    @State private var otpError: String?
    @State private var availableSms = true
    // TODO: Re-enable WhatsApp OTP when ready — set back to `true` and respect API response in refreshOtpMode()
    @State private var availableWhatsapp = false
    @State private var lastChannel: String = "sms"
    @State private var otpAttempts: Int = 0
    @State private var resendSeconds = 180
    @State private var showCountryPicker = false
    @FocusState private var phoneFocused: Bool

    private var otpString: String { otp }
    private var selectedDial: String { selectedCountry?.phone_country_code ?? "+91" }
    private var selectedIso: String { selectedCountry?.code ?? "IN" }
    private var phoneDigits: String { phoneLocal.filter { $0.isNumber } }
    private var isCountryLoading: Bool { countries.isEmpty }
    private var canSend: Bool { isPhoneValid() && !sendState.isLoading }

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: "Sign up",
                leftIcon: "chevron.left",
                onLeft: { leftTap() },
                rightLabel: "Skip",
                onRightLabel: { dismiss() },
                background: ContentColors.surfacePrimary,
                foreground: ContentColors.foregroundPrimary
            )

            ScrollView {
                Group {
                    if step == .phone {
                        phoneSection
                    } else {
                        otpSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.25), value: step)
            }
            .background(ContentColors.surfacePrimary)
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showCountryPicker) {
            if let sel = selectedCountry {
                CountryCodePickerView(countries: countries, selectedCountry: Binding(
                    get: { sel },
                    set: { newSel in
                        selectedCountry = newSel
                        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.countrySelected, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.selectCountryScreen, AnalyticsConstants.Property.countryCode: newSel.phone_country_code ?? newSel.code ?? ""], adjustToken: AnalyticsConstants.AdjustToken.countrySelected)
                        phoneLocal = ""
                        Task { await refreshOtpMode() }
                    }
                ))
            } else {
                VStack(spacing: 16) {
                    LogoSpinner(type: .vertical, label: "Loading countries…")
                }
                .padding(24)
                .background(ContentColors.surfacePrimary.ignoresSafeArea())
            }
        }
        .onChange(of: step) { _, newValue in
            if newValue == .otp {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.verifyOTPScreen], adjustToken: AnalyticsConstants.AdjustToken.screenViewed)
            }
        }
        .task { await loadCountriesIfNeeded() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if step == .otp && resendSeconds > 0 {
                resendSeconds -= 1
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if step == .phone { phoneFocused = true }
            }
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.loginScreen], adjustToken: AnalyticsConstants.AdjustToken.screenViewed)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.mobileVerificationStarted, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.loginScreen, AnalyticsConstants.Property.trigger: "Signup button"], adjustToken: AnalyticsConstants.AdjustToken.mobileVerificationStarted)
        }
        .onChange(of: phoneLocal) { _, new in
            let digitsOnly = new.filter { $0.isNumber }
            let maxLen = min(selectedCountry?.phone_length ?? 15, 15)
            let trimmed = String(digitsOnly.prefix(maxLen))
            if trimmed != new { phoneLocal = trimmed }
            if phoneError != nil { phoneError = nil }
        }
    }

    // MARK: - App bar action

    private func leftTap() {
        if step == .otp {
            withAnimation(.easeInOut(duration: 0.3)) {
                step = .phone
                otpError = nil
                otp = ""
            }
        } else {
            dismiss()
        }
    }

    // MARK: - Phone step

    private var phoneSection: some View {
        VStack(spacing: 0) {
            Text(sendState.isLoading ? "Enter phone number" : "Enter your phone number")
                .font(AppTypography.titleLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)
                .multilineTextAlignment(.center)

            Text(sendState.isLoading
                 ? "And we will send you a one time code"
                 : "We'll send a one-time code to sign you in")
                .font(AppTypography.bodyMedium())
                .foregroundStyle(ContentColors.foregroundSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 8) {
                if isCountryLoading {
                    CountryCodeLoadingBox()
                } else {
                    CountryCodeSelector(
                        countryCode: selectedDial,
                        flagUrl: selectedCountry?.flag,
                        countryIso: selectedIso,
                        onTap: {
                            if selectedCountry == nil { applyInitialCountrySelection() }
                            showCountryPicker = selectedCountry != nil
                        }
                    )
                }

                FormTextInput(
                    text: $phoneLocal,
                    placeholder: "00000 00000",
                    helper: phoneError,
                    state: phoneInputState,
                    keyboardType: .numberPad,
                    autocapitalization: .never,
                    height: 56,
                    isFocused: phoneFocused
                )
                .focused($phoneFocused)
            }
            .padding(.top, 24)

            if sendState.isLoading {
                PrimaryButton(
                    label: "Sending code...",
                    state: .loading,
                    height: 56,
                    isEnabled: false,
                    action: {}
                )
                .padding(.top, 16)
            } else {
                VStack(spacing: 8) {
                    if availableWhatsapp {
                        PrimaryButton(
                            label: "Send via WhatsApp",
                            state: .default,
                            height: 48,
                            icon: "message.fill",
                            iconPosition: .leading,
                            isEnabled: canSend,
                            action: {
                                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.sendOTPClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.loginScreen, AnalyticsConstants.Property.channel: "WhatsApp"], adjustToken: AnalyticsConstants.AdjustToken.sendOTPClick)
                                Task { await sendOtp(channel: "whatsapp") }
                            }
                        )
                    }
                    if availableSms {
                        PrimaryButton(
                            label: "Send via SMS",
                            state: .default,
                            height: 48,
                            icon: "message.fill",
                            iconPosition: .leading,
                            isEnabled: canSend,
                            action: {
                                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.sendOTPClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.loginScreen, AnalyticsConstants.Property.channel: "SMS"], adjustToken: AnalyticsConstants.AdjustToken.sendOTPClick)
                                Task { await sendOtp(channel: "sms") }
                            }
                        )
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private var phoneInputState: TextInputState {
        if sendState.isLoading { return .disabled }
        if phoneError != nil { return .error }
        return phoneFocused ? .active : .default
    }

    // MARK: - OTP step

    private var otpSection: some View {
        VStack(spacing: 0) {
            Text("Enter the code we sent")
                .font(AppTypography.titleLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)
                .multilineTextAlignment(.center)

            Text("Check your messages for the code")
                .font(AppTypography.bodyMedium())
                .foregroundStyle(ContentColors.foregroundSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            OtpInput(
                value: $otp,
                length: otpDigitCount,
                isError: otpError != nil,
                enabled: !verifyState.isLoading
            )
            .padding(.top, 24)
            .onChange(of: otp) { _, new in
                if otpError != nil && !new.isEmpty { otpError = nil }
            }

            PrimaryButton(
                label: verifyState.isLoading ? "Verifying" : "Verify",
                state: verifyState.isLoading ? .loading : .default,
                height: 56,
                isEnabled: otpString.count == otpDigitCount && !verifyState.isLoading,
                action: { Task { await verifyOtp() } }
            )
            .padding(.top, 16)

            if resendSeconds > 0 {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(BrandColors.feedbackSuccess)
                            .frame(width: 32, height: 32)
                        Image(systemName: "timer")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.white)
                    }
                    Text("Please enter in \(resendMinutesSeconds) seconds")
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(ContentColors.foregroundPrimary)
                }
                .padding(.top, 16)

                Text("Resend code")
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                    .padding(.vertical, 8)
                    .padding(.top, 16)
            } else {
                Text("Start over")
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(verifyState.isLoading ? ContentColors.foregroundSecondary : ContentColors.foregroundPrimary)
                    .padding(.vertical, 8)
                    .padding(.top, 16)
                    .onTapGesture {
                        if !verifyState.isLoading {
                            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.startOverClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.verifyOTPScreen], adjustToken: AnalyticsConstants.AdjustToken.startOverClicked)
                            startOver()
                        }
                    }

                Text("Resend code")
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(verifyState.isLoading ? ContentColors.foregroundSecondary : ContentColors.foregroundPrimary)
                    .padding(.vertical, 8)
                    .padding(.top, 8)
                    .onTapGesture {
                        if !verifyState.isLoading {
                            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.resendOTPClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.verifyOTPScreen, AnalyticsConstants.Property.channel: lastChannel], adjustToken: AnalyticsConstants.AdjustToken.resendOTPClick)
                            Task { await sendOtp(channel: lastChannel) }
                        }
                    }
            }

            if let err = otpError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                    Text(err)
                        .font(AppTypography.bodySmall())
                }
                .foregroundStyle(BrandColors.feedbackFail)
                .padding(.top, 12)
            }
        }
    }

    private var resendMinutesSeconds: String {
        let m = resendSeconds / 60
        let s = resendSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Network / FSM (unchanged)

    private func sendOtp(channel: String) async {
        phoneError = nil
        otpError = nil
        let digits = phoneDigits
        guard !digits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phoneError = "Please enter a valid number to continue"
            return
        }
        guard isPhoneValid() else {
            phoneError = "Please check and try again."
            return
        }

        lastChannel = channel
        sendState = .loading
        do {
            try await ensureGuestInitialized()
            try await AuthUseCase().sendOtp(phoneNumber: digits, countryCode: selectedDial, channel: [channel])
            await MainActor.run {
                sendState = .idle
                startResendTimer()
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = .otp
                }
                otp = ""
                otpAttempts = 0
            }
        } catch {
            await MainActor.run {
                sendState = .idle
                if let apiError = error as? APIError, case .server(let code, _) = apiError, code == 429 {
                    phoneError = apiError.errorDescription
                    return
                }

                if isNetworkError(error) {
                    ErrorNavigationManager.shared.emit(isNetworkError: true, fromScreen: "auth_send_otp") {
                        await sendOtp(channel: channel)
                    }
                    return
                }

                if let apiError = error as? APIError, case .server(let code, _) = apiError, code >= 500 {
                    ErrorNavigationManager.shared.emit(isNetworkError: false, fromScreen: "auth_send_otp") {
                        await sendOtp(channel: channel)
                    }
                    return
                }

                phoneError = error.localizedDescription
            }
        }
    }

    private func verifyOtp() async {
        otpError = nil
        verifyState = .loading
        do {
            guard otpString.count == otpDigitCount, otpString.allSatisfy({ $0.isNumber }) else {
                await MainActor.run {
                    verifyState = .idle
                    otpError = "Please enter a valid OTP"
                }
                return
            }
            let res = try await AuthUseCase().verifyOtp(
                phoneNumber: phoneDigits,
                countryCode: selectedDial,
                otp: otpString
            )
            // UI_AUTH.md §3 — delay 800ms before navigating so success state is visible
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                verifyState = .idle
                if let access = res.access_token {
                    KeychainManager.shared.set(value: access, forKey: "APP_ACCESS_TOKEN")
                    PreferencesManager.shared.accessToken = access
                }
                if let refresh = res.refresh_token {
                    KeychainManager.shared.set(value: refresh, forKey: "APP_REFRESH_TOKEN")
                    PreferencesManager.shared.refreshToken = refresh
                }
                if let uid = res.id, !uid.isEmpty {
                    PreferencesManager.shared.userId = uid
                }
                if let role = res.role, !role.isEmpty {
                    PreferencesManager.shared.userRole = role
                }
                PreferencesManager.shared.userPhoneCountryCode = selectedDial
                PreferencesManager.shared.phoneNumberLogin = selectedDial + phoneDigits
                let sanitizedName = EnterNameView.sanitizeNameForUi(res.name ?? "")
                if !sanitizedName.isEmpty {
                    PreferencesManager.shared.userName = sanitizedName
                    PreferencesManager.shared.userNameAdded = true
                }
                PreferencesManager.shared.isOtpVerified = true
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.loginCompleted, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.verifyOTPScreen, AnalyticsConstants.Property.userId: res.id ?? "", "is_new_user": res.id != nil], adjustToken: AnalyticsConstants.AdjustToken.loginCompleted)
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.submitOTP, properties: [AnalyticsConstants.Property.verificationStatus: "Success", AnalyticsConstants.Property.errorMessage: ""], adjustToken: AnalyticsConstants.AdjustToken.submitOTP)
                // if let uid = res.id { AnalyticsManager.identify(userId: uid, traits: nil) }
                // UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.phoneNo, attributeValue: selectedDial + phoneDigits)
                // UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.mobileNoVerified, attributeValue: true)
                // if let name = res.name, !name.isEmpty { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.name, attributeValue: name) }
                // if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.appVersion, attributeValue: version) }
                // if let code = Bundle.main.infoDictionary?["CFBundleVersion"] as? String { UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.versionCode, attributeValue: code) }
                // UserAttributeTracker.track(attributeName: AnalyticsConstants.UserAttribute.buildVersion, attributeValue: "V2")
                navigator.navigate(to: .accountSuccess)
            }
        } catch {
            await MainActor.run {
                verifyState = .idle
                if let apiError = error as? APIError, case .server(let code, _) = apiError, code == 401 {
                    otpAttempts += 1
                    otpError = apiError.errorDescription
                    return
                }

                if isNetworkError(error) {
                    ErrorNavigationManager.shared.emit(isNetworkError: true, fromScreen: "auth_verify_otp") {
                        await verifyOtp()
                    }
                    return
                }

                ErrorNavigationManager.shared.emit(isNetworkError: false, fromScreen: "auth_verify_otp") {
                    await verifyOtp()
                }
            }
        }
    }

    private func startOver() {
        withAnimation(.easeInOut(duration: 0.25)) {
            step = .phone
        }
        phoneError = nil
        otpError = nil
        otp = ""
        startResendTimer()
    }

    private func isPhoneValid() -> Bool {
        let digits = phoneDigits
        guard !digits.isEmpty else { return false }

        if selectedDial == "+251" {
            return digits.count == 9 && (digits.hasPrefix("7") || digits.hasPrefix("9"))
        }

        if let len = selectedCountry?.phone_length, len > 0, digits.count != len { return false }
        if let pattern = selectedCountry?.phone_number_pattern?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pattern.isEmpty {
            if (try? NSRegularExpression(pattern: pattern)) == nil { /* ignore bad regex */ }
            else if digits.range(of: pattern, options: .regularExpression) == nil { return false }
        }
        return (6...15).contains(digits.count)
    }

    private func loadCountriesIfNeeded() async {
        if !countries.isEmpty {
            await refreshOtpMode()
            return
        }
        do {
            let list = try await AuthUseCase().getAllCountries()
            await MainActor.run {
                countries = list.sorted { $0.name < $1.name }
                applyInitialCountrySelection()
                print("[Auth] Country selected: \(selectedCountry?.name ?? "nil"), dial: \(selectedDial)")
            }
            await refreshOtpMode()
        } catch is CancellationError {
            print("[Auth] loadCountries CANCELLED")
        } catch {
            print("[Auth] loadCountries FAILED: \(error)")
            await MainActor.run {
                availableSms = true
                // WhatsApp OTP force-hidden for now
                availableWhatsapp = false
            }
        }
    }

    private func applyInitialCountrySelection() {
        if selectedCountry != nil { return }
        let prefsIso = PreferencesManager.shared.userCountryCode?.uppercased()
        if let iso = prefsIso, let match = countries.first(where: { $0.code.uppercased() == iso }) {
            selectedCountry = match
            return
        }
        if let match = countries.first(where: { $0.phone_country_code == "+91" }) {
            selectedCountry = match
            return
        }
        selectedCountry = countries.first
    }

    private func refreshOtpMode() async {
        let stripped = selectedDial.replacingOccurrences(of: "+", with: "")
        print("[Auth] refreshOtpMode: phone_country_code=\(stripped)")
        do {
            let item = try await AuthUseCase().getOtpMode(phoneCountryCode: stripped)
            let smsVal = item?.sms_enabled ?? true
            let waVal = item?.whatsapp_enabled ?? true
            print("[Auth] getOtpMode SUCCESS: sms=\(smsVal), whatsapp=\(waVal)")
            await MainActor.run {
                availableSms = smsVal
                // WhatsApp OTP force-hidden for now; re-enable when ready
                availableWhatsapp = false
                _ = waVal  // silence unused warning without changing runtime behaviour
            }
        } catch is CancellationError {
            print("[Auth] getOtpMode CANCELLED")
        } catch {
            print("[Auth] getOtpMode FAILED: \(error)")
            await MainActor.run {
                availableSms = true
                // WhatsApp OTP force-hidden for now
                availableWhatsapp = false
            }
        }
    }

    private func startResendTimer() {
        resendSeconds = 180
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let apiError = error as? APIError, case .network = apiError { return true }
        return false
    }

    private func ensureGuestInitialized() async throws {
        let prefs = PreferencesManager.shared
        let did = prefs.resolvedDeviceId
        let uid = prefs.userId ?? ""
        if uid.trimmingCharacters(in: .whitespaces).isEmpty {
            let response = try await AuthUseCase().initializeUser(deviceId: did)
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
        }
    }
}

enum AuthStep {
    case phone
    case otp
}
