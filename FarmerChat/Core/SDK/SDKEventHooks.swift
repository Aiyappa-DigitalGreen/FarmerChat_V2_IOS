//
//  SDKEventHooks.swift
//  FarmerChat
//
//  Plotline / MoEngage / Push per SDK_NOTIFICATION_PAYLOAD_AND_NAVIGATION_FLOW.md.
//  All paths guard on AppSDKConfig.sdkEventsEnabled until SDKs are enabled.
//

import Foundation

enum SDKEventHooks {
    /// Push permission (MoEngage) on Home – per MD "Home screen LaunchedEffect".
    static func requestPushPermissionOnHome() {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // MoEPushHelper.getInstance().requestPushPermission(context)
    }

    /// Plotline redirect – per MD handlePlotlineRedirect(navigator, kv). Case-insensitive + camelCase key lookup; then applyPayload.
    static func handlePlotlineRedirect(navigator: AppNavigator, kv: [String: String]) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        let normalized = normalizePayloadKeys(kv)
        var payload = normalized
        payload["_source"] = "plotline"
        navigator.applyPayload(kv: payload)
    }

    /// MoEngage push tap: parse payload (extras) and apply same navigation. Call from notification delegate with payload as [String: String].
    static func handleMoEngagePushPayload(navigator: AppNavigator, payload: [String: String]) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        let normalized = normalizePayloadKeys(payload)
        var kv = normalized
        kv["_source"] = "moengage"
        navigator.applyPayload(kv: kv)
    }

    /// Normalize keys to lowercase and add canonical aliases (navigation_screen, notification_type, query, response, follow_up_question_1/2/3, action).
    private static func normalizePayloadKeys(_ kv: [String: String]) -> [String: String] {
        var n: [String: String] = [:]
        for (k, v) in kv {
            let key = k.lowercased()
            n[key] = v
            let flat = key.replacingOccurrences(of: "_", with: "")
            if flat == "navigationscreen" || flat == "screen" { n["navigation_screen"] = n["navigation_screen"] ?? v }
            if flat == "notificationtype" { n["notification_type"] = n["notification_type"] ?? v }
            if flat == "ctaaction" { n["action"] = n["action"] ?? v }
            if flat == "followupquestion1" { n["follow_up_question_1"] = n["follow_up_question_1"] ?? v }
            if flat == "followupquestion2" { n["follow_up_question_2"] = n["follow_up_question_2"] ?? v }
            if flat == "followupquestion3" { n["follow_up_question_3"] = n["follow_up_question_3"] ?? v }
        }
        if n["navigation_screen"] == nil, let s = n["screen"] { n["navigation_screen"] = s }
        return n
    }

    /// FCM token for Plotline push – per MD PlotlinePush.setFcmToken() when token available.
    static func setFcmToken(_ token: String) {
        guard AppSDKConfig.sdkEventsEnabled else { return }
        // PlotlinePush.setFcmToken(token)
    }
}
