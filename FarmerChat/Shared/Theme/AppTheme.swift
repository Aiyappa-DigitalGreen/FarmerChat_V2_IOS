//
//  AppTheme.swift
//  FarmerChat
//
//  Theme & Design System — mirrors Android (ColorPrimitives, ContentColors, Type.kt).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import CoreText
#endif

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Codable {
    case day = "day"
    case night = "night"
    case auto = "auto"
}

// MARK: - Layout tokens

struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 36
}

// Canonical spacing from UI_THEME.md §7 — use for all new screens.
// Legacy AppSpacing values above are kept for already-built screens.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 40
    static let button: CGFloat = 56
    static let appBar: CGFloat = 56
    static let bottomBarPadTop: CGFloat = 28
    static let spacerToBottomBar: CGFloat = 220
}

struct AppRadii {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

// Canonical radii from UI_THEME.md §6.1 — Android SmoothShapes / Radius tokens.
// Values differ from AppRadii on purpose (spec: MD=12 vs legacy AppRadii.md=16).
// New screens must use `Radius.*`. Existing screens untouched until migrated.
enum Radius {
    static let none: CGFloat = 0
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let rounded: CGFloat = 999
}

struct AppShadows {
    static let soft = (color: Color.black.opacity(0.08), radius: CGFloat(14), y: CGFloat(6))
    static let crisp = (color: Color.black.opacity(0.12), radius: CGFloat(10), y: CGFloat(4))
}

// MARK: - Colors (match Android theme/ColorPrimitives.kt & ColorContentSemantic.kt)

struct AppColors {
    // Primitives (Android ColorPrimitives.kt)
    static let white = Color(hex: 0xFFFFFFFF)
    static let black = Color(hex: 0xFF000000)
    static let neutral50 = Color(hex: 0xFFFAFAFA)
    static let neutral100 = Color(hex: 0xFFF4F4F5)
    static let neutral150 = Color(hex: 0xFFECECEE)
    static let neutral200 = Color(hex: 0xFFE4E4E7)
    static let neutral300 = Color(hex: 0xFFD4D4D8)
    static let neutral400 = Color(hex: 0xFF9F9FA9)
    static let neutral500 = Color(hex: 0xFF71717B)
    static let neutral600 = Color(hex: 0xFF52525C)
    static let neutral700 = Color(hex: 0xFF3F3F46)
    static let neutral800 = Color(hex: 0xFF27272A)
    static let neutral900 = Color(hex: 0xFF18181B)
    static let neutral950 = Color(hex: 0xFF09090B)
    static let green500 = Color(hex: 0xFF00C950)
    static let green500_8 = Color(hex: 0x1400C950)
    static let green500_16 = Color(hex: 0x2900C950)
    static let green700 = Color(hex: 0xFF008236)
    static let green800 = Color(hex: 0xFF08361B)
    static let green950 = Color(hex: 0xFF032E15)
    static let sky400 = Color(hex: 0xFF00BCFF)
    static let sky700 = Color(hex: 0xFF0069A8)
    static let sun300 = Color(hex: 0xFFF9FF47)
    static let red500 = Color(hex: 0xFFE5533D)

    // Light content (Android LightContentColors)
    static let surfacePrimary = neutral150
    static let surfaceSecondary = white
    static let surfaceTertiary = neutral200
    static let foregroundPrimary = black
    static let foregroundSecondary = neutral600
    static let foregroundTertiary = neutral300
    static let buttonPrimarySurface = green800
    static let buttonPrimaryForeground = white
    static let buttonPrimaryAccent = green500
    static let borderDefault = neutral300
    static let borderActive = green500
    static let formPlaceholder = neutral500

    // Legacy / aliases
    static let primary = green800
    static let primaryContainer = green500_16
    static let onPrimary = white
    static let onPrimaryContainer = black
    static let surface = neutral150
    static let surfaceVariant = neutral200
    static let onSurface = black
    static let onSurfaceVariant = neutral600
    static let outline = neutral300
    static let background = neutral100
    static let onBackground = black
    static let error = red500
    static let onError = white

    static var primaryFallback: Color { green800 }
    static var surfaceFallback: Color { neutral150 }
    static var backgroundFallback: Color { neutral100 }

    // Splash (Android res/values/colors.xml)
    static let splashBackground = Color(hex: 0xFFF4F4F5)

    // Language bottom panel (Android BottomPanel.kt)
    static let getStartedEnabled = Color(hex: 0xFF143D2A)
    static let getStartedDisabled = Color(hex: 0xFF9BB3A8)
    static let legalTextGray = Color(hex: 0xFF6A6A6A)
    static let legalLinkBlue = Color(hex: 0xFF4F6FD8)

    // Onboarding design system (agriculture-inspired)
    static let onboardingVibrantGreen = Color(hex: 0xFF2E7D32)   // Primary buttons, progress, active
    static let onboardingVibrantGreenBright = Color(hex: 0xFF4CAF50)
    static let onboardingWhite = Color(hex: 0xFFFFFFFF)
    static let onboardingLightGreen = Color(hex: 0xFFE8F5E9)     // AI bubbles, selected card bg
    static let onboardingCharcoalBlack = Color(hex: 0xFF000000)
    static let onboardingDarkGrey = Color(hex: 0xFF4A4A4A)       // Secondary text
    static let onboardingSoftGrey = Color(hex: 0xFFE0E0E0)       // Borders, dividers

    // Boot screen gradient (yellow-green top → deep green bottom)
    static let bootGradientTop = Color(hex: 0xFF81C784)
    static let bootGradientBottom = Color(hex: 0xFF2E7D32)

    // Onboarding boot gradient stops — UI_THEME.md §1.6 legacy palette.
    // Drives SplashView background until `boot_bg` asset is added to the Asset Catalog.
    static let gradientYellow = Color(hex: 0xFFF9FF47)
    static let gradientMidGreen = Color(hex: 0xFF69C46C)
    static let gradientDarkGreen = Color(hex: 0xFF093D1F)

    // Auth flow (green header bar, white text)
    static let authHeaderGreen = Color(hex: 0xFF008236)
    static let authSectionGreen = Color(hex: 0xFF08361B)
    static let authButtonDarkGreen = Color(hex: 0xFF08361B)
    static let menuButtonDarkGreen = Color(hex: 0xFF032E15)
    static let accentGreen = Color(hex: 0xFF00C950)

    // Adaptive (resolve light/dark from environment when .preferredColorScheme is set)
    #if canImport(UIKit)
    static let adaptiveGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let adaptiveSecondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let adaptiveTertiaryGroupedBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let adaptiveLabel = Color(uiColor: .label)
    static let adaptiveSecondaryLabel = Color(uiColor: .secondaryLabel)
    static let adaptiveTertiaryLabel = Color(uiColor: .tertiaryLabel)
    static let adaptiveSeparator = Color(uiColor: .separator)
    static let adaptiveFill = Color(uiColor: .secondarySystemFill)
    #else
    static let adaptiveGroupedBackground = neutral100
    static let adaptiveSecondaryGroupedBackground = white
    static let adaptiveTertiaryGroupedBackground = neutral150
    static let adaptiveLabel = black
    static let adaptiveSecondaryLabel = neutral600
    static let adaptiveTertiaryLabel = neutral500
    static let adaptiveSeparator = neutral300
    static let adaptiveFill = neutral150
    #endif
}

// MARK: - Canonical semantic tokens (match UI_THEME.md §2, §3)
// New screens/components MUST use these namespaces. Existing code keeps AppColors.*.

// Content semantic — neutral page UI. Light values from UI_THEME.md §3.1;
// dark values from §3.2. Tokens resolve via trait collection, so
// `.preferredColorScheme(.dark)` on the root actually flips page surfaces,
// foregrounds, borders, etc. across every screen that uses this namespace.
enum ContentColors {
    static let surfacePrimary = Color.dynamic(light: AppColors.neutral150, dark: AppColors.neutral900)
    static let surfaceSecondary = Color.dynamic(light: AppColors.white, dark: AppColors.neutral800)
    static let surfaceTertiary = Color.dynamic(light: AppColors.neutral200, dark: AppColors.neutral700)
    static let surfaceActive = AppColors.green500_16 // same in both modes
    static let surfaceReadingPrimary = Color.dynamic(light: AppColors.white, dark: AppColors.neutral900)
    static let surfaceReadingSecondary = Color.dynamic(light: AppColors.neutral150, dark: AppColors.neutral800)
    static let surfaceReadingTertiary = Color.dynamic(light: AppColors.white, dark: AppColors.neutral900)
    static let foregroundPrimary = Color.dynamic(light: AppColors.black, dark: AppColors.white)
    static let foregroundSecondary = Color.dynamic(light: AppColors.neutral600, dark: AppColors.neutral400)
    static let foregroundTertiary = Color.dynamic(light: AppColors.neutral300, dark: AppColors.neutral700)
    static let buttonPrimarySurface = Color.dynamic(light: AppColors.green800, dark: AppColors.green700)
    static let buttonPrimaryForeground = AppColors.white // same in both modes
    static let buttonPrimaryAccent = AppColors.green500 // same in both modes
    static let borderDefault = Color.dynamic(light: AppColors.neutral300, dark: AppColors.neutral700)
    static let borderActive = AppColors.green500 // same in both modes
    static let formPlaceholder = Color.dynamic(light: AppColors.neutral500, dark: AppColors.neutral400)
    static let scrim = Color.dynamic(light: AppColors.black.opacity(0.5), dark: AppColors.black.opacity(0.6))
    static let shimmer = Color.dynamic(light: AppColors.neutral100, dark: AppColors.neutral900)
    static let shine = Color.dynamic(light: AppColors.black, dark: AppColors.white)
}

// Brand semantic — green slabs (UI_THEME.md §2).
enum BrandColors {
    static let surfacePrimary = AppColors.green700
    static let surfaceSecondary = AppColors.green800
    static let surfaceTertiary = AppColors.green950
    static let foregroundPrimary = AppColors.white
    static let foregroundSecondary = AppColors.green500
    static let feedbackSuccess = AppColors.green500
    static let feedbackFail = AppColors.red500
    // Convenience mirrors that brand-themed components need alongside surface/fg tokens.
    static let buttonPrimarySurface = AppColors.green800
    static let buttonPrimaryForeground = AppColors.white
    static let buttonPrimaryAccent = AppColors.green500
    static let borderDefault = AppColors.neutral300
    static let borderActive = AppColors.green500
    static let scrim = AppColors.black.opacity(0.5)
}

// MARK: - Typography (matches Android Type.kt — Roboto Flex variable font)

struct AppTypography {
    // Roboto Flex variable font with weight axis values matching Android Type.kt.
    // wght FourCC tag = 0x77676874 = 2003265652.
    // Falls back to system font if Roboto Flex is not registered.
    #if canImport(UIKit)
    private static func robotoFlex(size: CGFloat, weight: Int) -> Font {
        let wghtTag = NSNumber(value: Int32(bitPattern: 0x77676874))
        let variations: [NSNumber: NSNumber] = [wghtTag: NSNumber(value: Float(weight))]
        let descriptor = UIFontDescriptor(name: "RobotoFlex-Regular", size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations
            ])
        let uiFont = UIFont(descriptor: descriptor, size: size)
        return Font(uiFont)
    }
    #else
    private static func robotoFlex(size: CGFloat, weight: Int) -> Font { .system(size: size) }
    #endif

    // Display — weight 650
    static func displayLarge() -> Font { robotoFlex(size: 35, weight: 650) }
    static func displayMedium() -> Font { robotoFlex(size: 28, weight: 650) }
    static func displaySmall() -> Font { robotoFlex(size: 24, weight: 650) }
    // Title — weight 680
    static func titleLarge() -> Font { robotoFlex(size: 22, weight: 680) }
    static func titleMedium() -> Font { robotoFlex(size: 18, weight: 680) }
    static func titleSmall() -> Font { robotoFlex(size: 16, weight: 680) }
    // Body — weight 425
    static func bodyLarge() -> Font { robotoFlex(size: 19, weight: 425) }
    static func bodyMedium() -> Font { robotoFlex(size: 17, weight: 425) }
    static func bodySmall() -> Font { robotoFlex(size: 15, weight: 425) }
    // Label — weight 560
    static func labelLarge() -> Font { robotoFlex(size: 17, weight: 560) }
    static func labelMedium() -> Font { robotoFlex(size: 15, weight: 560) }
    static func labelSmall() -> Font { robotoFlex(size: 13, weight: 560) }
    // Caption — weight 425
    static func caption() -> Font { robotoFlex(size: 13, weight: 425) }

    // Onboarding
    static func onboardingPrimaryHeading() -> Font { robotoFlex(size: 26, weight: 680) }
    static func onboardingSecondaryText() -> Font { robotoFlex(size: 17, weight: 425) }
    static func onboardingButtonText() -> Font { robotoFlex(size: 16, weight: 560) }
}

// MARK: - Components

struct AppCardModifier: ViewModifier {
    var background: Color = AppColors.adaptiveSecondaryGroupedBackground
    var radius: CGFloat = AppRadii.lg
    var border: Color? = AppColors.adaptiveSeparator.opacity(0.55)
    var padded: Bool = true
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padded ? AppSpacing.lg : 0)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(border ?? .clear, lineWidth: border == nil ? 0 : 1)
            )
            .shadow(
                color: shadow ? AppShadows.soft.color : .clear,
                radius: shadow ? AppShadows.soft.radius : 0,
                x: 0,
                y: shadow ? AppShadows.soft.y : 0
            )
    }
}

extension View {
    func appCard(
        background: Color = AppColors.adaptiveSecondaryGroupedBackground,
        radius: CGFloat = AppRadii.lg,
        border: Color? = AppColors.adaptiveSeparator.opacity(0.55),
        padded: Bool = true,
        shadow: Bool = true
    ) -> some View {
        modifier(AppCardModifier(background: background, radius: radius, border: border, padded: padded, shadow: shadow))
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    var height: CGFloat = 52
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(AppTypography.bodyMedium())
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: height)
            .background(AppColors.adaptiveSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.md))
            .overlay(RoundedRectangle(cornerRadius: AppRadii.md).stroke(AppColors.adaptiveSeparator.opacity(0.65), lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge())
            .foregroundStyle(AppColors.buttonPrimaryForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [AppColors.green800, AppColors.green700],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.md))
            .shadow(color: AppShadows.crisp.color, radius: AppShadows.crisp.radius, x: 0, y: AppShadows.crisp.y)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge())
            .foregroundStyle(AppColors.buttonPrimarySurface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.adaptiveSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.md))
            .overlay(RoundedRectangle(cornerRadius: AppRadii.md).stroke(AppColors.buttonPrimarySurface.opacity(0.85), lineWidth: 1))
            .shadow(color: AppShadows.soft.color, radius: 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Scale down slightly on press for a tactile feel (onboarding/auth).
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Smooth corner / elevated card helpers (UI_THEME.md §6)
// Android SmoothShapes use corner-smoothing = 1.0 (squircle). RoundedRectangle(style: .continuous)
// is iOS's native equivalent — always use .continuous, never .circular.

extension View {
    /// Clip with a continuous-curvature rounded rectangle (Android SmoothShapes parity).
    func smoothCorner(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Containers.elevated — radius + double shadow (~24% black, blur 40 + 10).
    func elevatedCard(radius: CGFloat, background: Color) -> some View {
        self
            .background(background)
            .smoothCorner(radius)
            .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 0)
    }

    /// Apply an absolute line-height (pt). Pairs with typography tokens whose line-height
    /// is absolute, not a multiplier (UI_THEME.md §5.2).
    func lineHeight(_ lineHeightPt: CGFloat, fontSize: CGFloat) -> some View {
        self.lineSpacing(max(0, lineHeightPt - fontSize))
    }
}

// MARK: - Tap-scale modifier (UI_COMPONENTS.md §12.2)

struct TapScaleModifier: ViewModifier {
    var targetScale: CGFloat = 0.95
    var haptic: Bool = true
    let action: () -> Void
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeOut(duration: 0.1)) { scale = targetScale }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.2)) { scale = 1 }
                        #if canImport(UIKit)
                        if haptic {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        #endif
                        action()
                    }
            )
    }
}

extension View {
    func tapScale(target: CGFloat = 0.95, haptic: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(TapScaleModifier(targetScale: target, haptic: haptic, action: action))
    }
}
