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
                DefaultAppBar(
                    title: "Sign up",
                    leftIcon: Optional<String>.none,
                    onLeft: nil
                )

                ScrollView {
                    VStack(spacing: 0) {
                        illustration
                            .padding(.top, 32)

                        Text("You\u{2019}re all set!")
                            .font(AppTypography.titleLarge())
                            .foregroundStyle(BrandColors.foregroundPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)

                        Text("Find your previous questions in the menu and continue anytime.")
                            .font(AppTypography.bodyLarge())
                            .foregroundStyle(BrandColors.foregroundPrimary.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        PrimaryButton(
                            label: "Continue",
                            state: .chevron,
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
