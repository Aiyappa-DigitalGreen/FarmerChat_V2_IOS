//
//  AppNavigator.swift
//  FarmerChat
//
//  Central navigation state and routeFromSplash logic.
//

import Foundation
import SwiftUI
import UIKit

@Observable
final class AppNavigator {
    var path = NavigationPath()
    var rootDestination: AppDestination = .splash
    /// Spec cases (SPLASH_SCREEN.md §4.2): persisted deep-link target consumed at splash exit.
    /// For non-spec destinations (auth, settings) captured from a deep link, use `deferredDestination` below.
    private(set) var pendingTarget: PendingTarget? {
        get { prefs.pendingTarget }
        set { prefs.pendingTarget = newValue }
    }
    /// Non-persisted fallback for AppDestination cases the spec's PendingTarget enum does not cover
    /// (currently `.accountBenefits` and `.settings`). Lives only in memory; cleared at consume.
    var deferredDestination: AppDestination?
    var presentedError: ErrorEvent?
    var presentedSheet: AppDestination?
    var showDrawer = false
    /// Transient image captured on Home screen, consumed by ChatView on next navigation.
    var pendingImage: UIImage?

    /// Incremented when user taps "Home" in the drawer so HomeView re-runs its .task and refetches APIs.
    var homeRefreshTrigger = 0

    /// Incremented on each drawer navigation so NavigationStack refreshes when path is replaced.
    var drawerPathVersion = 0

    /// When set, HomeView should trigger GPS campaign flow (widget/Plotline/MoEngage navigation_screen = gps) on appear. Consumed once.
    var pendingGpsCampaignAction: String?
    var pendingGpsTriggerSource: String?

    private let prefs = PreferencesManager.shared

    func setPendingGpsCampaign(action: String?, triggerSource: String) {
        pendingGpsCampaignAction = action
        pendingGpsTriggerSource = triggerSource
    }

    /// Returns (action, triggerSource) and clears. Call from HomeView when showing.
    func consumePendingGpsCampaign() -> (action: String?, triggerSource: String)? {
        guard pendingGpsCampaignAction != nil || pendingGpsTriggerSource != nil else { return nil }
        let action = pendingGpsCampaignAction
        let source = pendingGpsTriggerSource ?? "deeplink"
        pendingGpsCampaignAction = nil
        pendingGpsTriggerSource = nil
        return (action, source)
    }

    /// Persists a `PendingTarget` so a cold-start deep link survives onboarding screens
    /// (SPLASH_SCREEN.md §5.1). Consumed once by `routeFromSplash()`.
    func savePendingTarget(_ target: PendingTarget) {
        pendingTarget = target
    }

    /// Reads and clears the persisted `PendingTarget`. Safe to call multiple times.
    @discardableResult
    func consumePendingTarget() -> PendingTarget? {
        let current = pendingTarget
        if current != nil { pendingTarget = nil }
        return current
    }

    /// Determines first screen after splash (onboarding vs home) and applies any deferred destination.
    /// Onboarding always wins; captured deep-link targets are held until onboarding completes, per spec §5.1.
    ///
    /// SPLASH_SCREEN.md §4 Step 1 — Name-screen gating:
    /// - If profile not done AND name screen never seen:
    ///     - If remote-config `v2_show_name_screen_onboarding == false` → mark done, fall through.
    ///     - Else → show Name.
    /// - Else (name screen already seen) → fall through.
    func routeFromSplash() {
        if !prefs.onboardingLanguageDone {
            rootDestination = .language
            return
        }
        if !prefs.onboardingNameDone {
            if !prefs.nameScreenSeenOnce {
                if FeatureFlags.shared.showNameScreenOnboarding {
                    rootDestination = .enterName
                    return
                } else {
                    prefs.onboardingNameDone = true
                    // fall through to pending-target / home
                }
            }
            // name screen already seen → fall through
        }
        if let pending = consumePendingTarget() {
            applyPendingTarget(pending)
            return
        }
        if let deferred = deferredDestination {
            deferredDestination = nil
            rootDestination = deferred
            return
        }
        rootDestination = .home
    }

    /// Converts a `PendingTarget` to an `AppDestination` and routes (SPLASH_SCREEN.md §4 Step 2).
    /// `.gps(action)` always lands on Home with the GPS campaign action queued for HomeView.
    private func applyPendingTarget(_ target: PendingTarget) {
        switch target {
        case .home:
            rootDestination = .home
        case .chat(let chatId):
            rootDestination = .home
            path = NavigationPath()
            path.append(AppDestination.chat(conversationId: chatId, entrySource: .history))
        case .chatQuery(let question, let source):
            let entry: ChatEntrySource = ChatEntrySource(rawValue: source) ?? .deeplink
            rootDestination = .home
            path = NavigationPath()
            // §5.4: if a qapair payload was stashed alongside this target, adopt its pre-gen content.
            if let pregen = PendingPreGeneratedContentStore.shared.peek(), pregen.question == question {
                PendingPreGeneratedContentStore.shared.consume()
                path.append(AppDestination.chat(
                    question: question,
                    preGeneratedAnswer: pregen.response,
                    followUpQuestions: pregen.followUps.isEmpty ? nil : pregen.followUps,
                    entrySource: entry
                ))
            } else {
                path.append(AppDestination.chat(question: question, entrySource: entry))
            }
        case .gps(let action):
            rootDestination = .home
            setPendingGpsCampaign(action: action, triggerSource: "deeplink")
        }
    }

    func navigate(to destination: AppDestination) {
        if case .error = destination {
            presentedSheet = destination
            return
        }
        if case .legalContent = destination {
            presentedSheet = destination
            return
        }
        path.append(destination)
    }

    /// Clears the navigation stack and pushes the given destination (drawer semantics: go to this screen from root).
    func navigateDrawerRoute(_ destination: AppDestination) {
        rootDestination = .home
        var newPath = NavigationPath()
        newPath.append(destination)
        path = newPath
        drawerPathVersion += 1
    }

    func popToRoot() {
        path = NavigationPath()
        rootDestination = .home
    }

    func popToHome() {
        path = NavigationPath()
        rootDestination = .home
        homeRefreshTrigger += 1
    }

    func setRoot(_ destination: AppDestination) {
        path = NavigationPath()
        rootDestination = destination
    }

    /// Parse a universal-link URL and save a `PendingTarget` for `routeFromSplash` to consume
    /// (SPLASH_SCREEN.md §5.2 / §5.4). Pre-generated qapair payloads (`notification_type=qapair` with
    /// `response`) are stashed in `PendingPreGeneratedContentStore` so Chat can render them directly.
    func captureDeepLink(url: URL) {
        guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let kv = Dictionary(uniqueKeysWithValues: (comp.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") })
        captureDeepLinkKV(kv, source: "deeplink")
    }

    /// Shared parser used by both URL deep links and remote-notification payloads.
    /// Callers pass a lower-cased KV dict and a `source` label ("deeplink", "push", etc.)
    /// that flows into the chat entry source. Spec: SPLASH_SCREEN.md §5.2–§5.4.
    func captureDeepLinkKV(_ kv: [String: String], source: String) {
        let screen = (kv["navigation_screen"] ?? kv["screen"] ?? kv["nav"] ?? "").lowercased()
        let notificationType = (kv["notification_type"] ?? kv["notif_type"] ?? kv["target"] ?? "").lowercased()
        let chatId = (kv["chat_id"] ?? kv["chatid"]).flatMap { $0.isEmpty ? nil : $0 }
        let queryText = (kv["query"] ?? kv["question"] ?? kv["q"]).flatMap { $0.isEmpty ? nil : $0 }
        let response = (kv["response"] ?? kv["answer"] ?? kv["gcm_alert"] ?? kv["body"]).flatMap { $0.isEmpty ? nil : $0 }
        let actionRaw = (kv["action"] ?? kv["cta_action"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let followUps = collectFollowUps(from: kv)

        // §5.4 special case: qapair with pre-generated response stashes sidecar content.
        let qapairWithResponse = notificationType == "qapair" && (response?.isEmpty == false) && (queryText?.isEmpty == false)
        if qapairWithResponse, let q = queryText, let r = response {
            PendingPreGeneratedContentStore.shared.save(
                PendingPreGeneratedContent(question: q, response: r, followUps: followUps, source: source)
            )
        }

        // §5.2 row 4/5: `action`/`cta_action` starting with `enable_location` → GPS, regardless of screen.
        if let a = actionRaw, a.lowercased().hasPrefix("enable_location") {
            savePendingTarget(.gps(action: a))
            return
        }

        switch screen {
        case "home":
            savePendingTarget(.home)
        case "chat":
            if let id = chatId {
                savePendingTarget(.chat(chatId: id))
            } else if let q = queryText {
                savePendingTarget(.chatQuery(question: q, source: source))
            } else {
                savePendingTarget(.chatQuery(question: "", source: source))
            }
        case "gps", "location":
            savePendingTarget(.gps(action: buildGpsCampaignAction(from: kv, triggerSource: source) ?? "enable_location"))
        case "auth", "signup", "login", "account_benefits":
            if !isUserLoggedIn() {
                deferredDestination = .accountBenefits
            }
        case "settings":
            deferredDestination = .settings
        default:
            // §5.2 fallbacks: chatId > query (with matching notification_type) > Home.
            if let id = chatId {
                savePendingTarget(.chat(chatId: id))
            } else if let q = queryText, notificationType == "query" || notificationType == "qapair" {
                savePendingTarget(.chatQuery(question: q, source: source))
            } else {
                savePendingTarget(.home)
            }
        }
    }

    /// Collect `follow_up_question_1/2/3` (or `_0/_1/_2`), preserving order. Missing / empty dropped.
    private func collectFollowUps(from kv: [String: String]) -> [String] {
        var result: [String] = []
        for i in 0...3 {
            if let v = kv["follow_up_question_\(i)"], !v.isEmpty { result.append(v) }
        }
        return result
    }

    /// Apply payload from Plotline redirect or MoEngage push (KV). Uses navigation_screen, notification_type, query, response, follow_up_question_*, action. Source from kv["_source"] or "plotline". Ensures root is Home then navigates.
    func applyPayload(kv: [String: String]) {
        rootDestination = .home
        path = NavigationPath()

        let sourceKey = kv["_source"] ?? "plotline"
        let entrySource: ChatEntrySource = sourceKey == "moengage" ? .moengage : (sourceKey == "deeplink" ? .deeplink : .plotline)
        let screen = (kv["navigation_screen"] ?? kv["screen"] ?? "").lowercased()
        let notificationType = (kv["notification_type"] ?? "").lowercased()
        let queryText = kv["query"] ?? kv["question"] ?? kv["q"] ?? ""
        let response = kv["response"] ?? kv["answer"] ?? kv["gcm_alert"] ?? kv["body"] ?? ""
        let action = kv["action"] ?? kv["cta_action"] ?? ""
        let followUps = [1, 2, 3].compactMap { kv["follow_up_question_\($0)"] }.filter { !$0.isEmpty }

        switch screen {
        case "chat":
            if let id = kv["chat_id"], !id.isEmpty {
                path.append(AppDestination.chat(conversationId: id, entrySource: .history))
            } else if !queryText.isEmpty {
                if notificationType == "qapair", !response.isEmpty {
                    stashPreGeneratedContent(question: queryText, response: response, followUps: followUps, source: sourceKey)
                    path.append(AppDestination.chat(question: queryText, preGeneratedAnswer: response, followUpQuestions: followUps.isEmpty ? nil : followUps, entrySource: entrySource))
                } else {
                    path.append(AppDestination.chat(question: queryText, entrySource: entrySource))
                }
            } else {
                path.append(AppDestination.chat(question: nil, conversationId: nil, entrySource: entrySource))
            }
        case "home":
            popToHome()
        case "gps", "location":
            popToHome()
            setPendingGpsCampaign(action: buildGpsCampaignAction(from: kv, triggerSource: sourceKey), triggerSource: sourceKey)
        case "login", "auth", "signup", "account_benefits":
            if !isUserLoggedIn() {
                path.append(AppDestination.accountBenefits)
            }
        case "settings":
            navigateDrawerRoute(.settings)
        default:
            if !queryText.isEmpty {
                if notificationType == "qapair", !response.isEmpty {
                    stashPreGeneratedContent(question: queryText, response: response, followUps: followUps, source: sourceKey)
                    path.append(AppDestination.chat(question: queryText, preGeneratedAnswer: response, followUpQuestions: followUps.isEmpty ? nil : followUps, entrySource: entrySource))
                } else {
                    path.append(AppDestination.chat(question: queryText, entrySource: entrySource))
                }
            } else {
                popToHome()
            }
        }
    }

    /// Mirror of `PendingPreGeneratedContentStore.save` so the live payload path (applyPayload)
    /// matches the cold-start path (captureDeepLinkKV) — spec §5.4 says both branches stash.
    private func stashPreGeneratedContent(question: String, response: String, followUps: [String], source: String) {
        PendingPreGeneratedContentStore.shared.save(
            PendingPreGeneratedContent(question: question, response: response, followUps: followUps, source: source)
        )
    }

    /// Sign Up CTA gate (AUTH_FLOW.md §0.3 / §6.1). Calls `/api/images/v2/user_question_count/`
    /// and routes: `bypass_interstitial == true` → `.auth` directly; else → `.accountBenefits`.
    /// On error, mirrors Android `handleSignUpClick` (AppNavGraph.kt:138-148) by doing nothing.
    /// `viaDrawer == true` replaces the nav stack (drawer semantics); else pushes onto the current stack.
    @MainActor
    func performSignUpGate(viaDrawer: Bool, homeUseCase: HomeUseCase = HomeUseCase()) {
        Task {
            do {
                let response = try await homeUseCase.getUserQuestionCount()
                let bypass = response.bypass_interstitial ?? false
                let destination: AppDestination = bypass ? .auth : .accountBenefits
                if viaDrawer {
                    self.navigateDrawerRoute(destination)
                } else {
                    self.navigate(to: destination)
                }
            } catch {
                print("[Auth] user_question_count failed — staying on current screen: \(error)")
            }
        }
    }

    private func isUserLoggedIn() -> Bool {
        let uid = prefs.userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let token = prefs.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !uid.isEmpty || !token.isEmpty
    }

    private func buildGpsCampaignAction(from kv: [String: String], triggerSource: String) -> String? {
        var parts: [String] = []
        let keys = ["skip_why_location", "skip_interstitial", "min_interval_ms", "min_interval_seconds", "max_shows", "campaign_id", "id", "allow_retrigger", "force_retrigger"]
        for k in keys {
            if let v = kv[k], !v.isEmpty { parts.append("\(k)=\(v)") }
        }
        if !parts.isEmpty { parts.append("trigger_source=\(triggerSource)") }
        return parts.isEmpty ? nil : parts.joined(separator: "&")
    }
}
