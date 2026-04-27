//
//  Color+Hex.swift
//  FarmerChat
//
//  Hex color support to match Android theme values.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Create from 0xFFRRGGBB (opaque) or 0xAARRGGBB.
    init(hex: UInt32) {
        let a = (hex >> 24) & 0xFF
        let r = (hex >> 16) & 0xFF
        let g = (hex >> 8) & 0xFF
        let b = hex & 0xFF
        let alpha = a == 0 ? 1.0 : Double(a) / 255.0
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: alpha
        )
    }

    /// Resolve light/dark at render time via trait collection. Needed because raw
    /// hex `Color` values are fixed sRGB — `.preferredColorScheme(.dark)` only flips
    /// colors backed by a `UIColor` with a dynamic provider.
    static func dynamic(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #else
        return light
        #endif
    }
}
