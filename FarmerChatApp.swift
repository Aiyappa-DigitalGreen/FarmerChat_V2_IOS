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

@main
struct FarmerChatApp: App {
    @ObservedObject private var prefs = PreferencesManager.shared

    init() {
        let transparent = UINavigationBarAppearance()
        transparent.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = transparent
        UINavigationBar.appearance().compactAppearance = transparent
        UINavigationBar.appearance().scrollEdgeAppearance = transparent
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(prefs.appearanceMode.rawValue)
                .preferredColorScheme(preferredColorScheme)
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
