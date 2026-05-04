//
//  FarmerChatApp.swift
//  FarmerChat
//
//  Created by Aiyappa  Mahalingam on 11/02/26.
//
//  Note: CHHapticPattern / hapticpatternlibrary.plist console errors on Simulator
//  are from system keyboard haptics and can be ignored (see README_iOS_Migration.md).
//

import SwiftUI
import UIKit
import CoreText

@main
struct FarmerChatApp: App {
    @ObservedObject private var prefs = PreferencesManager.shared

    init() {
        registerFonts()
        // Paint the UIKit window green800 (#08361B) immediately so there is no white
        // flash between the system launch screen and SwiftUI's first rendered frame.
        UIWindow.appearance().backgroundColor = UIColor(red: 8/255, green: 54/255, blue: 27/255, alpha: 1)
        let transparent = UINavigationBarAppearance()
        transparent.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = transparent
        UINavigationBar.appearance().compactAppearance = transparent
        UINavigationBar.appearance().scrollEdgeAppearance = transparent
    }

    private func registerFonts() {
        guard let url = Bundle.main.url(forResource: "roboto_flex_variable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    var body: some Scene {
        WindowGroup {
            // AppColors.green800 fills the UIKit window before SwiftUI renders its first
            // frame, preventing the white flash on cold start.
            ZStack {
                AppColors.green800.ignoresSafeArea()
                RootView()
                    .preferredColorScheme(preferredColorScheme)
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch prefs.appearanceMode {
        case .day: return .light
        case .night: return .dark
        case .auto: return nil
        }
    }
}
