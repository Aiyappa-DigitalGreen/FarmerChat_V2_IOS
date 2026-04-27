//
//  NotificationPayloadRouter.swift
//  FarmerChat
//
//  Routes MoEngage (and other) push tap payloads to AppNavigator. Per SDK_NOTIFICATION_PAYLOAD_AND_NAVIGATION_FLOW.md.
//  Register navigator from RootView; call handlePushPayload from UNUserNotificationCenterDelegate when user taps notification.
//

import Foundation

enum NotificationPayloadRouter {
    private static weak var _navigator: AppNavigator?

    /// Call from RootView .onAppear so push taps can navigate.
    static func setNavigator(_ navigator: AppNavigator) {
        _navigator = navigator
    }

    /// Call from UNUserNotificationCenterDelegate userNotificationCenter(_:didReceive:withCompletionHandler:) with notification request content as [String: String].
    static func handlePushPayload(_ payload: [String: String]) {
        guard let nav = _navigator else { return }
        SDKEventHooks.handleMoEngagePushPayload(navigator: nav, payload: payload)
    }
}
