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
                interstitial(buttonState: .chevron, buttonLabel: PreferencesManager.shared.label("fc_v2_app_label_share_location", fallback: "Share Location"))
            case .requestPermission, .requestEnableGps:
                interstitial(buttonState: .loading, buttonLabel: PreferencesManager.shared.label("fc_v2_app_label_getting_your_location", fallback: "Getting your location..."))
            case .fetchingLocation:
                interstitial(buttonState: .loading, buttonLabel: PreferencesManager.shared.label("fc_v2_app_label_getting_your_location", fallback: "Getting your location..."))
            case .recovery:
                interstitial(buttonState: .chevron, buttonLabel: PreferencesManager.shared.label("fc_v2_app_label_share_location", fallback: "Share Location"))
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
        let prefs = PreferencesManager.shared
        let isFetching = buttonState == .loading
        let leftIcon: String? = isFetching ? nil : "chevron.left"
        let onLeft: (() -> Void)? = isFetching ? nil : { manager.cancel() }
        let rightLabel: String? = isFetching ? nil : prefs.label("fc_v2_app_label_skip", fallback: "Skip")
        let onRight: (() -> Void)? = isFetching ? nil : { manager.skipOrContinueWithoutLocation() }

        return FullScreenMessage(
            title: prefs.label("fc_v2_app_label_share_location", fallback: "Share Location"),
            mainMessage: prefs.label("fc_v2_app_label_get_advice_your_area", fallback: "Get advice for your area"),
            subtitle: prefs.label("fc_v2_app_label_location_helps_suggestions", fallback: "Your location helps us suggest crops, weather, and pests near you."),
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
            primaryCtaLabel: PreferencesManager.shared.label("fc_v2_app_label_try_again", fallback: "Try again"),
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
        let prefs = PreferencesManager.shared
        switch type {
        case .noNetwork:
            return (prefs.label("fc_v2_app_label_no_internet_connection", fallback: "No internet connection"),
                    prefs.label("fc_v2_app_label_farmerchat_needs_the_internet", fallback: "FarmerChat needs\nthe internet"),
                    prefs.label("fc_v2_app_label_check_mobile_data_wi-fi_signal", fallback: "Check mobile data or Wi-Fi signal"),
                    "farmer_looking_at_sky")
        case .gpsUnavailable:
            return (prefs.label("fc_v2_app_label_turn_on_gps", fallback: "Turn on GPS"),
                    prefs.label("fc_v2_app_label_get_local_advice", fallback: "Get local advice"),
                    prefs.label("fc_v2_app_label_location_gps_turned_off_turning_helps", fallback: "Location and GPS are turned off. Turning this on helps us tailor answers to your area."),
                    "farmer_looking_at_phone")
        case .locationFailed:
            return (prefs.label("fc_v2_app_label_something_went_wrong", fallback: "Something went wrong"),
                    prefs.label("fc_v2_app_label_couldnt_get_your_location", fallback: "Couldn't get your location"),
                    prefs.label("fc_v2_app_label_please_try_again", fallback: "Please try again."),
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
                Text(PreferencesManager.shared.label("fc_v2_app_label_we_need_your_location", fallback: "We need your location"))
                    .font(AppTypography.titleLarge())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(PreferencesManager.shared.label("fc_v2_app_label_location_tailor_advice", fallback: "Sharing your location helps FarmerChat tailor advice to your farm."))
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                PrimaryButton(
                    label: PreferencesManager.shared.label("fc_v2_app_label_turn_on_in_settings", fallback: "Turn on in settings"),
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
