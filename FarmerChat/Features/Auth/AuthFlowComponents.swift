//
//  AuthFlowComponents.swift
//  FarmerChat
//
//  Shared UI for login flow: green header bar, progress dots. Matches screenshot design.
//

import SwiftUI

/// Green header: [back or X] title [optional Skip]. White foreground.
struct AuthFlowHeader: View {
    let title: String
    var showSkip: Bool = false
    var useBackButton: Bool = false
    var onClose: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: useBackButton ? "chevron.left" : "xmark")
                    .font(.system(size: useBackButton ? 18 : 16, weight: .medium))
                    .foregroundStyle(AppColors.onboardingWhite)
                    .frame(width: 42, height: 42)
                    .background(AppColors.menuButtonDarkGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.onboardingWhite)
            Spacer()
            if showSkip, let skip = onSkip {
                Button("Skip", action: skip)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.onboardingWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.authButtonDarkGreen)
                    .clipShape(Capsule())
            } else {
                Color.clear.frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppColors.authHeaderGreen)
    }
}

/// Four horizontal dots; filled up to and including current step (1...4).
struct AuthProgressDots: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? AppColors.onboardingVibrantGreen : AppColors.onboardingSoftGrey)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - UI_AUTH.md §2 — CountryCodeSelector

/// Compact button with flag + dial code, used on the phone-entry row. 56pt tall, Radius.md.
struct CountryCodeSelector: View {
    let countryCode: String      // "+91"
    let flagUrl: String?          // http URL or nil → emoji fallback
    let countryIso: String        // "IN" — drives emoji fallback
    var minWidth: CGFloat = 90
    var height: CGFloat = 56
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                CountryFlagView(flagUrl: flagUrl ?? "", code: countryIso)
                    .frame(width: 21, height: 15)
                Text(countryCode)
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(ContentColors.foregroundPrimary)
            }
            .padding(.horizontal, 14)
            .frame(minWidth: minWidth)
            .frame(height: height)
            .background(ContentColors.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(ContentColors.borderDefault, lineWidth: 0.5)
            )
            .smoothCorner(Radius.md)
        }
        .buttonStyle(.plain)
    }
}

/// Loading placeholder shown before the countries list resolves — same footprint as the selector.
struct CountryCodeLoadingBox: View {
    var minWidth: CGFloat = 90
    var height: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(ContentColors.surfaceSecondary)
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(ContentColors.borderDefault, lineWidth: 0.5)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ContentColors.borderActive))
                .scaleEffect(0.85)
        }
        .frame(minWidth: minWidth)
        .frame(height: height)
        .smoothCorner(Radius.md)
    }
}

// MARK: - UI_AUTH.md §3 — OtpInput (4-digit with iOS auto-fill)

/// 4-digit OTP field with `.textContentType(.oneTimeCode)` — iOS Messages autofill works out of the box.
/// Backed by a single hidden TextField so a full code arrives in one set; visual boxes reflect `value`.
struct OtpInput: View {
    @Binding var value: String
    var length: Int = 4
    var isError: Bool = false
    var enabled: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { i in
                    digitBox(index: i)
                }
            }
            TextField("", text: Binding(
                get: { value },
                set: { new in
                    let digits = new.filter { $0.isNumber }
                    value = String(digits.prefix(length))
                }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .foregroundStyle(Color.clear)
            .accentColor(Color.clear)
            .opacity(0.02)
            .disabled(!enabled)
        }
        .contentShape(Rectangle())
        .onTapGesture { if enabled { isFocused = true } }
        .onAppear {
            // Spec §11 — "Keyboard pops up on screen appear"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if enabled { isFocused = true }
            }
        }
    }

    private func digitBox(index: Int) -> some View {
        let ch: String = {
            guard index < value.count else { return "" }
            let i = value.index(value.startIndex, offsetBy: index)
            return String(value[i])
        }()
        let hasValue = !ch.isEmpty
        let border: Color = {
            if isError { return BrandColors.feedbackFail }
            if hasValue { return ContentColors.borderActive }
            return ContentColors.borderDefault
        }()
        let lineWidth: CGFloat = (isError || hasValue) ? 2 : 1

        return Text(ch)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(ContentColors.foregroundPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(ContentColors.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: lineWidth)
            )
            .smoothCorner(Radius.md)
    }
}
