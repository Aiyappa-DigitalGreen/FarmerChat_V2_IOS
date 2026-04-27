//
//  SharedUIComponents.swift
//  FarmerChat
//
//  Shared component catalog — mirrors fc-compose `components/` package.
//  Every public component maps 1:1 to a section in docs/ios-specs/UI_COMPONENTS.md.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - §1.1 DefaultAppBar
// 64pt tall app bar. Defaults to brand-green slab (used by AccountSuccess etc.).
// Pass background/foreground overrides for neutral-surface screens (Auth, CountryPicker).

struct DefaultAppBar: View {
    let title: String
    var leftIcon: String? = "xmark"
    var onLeft: (() -> Void)? = nil
    var rightIcon: String? = nil
    var onRight: (() -> Void)? = nil
    var rightLabel: String? = nil
    var onRightLabel: (() -> Void)? = nil
    var background: Color = BrandColors.surfacePrimary
    var foreground: Color = BrandColors.foregroundPrimary

    var body: some View {
        ZStack {
            // Title always centered on the full bar width, never shifted by asymmetric slots.
            Text(title)
                .font(AppTypography.titleMedium())
                .foregroundStyle(foreground)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                iconSlot(icon: leftIcon, action: onLeft)
                Spacer(minLength: 0)
                rightSlot
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(background)
    }

    @ViewBuilder
    private var rightSlot: some View {
        if let label = rightLabel, let action = onRightLabel {
            Button(action: action) {
                Text(label)
                    .font(AppTypography.labelMedium())
                    .foregroundStyle(foreground)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
        } else {
            iconSlot(icon: rightIcon, action: onRight)
        }
    }

    @ViewBuilder
    private func iconSlot(icon: String?, action: (() -> Void)?) -> some View {
        if let icon = icon, let action = action {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(foreground)
                    .frame(width: 42, height: 42)
                    .background(foreground.opacity(0.12))
                    .smoothCorner(Radius.md)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 42, height: 42)
        }
    }
}

// MARK: - §1.2 HomeAppBar
// Menu on left, optional WeatherButton on right. Brand green slab + yellow Glow.

struct HomeAppBar: View {
    var onMenu: () -> Void
    var showWeather: Bool = false
    var weather: WeatherButtonData? = nil
    var onWeather: (() -> Void)? = nil

    var body: some View {
        ZStack {
            BrandColors.surfacePrimary
            Glow(type: .yellow)
                .frame(height: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack(spacing: 12) {
                ActionButton(icon: "line.3.horizontal", radius: Radius.md, action: onMenu)
                Spacer(minLength: 0)
                if showWeather, let w = weather, let tap = onWeather {
                    WeatherButton(data: w, action: tap)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 64)
    }
}

// MARK: - §1.3 LogoAppBar
// 36pt logo that fades 0↔1 on `showLogo`. Used by Chat when scrolled past thread title.

struct LogoAppBar: View {
    let showLogo: Bool
    var leftIcon: String? = nil
    var onLeft: (() -> Void)? = nil
    var rightIcon: String? = nil
    var onRight: (() -> Void)? = nil

    @State private var logoAlpha: Double = 0

    var body: some View {
        ZStack {
            BrandColors.surfacePrimary
            Glow(type: .yellow)
                .frame(height: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack(spacing: 0) {
                sideSlot(icon: leftIcon, action: onLeft)
                Spacer(minLength: 0)
                LogoMarkShape()
                    .fill(BrandColors.foregroundPrimary)
                    .frame(width: 36, height: 36)
                    .opacity(logoAlpha)
                Spacer(minLength: 0)
                sideSlot(icon: rightIcon, action: onRight)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 64)
        .onAppear { logoAlpha = showLogo ? 1 : 0 }
        .onChange(of: showLogo) { _, new in
            withAnimation(.easeOut(duration: new ? 0.6 : 0.3)) {
                logoAlpha = new ? 1 : 0
            }
        }
    }

    @ViewBuilder
    private func sideSlot(icon: String?, action: (() -> Void)?) -> some View {
        if let icon = icon, let action = action {
            ActionButton(icon: icon, radius: Radius.md, action: action)
        } else {
            Color.clear.frame(width: 42, height: 42)
        }
    }
}

// MARK: - §1.4 ChatAppBar
// LogoAppBar variant that shows a title (bodyMedium) instead of the logo.
// Glow softer (0.5 alpha).

struct ChatAppBar: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var rightIcon: String? = nil
    var onRight: (() -> Void)? = nil

    var body: some View {
        ZStack {
            BrandColors.surfacePrimary
            Glow(type: .yellow)
                .frame(height: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .opacity(0.5)

            HStack(spacing: 12) {
                if let onBack = onBack {
                    ActionButton(icon: "chevron.left", radius: Radius.md, action: onBack)
                } else {
                    Color.clear.frame(width: 42, height: 42)
                }
                Spacer(minLength: 0)
                Text(title)
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(BrandColors.foregroundPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if let rightIcon = rightIcon, let onRight = onRight {
                    ActionButton(icon: rightIcon, radius: Radius.md, action: onRight)
                } else {
                    Color.clear.frame(width: 42, height: 42)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 64)
    }
}

// MARK: - §2.1 PrimaryButton

enum PrimaryButtonState {
    case `default`
    case chevron
    case loading
}

enum IconPosition {
    case leading
    case trailing
}

struct PrimaryButton: View {
    let label: String
    var state: PrimaryButtonState = .default
    var height: CGFloat = 48
    var icon: String? = nil
    var iconPosition: IconPosition = .leading
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: { if state != .loading { action() } }) {
            HStack(spacing: 8) {
                switch state {
                case .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ContentColors.buttonPrimaryForeground))
                default:
                    if let icon = icon, iconPosition == .leading {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(label)
                        .font(AppTypography.labelLarge())
                    if state == .chevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    } else if let icon = icon, iconPosition == .trailing {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .foregroundStyle(ContentColors.buttonPrimaryForeground)
            .padding(.horizontal, state == .chevron || iconPosition == .trailing ? 16 : 24)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(ContentColors.buttonPrimarySurface)
            .smoothCorner(Radius.md)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled || state == .loading)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - §2.2 SecondaryButton

struct SecondaryButton: View {
    let label: String
    var height: CGFloat = 48
    var icon: String? = nil
    var iconPosition: IconPosition = .leading
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon, iconPosition == .leading {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(label)
                    .font(AppTypography.labelLarge())
                if let icon = icon, iconPosition == .trailing {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundStyle(BrandColors.foregroundPrimary)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(BrandColors.surfaceSecondary)
            .smoothCorner(Radius.md)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - §2.3 ActionButton
// 42pt square (icon-only) or pill (icon + label). Radius.MD. Medium haptic.

enum ActionButtonLabelPosition {
    case left
    case right
}

struct ActionButton: View {
    var icon: String? = nil
    var label: String? = nil
    var labelPosition: ActionButtonLabelPosition = .right
    var background: Color = BrandColors.surfaceSecondary
    var foreground: Color = BrandColors.foregroundPrimary
    var radius: CGFloat = Radius.md
    var action: () -> Void

    private var isPill: Bool { label != nil }

    var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: 10) {
                if let label = label, labelPosition == .left {
                    Text(label)
                        .font(AppTypography.labelMedium())
                        .foregroundStyle(foreground)
                }
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(foreground)
                }
                if let label = label, labelPosition == .right {
                    Text(label)
                        .font(AppTypography.labelMedium())
                        .foregroundStyle(foreground)
                }
            }
            .padding(.horizontal, isPill ? 14 : 0)
            .frame(width: isPill ? nil : 42, height: 42)
            .background(background)
            .smoothCorner(radius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - §2.6 WeatherButton

enum WeatherCondition {
    case sun
    case rain
    case sunClouds
}

enum WeatherButtonState {
    case `default`
    case loading
}

struct WeatherButtonData {
    let condition: WeatherCondition
    let temperature: String
    let state: WeatherButtonState
}

struct WeatherButton: View {
    let data: WeatherButtonData
    var action: () -> Void

    private var iconName: String {
        switch data.condition {
        case .sun: return "sun.max.fill"
        case .rain: return "cloud.rain.fill"
        case .sunClouds: return "cloud.sun.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if data.state == .loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: BrandColors.foregroundPrimary))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(BrandColors.foregroundPrimary)
                }
                Text(data.temperature)
                    .font(AppTypography.labelMedium())
                    .foregroundStyle(BrandColors.foregroundPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(BrandColors.surfaceSecondary)
            .smoothCorner(Radius.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - §2.7 InputActionButton
// 48pt circle, 22pt icon, always white-on-dark regardless of mode.

struct InputActionButton: View {
    let icon: String
    var background: Color = BrandColors.surfaceSecondary
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void

    @State private var spinnerAngle: Double = 0
    @State private var spinnerTask: Task<Void, Never>? = nil

    var body: some View {
        Button(action: { if !isLoading { action() } }) {
            ZStack {
                Circle().fill(background)
                if isLoading {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(spinnerAngle))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .onChange(of: isLoading) { _, new in
            spinnerTask?.cancel()
            spinnerTask = nil
            if new {
                spinnerTask = Task { @MainActor in
                    while !Task.isCancelled {
                        withAnimation(.linear(duration: 1.0)) { spinnerAngle += 360 }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
        }
        .onDisappear {
            spinnerTask?.cancel()
            spinnerTask = nil
        }
    }
}

// MARK: - §3.4 ListCard

struct ListCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 4, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ContentColors.surfaceSecondary)
        .smoothCorner(Radius.md)
    }
}

// MARK: - §4.1 Checkbox (iOS)

struct SharedCheckbox: View {
    let label: String
    let isChecked: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(
                            isChecked ? BrandColors.borderActive : BrandColors.borderDefault,
                            lineWidth: isChecked ? 0 : 0.25
                        )
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(isChecked ? ContentColors.surfaceActive : Color.clear)
                        )
                        .frame(width: 22, height: 22)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(BrandColors.borderActive)
                    }
                }
                Text(label)
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - §4.2 RadioButton (generic — used everywhere, not just country picker)

struct SharedRadioButton: View {
    let label: String
    let isSelected: Bool
    var countryCode: String? = nil
    var flagUrl: String? = nil
    var background: Color = ContentColors.surfaceSecondary
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? ContentColors.borderActive : ContentColors.borderDefault,
                            lineWidth: isSelected ? 2 : 1
                        )
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(ContentColors.borderActive)
                            .frame(width: 10, height: 10)
                    }
                }

                Text(label)
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(ContentColors.foregroundPrimary)

                Spacer(minLength: 0)

                if let code = countryCode, let url = flagUrl {
                    CountryFlagView(flagUrl: url, code: code)
                        .frame(width: 30, height: 20)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(isSelected ? ContentColors.surfaceActive : background)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? ContentColors.borderActive : ContentColors.borderDefault,
                        lineWidth: 0.25
                    )
            )
            .smoothCorner(Radius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - §4.3 SearchInput
// 48pt tall outlined field, Radius.MD, magnifying glass leading.

struct SearchInput: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ContentColors.formPlaceholder)
            TextField(placeholder, text: $text)
                .font(AppTypography.bodyMedium())
                .foregroundStyle(ContentColors.foregroundPrimary)
                .tint(ContentColors.borderActive)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(ContentColors.surfaceSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(ContentColors.borderDefault, lineWidth: 0.5)
        )
        .smoothCorner(Radius.md)
    }
}

// MARK: - §4.4 FormTextInput

enum TextInputState {
    case `default`
    case active
    case disabled
    case error
}

struct FormTextInput: View {
    @Binding var text: String
    var placeholder: String = ""
    var label: String? = nil
    var helper: String? = nil
    var state: TextInputState = .default
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var height: CGFloat = 56
    var isFocused: Bool = false
    var onCommit: (() -> Void)? = nil

    private var borderColor: Color {
        switch state {
        case .active: return ContentColors.borderActive
        case .error: return BrandColors.feedbackFail
        case .disabled: return ContentColors.borderDefault
        case .default: return isFocused ? ContentColors.borderActive : ContentColors.borderDefault
        }
    }

    private var borderWidth: CGFloat {
        switch state {
        case .active, .error: return 2
        default: return isFocused ? 2 : 0.5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label)
                    .font(AppTypography.labelMedium())
                    .foregroundStyle(ContentColors.foregroundPrimary)
            }
            TextField(placeholder, text: $text, onCommit: { onCommit?() })
                .font(AppTypography.bodyLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)
                .tint(ContentColors.borderActive)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(ContentColors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )
                .smoothCorner(Radius.md)
                .disabled(state == .disabled)
            if let helper = helper {
                Text(helper)
                    .font(AppTypography.labelSmall())
                    .foregroundStyle(state == .error ? BrandColors.feedbackFail : ContentColors.foregroundSecondary)
            }
        }
    }
}

// MARK: - §9.1 ListItem

struct ListItem: View {
    let label: String
    var icon: String? = nil
    var rightLabel: String? = nil
    var showChevron: Bool = true
    var showDivider: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(ContentColors.foregroundPrimary)
                            .frame(width: 20, height: 20)
                    }
                    Text(label)
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(ContentColors.foregroundPrimary)
                    Spacer(minLength: 0)
                    if let right = rightLabel {
                        Text(right)
                            .font(AppTypography.bodyMedium())
                            .foregroundStyle(ContentColors.foregroundSecondary)
                    }
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ContentColors.foregroundPrimary)
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(minHeight: 48)

                if showDivider {
                    Rectangle()
                        .fill(ContentColors.borderDefault)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - §10.1 LogoSpinner
// Rotates 360° in 600ms eased bursts, held flat for 3000ms between bursts.

enum LogoSpinnerType {
    case vertical
    case horizontal
}

struct LogoSpinner: View {
    var type: LogoSpinnerType = .vertical
    var color: Color = AppColors.green500
    var label: String? = nil
    /// When true: steady linear rotation with no pause (use for in-progress states like "Getting your answer").
    /// When false (default): 3-second idle pause then a quick burst spin.
    var continuous: Bool = false

    @State private var rotation: Double = 0
    @State private var rotationTask: Task<Void, Never>? = nil

    private var spinnerSize: CGFloat { type == .vertical ? 55 : 40 }
    private var logoSize: CGFloat { type == .vertical ? 32 : 23 }
    private var strokeWidth: CGFloat { type == .vertical ? 3 : 2.5 }

    var body: some View {
        Group {
            if type == .vertical {
                VStack(spacing: 12) {
                    core
                    if let label = label {
                        Text(label)
                            .font(AppTypography.labelMedium())
                            .foregroundStyle(ContentColors.foregroundSecondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    core
                    if let label = label {
                        Text(label)
                            .font(AppTypography.labelMedium())
                            .foregroundStyle(ContentColors.foregroundSecondary)
                    }
                }
            }
        }
        .onAppear { startRotation() }
        .onDisappear {
            rotationTask?.cancel()
            rotationTask = nil
        }
    }

    private var core: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: spinnerSize, height: spinnerSize)
                .rotationEffect(.degrees(rotation))
            LogoMarkShape()
                .fill(color)
                .frame(width: logoSize, height: logoSize)
                .rotationEffect(.degrees(rotation))
        }
    }

    private func startRotation() {
        rotationTask?.cancel()
        rotationTask = Task { @MainActor in
            if continuous {
                // Steady linear spin: sleep slightly shorter than the animation so each
                // new animation begins just before the previous one ends — no gap.
                while !Task.isCancelled {
                    withAnimation(.linear(duration: 0.85)) { rotation += 360 }
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            } else {
                // Burst mode: 3-second idle pause, then a quick easeOut spin.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if Task.isCancelled { return }
                    withAnimation(.easeOut(duration: 0.6)) { rotation += 360 }
                    try? await Task.sleep(nanoseconds: 600_000_000)
                }
            }
        }
    }
}

// MARK: - §10.4 Toast

enum ToastState {
    case success
    case error
    case loading
}

struct Toast: View {
    let message: String
    var state: ToastState = .success

    private var iconBg: Color {
        switch state {
        case .success, .loading: return AppColors.green500
        case .error: return AppColors.red500
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconBg).frame(width: 32, height: 32)
                switch state {
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.white)
                case .error:
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.white)
                case .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.white))
                        .scaleEffect(0.7)
                }
            }
            Text(message)
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
    }
}

/// Host a toast at the top of any screen. Auto-dismisses after 3s unless `.loading`.
struct ToastHost: ViewModifier {
    @Binding var message: String?
    @Binding var state: ToastState

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let msg = message {
                Toast(message: msg, state: state)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: msg) {
                        guard state != .loading else { return }
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) { message = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message)
    }
}

extension View {
    func toastHost(message: Binding<String?>, state: Binding<ToastState>) -> some View {
        modifier(ToastHost(message: message, state: state))
    }
}

// MARK: - §11.1 Glow
// 88pt tall yellow/green drawable at TopCenter. Uses Asset Catalog drawables if present,
// otherwise synthesizes a radial gradient as a visual fallback.

enum GlowType {
    case green
    case yellow
}

struct Glow: View {
    let type: GlowType

    private var assetName: String { type == .green ? "glow_green" : "glow_yellow" }

    private var fallbackColor: Color {
        type == .green ? AppColors.green500.opacity(0.25) : AppColors.sun300.opacity(0.30)
    }

    var body: some View {
        #if canImport(UIKit)
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RadialGradient(
                colors: [fallbackColor, .clear],
                center: .top,
                startRadius: 0,
                endRadius: 80
            )
        }
        #else
        RadialGradient(
            colors: [fallbackColor, .clear],
            center: .top,
            startRadius: 0,
            endRadius: 80
        )
        #endif
    }
}

// MARK: - §11.3 FeedHeader

struct FeedHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTypography.titleMedium())
            .foregroundStyle(ContentColors.foregroundPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 20, leading: 24, bottom: 16, trailing: 24))
    }
}

// MARK: - §11.4 FeedFooter

struct FeedFooter: View {
    let tagline: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Glow(type: .green)
                .frame(height: 100)
                .opacity(0.8)
                .scaleEffect(x: 1, y: -1)

            VStack(spacing: 16) {
                LogoMarkShape()
                    .fill(ContentColors.borderActive)
                    .frame(width: 34, height: 34)
                Text(tagline)
                    .font(AppTypography.titleMedium())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 44)
            .padding(.bottom, 56)
        }
    }
}

// MARK: - Full-screen loader (shared convenience wrapping LogoSpinner + brand bg)

struct BrandFullScreenLoader: View {
    var label: String? = "Loading..."

    var body: some View {
        ZStack {
            BrandColors.surfacePrimary.ignoresSafeArea()
            LogoSpinner(type: .vertical, color: BrandColors.foregroundPrimary, label: label)
        }
    }
}

// MARK: - UI_ERROR.md §1 — FullScreenMessage
// Brand-green hero container with yellow Glow behind the app bar, pill-shaped 300:450
// illustration, displaySmall mainMessage + bodyMedium subtitle, 64pt PrimaryButton.
// Optional 1500ms debounce turns the button into the loading state while the handler runs.

struct FullScreenMessage: View {
    let title: String
    let mainMessage: String
    var subtitle: String? = nil
    let primaryCtaLabel: String
    var primaryCtaState: PrimaryButtonState = .chevron
    let onPrimaryCta: () -> Void
    var illustration: String = "image_card1"
    var showGradientOverlay: Bool = false
    var enableDebounce: Bool = false
    var leftIcon: String? = nil
    var onLeft: (() -> Void)? = nil
    var rightLabel: String? = nil
    var onRight: (() -> Void)? = nil
    /// Override for AccountSuccess (`bodyLarge`); defaults to `bodyMedium` per §3.
    var subtitleFont: Font? = nil

    @State private var isDebouncing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            illustrationAndText
            buttonArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .top) {
                BrandColors.surfacePrimary
                Glow(type: .yellow)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        )
        .task(id: isDebouncing) {
            guard isDebouncing else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            isDebouncing = false
        }
    }

    // MARK: Header (custom — can't reuse DefaultAppBar because bg is brand green)

    private var header: some View {
        HStack(spacing: 0) {
            headerLeftSlot
            Spacer(minLength: 0)
            Text(title)
                .font(AppTypography.titleMedium())
                .foregroundStyle(BrandColors.foregroundPrimary)
            Spacer(minLength: 0)
            headerRightSlot
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
    }

    @ViewBuilder
    private var headerLeftSlot: some View {
        if let icon = leftIcon, let action = onLeft {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColors.foregroundPrimary)
                    .frame(width: 42, height: 42)
                    .background(BrandColors.surfaceSecondary)
                    .smoothCorner(Radius.md)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 42, height: 42)
        }
    }

    @ViewBuilder
    private var headerRightSlot: some View {
        if let label = rightLabel, let action = onRight {
            Button(action: action) {
                Text(label)
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(BrandColors.foregroundPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(BrandColors.surfaceSecondary)
                    .smoothCorner(Radius.md)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 42, height: 42)
        }
    }

    // MARK: Illustration + text

    private var illustrationAndText: some View {
        VStack(spacing: 0) {
            illustrationBox
                .padding(.vertical, 16)

            VStack(spacing: 10) {
                Text(mainMessage)
                    .font(AppTypography.displaySmall())
                    .foregroundStyle(BrandColors.foregroundPrimary)
                    .multilineTextAlignment(.center)

                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(subtitleFont ?? AppTypography.bodyMedium())
                        .foregroundStyle(BrandColors.foregroundPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var illustrationBox: some View {
        let pill = RoundedRectangle(cornerRadius: Radius.rounded, style: .continuous)
        ZStack {
            if let img = UIImage(named: illustration), !img.size.equalTo(.zero) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(300.0/450.0, contentMode: .fill)
            } else {
                BrandColors.surfaceSecondary
            }
            if showGradientOverlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.77),
                        .init(color: .black.opacity(0.4), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: 300)
        .aspectRatio(300.0/450.0, contentMode: .fit)
        .clipShape(pill)
    }

    // MARK: Primary CTA

    private var buttonArea: some View {
        let state: PrimaryButtonState = (enableDebounce && isDebouncing) ? .loading : primaryCtaState
        return PrimaryButton(
            label: primaryCtaLabel,
            state: state,
            height: 64,
            action: {
                guard !(enableDebounce && isDebouncing) else { return }
                if enableDebounce { isDebouncing = true }
                onPrimaryCta()
            }
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - UI_HOME.md §3, §10 — AttentionWobble
// One-shot ±3° wiggle after an initial delay. Fires only the first time `trigger`
// flips true after the view mounts.

struct AttentionWobble: ViewModifier {
    let trigger: Bool
    var delayMs: Int = 1000
    var maxAngle: Double = 3

    @State private var angle: Double = 0
    @State private var hasFired = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear { if trigger { scheduleWobble() } }
            .onChange(of: trigger) { _, new in
                if new { scheduleWobble() }
            }
    }

    private func scheduleWobble() {
        guard !hasFired else { return }
        hasFired = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
            let spring = Animation.spring(response: 0.18, dampingFraction: 0.5)
            withAnimation(spring) { angle = maxAngle }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(spring) { angle = -maxAngle }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(spring) { angle = 0 }
                }
            }
        }
    }
}

extension View {
    func attentionWobble(trigger: Bool, delayMs: Int = 1000, maxAngle: Double = 3) -> some View {
        modifier(AttentionWobble(trigger: trigger, delayMs: delayMs, maxAngle: maxAngle))
    }
}

// MARK: - UI_HOME.md §3 — GreetingSkeleton
// Shimmer-animated pill that stands in for the greeting while `greetingFromFeed` is loading.

struct GreetingSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        Capsule()
            .fill(BrandColors.foregroundPrimary.opacity(shimmer ? 0.10 : 0.24))
            .frame(maxWidth: 260)
            .frame(height: 20)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    shimmer.toggle()
                }
            }
    }
}
