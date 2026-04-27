//
//  RootView.swift
//  FarmerChat
//
//  Root: shows Splash / Language / Name / Home by rootDestination; handles error & legal sheets.
//

import SwiftUI
import Network

struct RootView: View {
    @State private var navigator = AppNavigator()
    @State private var errorManager = ErrorNavigationManager.shared

    /// Skip-retry tokens per ERROR_SCREEN.md §5. These are "pure navigation failures" —
    /// either no VM lambda was stored or the retry is done locally elsewhere.
    private static let skipRetryTokens: Set<String> = ["drawer", "chathistory", "home_weather", "home_card"]

    var body: some View {
        Group {
            switch navigator.rootDestination {

            case .splash:
                SplashView()
                    .environment(navigator)
            case .language:
                NavigationStack {
                    LanguageSelectionView()
                        .environment(navigator)
                }
            case .enterName:
                NavigationStack {
                    EnterNameView()
                        .environment(navigator)
                }
            case .home:
                HomeView()
                    .environment(navigator)
            case .accountBenefits:
                NavigationStack {
                    AccountBenefitsView()
                        .environment(navigator)
                }
            case .auth:
                NavigationStack {
                    AuthView()
                        .environment(navigator)
                }
            case .accountSuccess:
                NavigationStack {
                    AccountSuccessView()
                        .environment(navigator)
                }
            default:
                HomeView()
                    .environment(navigator)
            }
        }
        .overlay {
            if navigator.rootDestination == .home && navigator.showDrawer {
                AppDrawer(isPresented: Binding(
                    get: { navigator.showDrawer },
                    set: { navigator.showDrawer = $0 }
                ))
                .environment(navigator)
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: navigator.showDrawer)
        .sheet(item: Binding(get: { navigator.presentedSheet }, set: { navigator.presentedSheet = $0 })) { dest in
            sheetContent(dest)
        }
        .sheet(isPresented: Binding(
            get: { errorManager.currentError != nil },
            set: { if !$0 { errorManager.clear() } }
        )) {
            if let e = errorManager.currentError {
                ErrorView(
                    isNetworkError: e.isNetworkError,
                    fromScreen: e.fromScreen,
                    onTryAgain: { await handleTryAgain(e) }
                )
            }
        }
        .onOpenURL { url in
            navigator.captureDeepLink(url: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                navigator.captureDeepLink(url: url)
            }
        }
        .onAppear {
            // NotificationPayloadRouter.setNavigator(navigator)
        }
    }

    @ViewBuilder
    private func sheetContent(_ dest: AppDestination) -> some View {
        if case .legalContent(let url, let title) = dest {
            PolicyWebView(url: url, title: title, onDismiss: { navigator.presentedSheet = nil })
        }
    }

    /// ERROR_SCREEN.md §5 onTryAgain handler. Implements: offline-stays, skip-retry
    /// tokens, chathistory re-push, default pop+retry.
    private func handleTryAgain(_ event: ErrorEvent) async {
        if event.isNetworkError {
            let online = await Self.isCurrentlyOnline()
            if !online { return }
        }

        let token = (event.fromScreen ?? "")

        if token == "chathistory" {
            errorManager.clear()
            navigator.navigate(to: .chatHistory)
            return
        }

        if Self.skipRetryTokens.contains(token) {
            errorManager.clear()
            return
        }

        errorManager.clear()
        await event.retry()
    }

    /// One-shot NWPathMonitor probe. Matches the ad-hoc pattern used elsewhere in the
    /// app (AppDrawer, LocationPromptManager) — no centralized monitor exists yet.
    private static func isCurrentlyOnline() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                cont.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
        }
    }
}

// Allow binding to optional sheet from AppDestination
extension AppDestination: @retroactive Identifiable {
    public var id: String {
        switch self {
        case .splash: return "splash"
        case .language: return "language"
        case .enterName: return "enterName"
        case .home: return "home"
        case .chat(_, _, _, _, _, _, _, _, _): return "chat"
        case .chatHistory: return "chatHistory"
        case .settings: return "settings"
        case .settingsName: return "settingsName"
        case .settingsLanguage: return "settingsLanguage"
        case .help: return "help"
        case .accountBenefits: return "accountBenefits"
        case .auth: return "auth"
        case .accountSuccess: return "accountSuccess"
        case .error(let network, let from): return "error-\(network)-\(from ?? "")"
        case .legalContent(let url, let title): return "legal-\(url.absoluteString)-\(title)"
        }
    }
}
