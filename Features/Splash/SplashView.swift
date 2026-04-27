//
//  SplashView.swift
//  FarmerChat
//
//  Boot screen: gradient, white logo, "FarmerChat is starting...". Existing logic: init user, then routeFromSplash().
//

import SwiftUI

private let logoSize: CGFloat = 100

struct SplashView: View {
    @Environment(AppNavigator.self) private var navigator
    @State private var didInit = false
    @State private var contentAppeared = false
    @State private var logoRotation: Double = 0
    @State private var rotationTask: Task<Void, Never>? = nil
    /// SPLASH_SCREEN.md §2.4 — reassurance toast appears only after 2s on splash, not on cold render.
    @State private var showReassuranceToast = false

    var body: some View {
        ZStack {
            // UI_SPLASH.md §2 — prefer the shipped `boot_bg` Asset Catalog drawable.
            // Falls back to the Android legacy gradient (UI_THEME.md §1.6) if the asset is absent.
            #if canImport(UIKit)
            if UIImage(named: "boot_bg") != nil {
                Image("boot_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [AppColors.gradientYellow, AppColors.gradientMidGreen, AppColors.gradientDarkGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            #else
            LinearGradient(
                colors: [AppColors.gradientYellow, AppColors.gradientMidGreen, AppColors.gradientDarkGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            #endif

            LogoMarkShape()
                .fill(BrandColors.foregroundPrimary)
                .frame(width: logoSize, height: logoSize)
                .scaleEffect(contentAppeared ? 1 : 0.8)
                .opacity(contentAppeared ? 1 : 0)
                .rotationEffect(.degrees(logoRotation))
        }
        // UI_SPLASH.md §4 — reassurance toast slides in from top, Radius.LG, 8dp shadow.
        .overlay(alignment: .bottom) {
            if showReassuranceToast {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.green500)
                            .frame(width: 32, height: 32)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.white))
                            .scaleEffect(0.8)
                    }
                    Text("FarmerChat is starting...")
                        .font(AppTypography.bodySmall())
                        .foregroundStyle(AppColors.black)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.white)
                .smoothCorner(Radius.lg)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showReassuranceToast)
        .task { await runSplash() }
        .task {
            // SPLASH_SCREEN.md §3.1 Step 6 — reassurance toast appears after SPLASH_TOAST_DELAY_MS (2000ms).
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled { showReassuranceToast = true }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { contentAppeared = true }
            startLogoRotation()
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.appOpened, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.appOpened)
            let defaults = UserDefaults.standard
            let hasLaunched = defaults.bool(forKey: PreferenceKeys.hasLaunchedBefore)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            if !hasLaunched {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.appInstalled, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.appInstalled)
                defaults.set(true, forKey: PreferenceKeys.hasLaunchedBefore)
            }
            let lastVersion = defaults.string(forKey: PreferenceKeys.lastSeenAppVersion)
            if hasLaunched, lastVersion != nil, lastVersion != version {
                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.appUpdated, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.appUpdated)
            }
            defaults.set(version, forKey: PreferenceKeys.lastSeenAppVersion)
        }
        .onDisappear {
            rotationTask?.cancel()
            rotationTask = nil
            // AnalyticsManager.trackScreenExit(screenName: AnalyticsConstants.Screen.splashScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenExited, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.splashScreen], adjustToken: AnalyticsConstants.AdjustToken.screenExited)
        }
    }

    /// Android parity: 4s cycle — 3s hold at 0°, 1s spin to 360° with
    /// FastOutSlowInEasing (cubic-bezier 0.4, 0.0, 0.2, 1.0). Loops until the
    /// splash disappears.
    private func startLogoRotation() {
        rotationTask?.cancel()
        rotationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
                withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.0)) {
                    logoRotation += 360
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func runSplash() async {
        guard !didInit else { return }
        didInit = true

        await initSDKs()

        try? await Task.sleep(nanoseconds: 200_000_000)

        if !Task.isCancelled {
            let prefs = PreferencesManager.shared
            // AnalyticsManager.identify(userId: prefs.userId, traits: nil)
            navigator.routeFromSplash()
        }
    }

    private func initSDKs() async {
        // SDK init path present; no-op while AppSDKConfig.sdkEventsEnabled is false (per HOME_AND_CHAT_COMPLETE_APIS.md).
        // AnalyticsManager.initializeSDKsIfEnabled()

        try? await Task.sleep(nanoseconds: 500_000_000)

        let prefs = PreferencesManager.shared
        let deviceId = prefs.resolvedDeviceId
        // Per INITIALIZE_USER_API.md: initialize_user is primarily an onboarding (Language screen) step.
        // We only run it here as a recovery if onboarding is complete but auth/session data is missing.
        if prefs.onboardingLanguageDone,
           (prefs.userId?.isEmpty != false || prefs.accessToken?.isEmpty != false) {
            do {
                let response = try await AuthUseCase().initializeUser(deviceId: deviceId)
                await MainActor.run {
                    if let uid = response.user_id { prefs.userId = uid }
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
            } catch {
                print("[Splash] initialize_user failed: \(error)")
            }
        }
        try? await Task.sleep(nanoseconds: 300_000_000)

        // LANGUAGE_SCREEN.md §6.8 — call once per install, gated on BUILD_VERSION_API_CALLED.
        // Must run after auth is in place so the Authorization header is attached.
        if !prefs.buildVersionApiCalled,
           let uid = prefs.userId, !uid.isEmpty,
           let access = prefs.accessToken, !access.isEmpty {
            do {
                try await APIClient().updateBuildVersion()
                await MainActor.run { prefs.buildVersionApiCalled = true }
            } catch {
                print("[Splash] update_build_version failed: \(error)")
            }
        }
    }
}
