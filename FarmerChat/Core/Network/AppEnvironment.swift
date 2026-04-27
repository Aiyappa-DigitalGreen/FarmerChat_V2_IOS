//
//  AppEnvironment.swift
//  FarmerChat
//
//  Build flavors → base URL (dev, stage, demo, prod).
//

import Foundation

enum AppEnvironment: String, CaseIterable {
    case dev
    case stage
    case demo
    case prod

    var baseURL: String {
        switch self {
        case .dev: return "https://farmerchat.farmstack.co/mobile-app-dev/"
        case .stage: return "https://farmerchat.farmstack.co/mobile-app-stage/"
        case .demo: return "https://farmerchat.farmstack.co/mobile-app-demo/"
        case .prod: return "https://farmerchat.farmstack.co/mobile-app-prod/"
        }
    }

    static var current: AppEnvironment {
        #if STAGE
        return .stage
        #elseif DEBUG
        return .dev
        #else
        return .prod
        #endif
    }
}
