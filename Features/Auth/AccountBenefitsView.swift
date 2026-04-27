//
//  AccountBenefitsView.swift
//  FarmerChat
//

import SwiftUI
import Network

private let photoWidth: CGFloat = 300
private let photoHeight: CGFloat = 450
private let benefitsGreen = Color(hex: 0xFF008236)
private let benefitsButtonDark = Color(hex: 0xFF08361B)

struct AccountBenefitsView: View {
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @State private var termsUrl: String?
    @State private var privacyUrl: String?
    @State private var contentAppeared = false

    var body: some View {
        ZStack {
            benefitsGreen.ignoresSafeArea()

            VStack(spacing: 0) {
                AuthFlowHeader(title: "Sign up", showSkip: true, useBackButton: true, onClose: { dismiss() }, onSkip: { skipOrPop() })

                Spacer(minLength: 0)

                if let img = UIImage(named: "FarmerOnboarding"), !img.size.equalTo(.zero) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: photoWidth, height: photoHeight)
                        .clipShape(Capsule())
                        .scaleEffect(contentAppeared ? 1 : 0.85)
                        .opacity(contentAppeared ? 1 : 0)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(AppColors.onboardingWhite.opacity(0.9))
                        .frame(width: photoWidth, height: photoHeight)
                }

                Spacer(minLength: 16)

                VStack(spacing: 10) {
                    Text("Save your questions\nand answers")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.onboardingWhite)
                        .multilineTextAlignment(.center)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)

                    Text("We'll save your chats so you can\ncontinue later.")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(AppColors.onboardingWhite.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .opacity(contentAppeared ? 1 : 0)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                Button {
                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.accountBenefitScreenProceed, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.accountBenefitScreenProceed)
                    proceedToAuth()
                } label: {
                    HStack(spacing: 8) {
                        Text("Sign up with phone number")
                            .font(AppTypography.onboardingButtonText())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(AppColors.onboardingWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(benefitsButtonDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 10)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .task { await loadLegalLinks() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { contentAppeared = true }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var legalText: some View {
        HStack(spacing: 0) {
            Text("By signing up, you agree to our ")
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.onboardingDarkGrey)
            if let u = termsUrl, let url = URL(string: u) {
                Button("Terms of Service") {
                    navigator.navigate(to: .legalContent(url: url, title: "Terms of Service"))
                }
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.legalLinkBlue)
                .underline()
            } else {
                Text("Terms of Service")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.onboardingDarkGrey)
            }
            Text(" and ")
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.onboardingDarkGrey)
            if let u = privacyUrl, let url = URL(string: u) {
                Button("Privacy Policy.") {
                    navigator.navigate(to: .legalContent(url: url, title: "Privacy Policy"))
                }
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.legalLinkBlue)
                .underline()
            } else {
                Text("Privacy Policy.")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.onboardingDarkGrey)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func loadLegalLinks() async {
        guard let help = try? await GetHelpSupportUseCase().execute(limit: 5) else { return }
        await MainActor.run {
            termsUrl = help.legalResolved?.terms_of_use?.webview_url
            privacyUrl = help.legalResolved?.privacy_policy?.webview_url
        }
    }

    private func proceedToAuth() {
        Task {
            let available = await isNetworkAvailable()
            await MainActor.run {
                if available {
                    navigator.navigate(to: .auth)
                } else {
                    ErrorNavigationManager.shared.emit(
                        isNetworkError: true,
                        fromScreen: "auth",
                        retry: { await MainActor.run { navigator.navigate(to: .auth) } }
                    )
                }
            }
        }
    }

    private func isNetworkAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
    }

    private func skipOrPop() {
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.accountBenefitScreenSkip, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.accountBenefitScreenSkip)
        dismiss()
    }
}
