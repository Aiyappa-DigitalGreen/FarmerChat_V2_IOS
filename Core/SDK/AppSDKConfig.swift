//
//  AppSDKConfig.swift
//  FarmerChat
//
//  Gate for all third-party SDKs. NO events are sent on any screen until product explicitly enables.
//

import Foundation

enum AppSDKConfig {
    /// Master switch. Must remain false so that no SDK (MoEngage, Plotline, Firebase, Adjust, etc.)
    /// is initialised and no analytics/tracking events are triggered on any screen.
    /// Do not set to true unless product explicitly requests SDK events.
    static var sdkEventsEnabled: Bool = false

    /// When false, MoEngage is not initialised and no events are sent.
    static var enableMoEngage: Bool { sdkEventsEnabled && false }

    /// When false, Plotline is not initialised and no events are sent.
    static var enablePlotline: Bool { sdkEventsEnabled && false }

    /// When false, Firebase (Analytics, Crashlytics, FCM) is not initialised and no events are sent.
    static var enableFirebase: Bool { sdkEventsEnabled && false }

    /// When false, Adjust is not initialised and no attribution events are sent.
    static var enableAdjust: Bool { sdkEventsEnabled && false }
}
