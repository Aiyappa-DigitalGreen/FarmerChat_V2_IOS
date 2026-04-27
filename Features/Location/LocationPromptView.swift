//
//  LocationPromptView.swift
//  FarmerChat
//
//  UI_LOCATION.md §§1-4 — 5-state host (interstitial / permission / fetching /
//  recovery sheet / error). Interstitial + Error delegate to FullScreenMessage
//  (UI_ERROR.md §1). Recovery uses a native `.sheet` with 382pt image + white
//  close + "Turn on in settings" PrimaryButton.
//

import SwiftUI

struct LocationPromptView: View {
    @Environment(\.openURL) private var openURL
    var manager: LocationPromptManager

    private var recoverySheetBinding: Binding<Bool> {
        Binding(
            get: { if case .recovery = manager.state { return true } else { return false } },
            set: { newValue in
                if !newValue, case .recovery = manager.state { manager.dismissRecovery() }
            }
        )
    }

    var body: some View {
        ZStack {
            switch manager.state {
            case .idle:
                EmptyView()
            case .interstitial:
                interstitial(buttonState: .chevron, buttonLabel: "Share Location")
            case .requestPermission, .requestEnableGps:
                interstitial(buttonState: .loading, buttonLabel: "Getting your location...")
            case .fetchingLocation:
                interstitial(buttonState: .loading, buttonLabel: "Getting your location...")
            case .recovery:
                interstitial(buttonState: .chevron, buttonLabel: "Share Location")
            case .error(let type):
                errorScreen(type: type)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            manager.onOpenSettings = {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
        }
        .sheet(isPresented: recoverySheetBinding) {
            recoverySheet
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Interstitial (UI_LOCATION.md §2)

    private func interstitial(buttonState: PrimaryButtonState, buttonLabel: String) -> some View {
        let isFetching = buttonState == .loading
        let leftIcon: String? = isFetching ? nil : "chevron.left"
        let onLeft: (() -> Void)? = isFetching ? nil : { manager.cancel() }
        let rightLabel: String? = isFetching ? nil : "Skip"
        let onRight: (() -> Void)? = isFetching ? nil : { manager.skipOrContinueWithoutLocation() }

        return FullScreenMessage(
            title: "Share Location",
            mainMessage: "Get advice for your area",
            subtitle: "Your location helps us suggest crops, weather, and pests near you.",
            primaryCtaLabel: buttonLabel,
            primaryCtaState: buttonState,
            onPrimaryCta: { manager.userTappedTurnOnLocation() },
            illustration: "farmer_looking_at_phone",
            showGradientOverlay: true,
            leftIcon: leftIcon,
            onLeft: onLeft,
            rightLabel: rightLabel,
            onRight: onRight
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { /* swallow taps under the overlay */ })
    }

    // MARK: - Error (UI_LOCATION.md §4)

    private func errorScreen(type: LocationPromptErrorType) -> some View {
        let copy = errorCopy(type)
        return FullScreenMessage(
            title: copy.title,
            mainMessage: copy.mainMessage,
            subtitle: copy.subtitle,
            primaryCtaLabel: "Try again",
            primaryCtaState: .chevron,
            onPrimaryCta: {
                switch type {
                case .noNetwork:
                    manager.retry()
                case .gpsUnavailable, .locationFailed:
                    manager.dismissErrorAndContinue()
                }
            },
            illustration: copy.illustration,
            enableDebounce: true
        )
    }

    private func errorCopy(_ type: LocationPromptErrorType) -> (title: String, mainMessage: String, subtitle: String, illustration: String) {
        switch type {
        case .noNetwork:
            return ("No internet connection",
                    "FarmerChat needs\nthe internet",
                    "Check mobile data or Wi-Fi signal",
                    "farmer_looking_at_sky")
        case .gpsUnavailable:
            return ("Turn on GPS",
                    "Get local advice",
                    "Location and GPS are turned off. Turning this on helps us tailor answers to your area.",
                    "farmer_looking_at_phone")
        case .locationFailed:
            return ("Something went wrong",
                    "Couldn't get your location",
                    "Please try again.",
                    "farmer_looking_at_phone")
        }
    }

    // MARK: - Recovery sheet (UI_LOCATION.md §3)

    private var recoverySheet: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                recoveryImage
                    .frame(height: 382)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))

                Button {
                    manager.dismissRecovery()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .smoothCorner(14)
                }
                .buttonStyle(.plain)
                .padding(12)
            }

            Spacer().frame(height: 4)

            VStack(spacing: 12) {
                Text("We need your location")
                    .font(AppTypography.titleLarge())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("Sharing your location helps FarmerChat tailor advice to your farm.")
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                PrimaryButton(
                    label: "Turn on in settings",
                    state: .chevron,
                    height: 56,
                    action: { manager.openSettings() }
                )

                Spacer().frame(height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(ContentColors.surfacePrimary.ignoresSafeArea())
    }

    @ViewBuilder
    private var recoveryImage: some View {
        if let img = UIImage(named: "farmer_looking_at_phone_square"), !img.size.equalTo(.zero) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let fallback = UIImage(named: "farmer_looking_at_phone"), !fallback.size.equalTo(.zero) {
            Image(uiImage: fallback)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            BrandColors.surfaceSecondary
        }
    }
}
