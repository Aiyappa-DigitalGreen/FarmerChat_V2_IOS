//
//  AccountSuccessView.swift
//  FarmerChat
//
//  UI_AUTH.md §8 — Full brand-green screen. DefaultAppBar "Sign up" (no back button).
//  Illustration clipped to Capsule (300×450). White text. PrimaryButton "Continue".
//

import SwiftUI

private let photoWidth: CGFloat = 300
private let photoHeight: CGFloat = 450

struct AccountSuccessView: View {
    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        ZStack {
            BrandColors.surfacePrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Figma 5.3.7: no back button, just "Sign up" title centered on green bar
                DefaultAppBar(
                    title: PreferencesManager.shared.label("fc_v2_app_label_sign_up", fallback: "Sign up"),
                    leftIcon: Optional<String>.none,
                    onLeft: nil
                )

                ScrollView {
                    VStack(spacing: 0) {
                        illustration
                            .padding(.top, 32)

                        // Figma 5.3.7: "You're all set!" titleLarge, white
                        Text(PreferencesManager.shared.label("fc_v2_app_label_youre_all_set", fallback: "You're all set!"))
                            .font(AppTypography.titleLarge())
                            .foregroundStyle(BrandColors.foregroundPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)

                        // Figma 5.3.7: subtitle bodyMedium, white slightly dimmed
                        Text(PreferencesManager.shared.label("fc_v2_app_label_previous_questions_menu", fallback: "Find your previous questions in the menu and continue anytime."))
                            .font(AppTypography.bodyMedium())
                            .foregroundStyle(BrandColors.foregroundPrimary.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        // Figma 5.3.7: "Continue" button, no chevron, dark green, 56pt
                        PrimaryButton(
                            label: PreferencesManager.shared.label("fc_v2_app_label_continue", fallback: "Continue"),
                            state: .default,
                            height: 56,
                            action: {
                                // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.signupContinueClicked, properties: nil, adjustToken: AnalyticsConstants.AdjustToken.signupContinueClicked)
                                navigator.popToHome()
                            }
                        )
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 48)
                }
                .background(Color.clear)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var illustration: some View {
        let capsule = Capsule()
        Group {
            if let img = UIImage(named: "farmer_looking_at_sky"), !img.size.equalTo(.zero) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if let fallback = UIImage(named: "farmer_looking_at_phone"), !fallback.size.equalTo(.zero) {
                Image(uiImage: fallback)
                    .resizable()
                    .scaledToFill()
            } else {
                BrandColors.surfaceSecondary
            }
        }
        .frame(width: photoWidth, height: photoHeight)
        .clipShape(capsule)
    }
}
