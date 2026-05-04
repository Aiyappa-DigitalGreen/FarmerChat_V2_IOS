//
//  HelpView.swift
//  FarmerChat
//
//  UI_SETTINGS.md §5 — DefaultAppBar "Help" + Menu, ListCard with 5× FaqSkeletonRow
//  shimmer placeholder while loading, then FAQ ListItems; More section with
//  Terms/Privacy; centered caption footer with app version + © Digital Green.
//  Link-unavailable → Toast. SFSafariViewController (PolicyWebView) for URLs.
//

import SwiftUI

struct HelpView: View {
    @Environment(AppNavigator.self) private var navigator
    @State private var faqs: [FaqItem] = []
    @State private var legalLinks: [(title: String, url: String)] = []
    @State private var loading = true
    @State private var presentedLegal: LegalSheetItem?
    @State private var presentedFaqUrl: LegalSheetItem?
    @State private var presentedFaqHtml: FaqHtmlItem?
    @State private var toastMessage: String? = nil
    @State private var toastState: ToastState = .error

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: PreferencesManager.shared.label("fc_v2_app_label_help", fallback: "Help"),
                leftIcon: "line.3.horizontal",
                onLeft: { navigator.showDrawer = true }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    howToUseSection
                    moreSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }
            .background(ContentColors.surfacePrimary)
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toastHost(message: $toastMessage, state: $toastState)
        .sheet(item: $presentedLegal) { item in
            PolicyWebView(url: item.url, title: item.title) { presentedLegal = nil }
        }
        .sheet(item: $presentedFaqUrl) { item in
            PolicyWebView(url: item.url, title: item.title) { presentedFaqUrl = nil }
        }
        .sheet(item: $presentedFaqHtml) { item in
            PolicyWebView(htmlContent: item.html, title: item.title) { presentedFaqHtml = nil }
        }
        .onAppear {
            // AnalyticsManager.trackScreenView(screenName: AnalyticsConstants.Screen.helpAndSupportScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenViewed, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.helpAndSupportScreen], adjustToken: AnalyticsConstants.AdjustToken.screenViewed)
        }
        .onDisappear {
            // AnalyticsManager.trackScreenExit(screenName: AnalyticsConstants.Screen.helpAndSupportScreen)
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.screenExited, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.helpAndSupportScreen], adjustToken: AnalyticsConstants.AdjustToken.screenExited)
        }
        .task { await load() }
    }

    // MARK: - Sections

    private var howToUseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PreferencesManager.shared.label("fc_v2_app_label_how_to_use_farmerchat", fallback: "How to use FarmerChat"))
                .font(AppTypography.labelLarge())
                .foregroundStyle(ContentColors.foregroundPrimary)

            ListCard {
                if loading {
                    ForEach(0..<5, id: \.self) { idx in
                        FaqSkeletonRow(showDivider: idx < 4)
                    }
                } else if faqs.isEmpty {
                    ListItem(
                        label: PreferencesManager.shared.label("fc_v2_app_label_no_faqs_available", fallback: "No FAQs available"),
                        showChevron: false,
                        showDivider: false,
                        action: {}
                    )
                } else {
                    ForEach(Array(faqs.enumerated()), id: \.offset) { idx, faq in
                        ListItem(
                            label: faq.title ?? faq.question ?? "FAQ",
                            showChevron: true,
                            showDivider: idx < faqs.count - 1,
                            action: { openFaq(faq) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var moreSection: some View {
        if !legalLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(PreferencesManager.shared.label("fc_v2_app_label_more", fallback: "More"))
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(ContentColors.foregroundPrimary)

                ListCard {
                    ForEach(Array(legalLinks.enumerated()), id: \.offset) { idx, link in
                        ListItem(
                            label: link.title,
                            showChevron: true,
                            showDivider: idx < legalLinks.count - 1,
                            action: { openLegal(link) }
                        )
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("FarmerChat v.\(appVersion)")
                .font(AppTypography.caption())
                .foregroundStyle(ContentColors.foregroundSecondary)
                .multilineTextAlignment(.center)
            Text("© Digital Green")
                .font(AppTypography.caption())
                .foregroundStyle(ContentColors.foregroundSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func openFaq(_ faq: FaqItem) {
        let title = faq.title ?? faq.question ?? "FAQ"
        // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.faqClicked, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.helpAndSupportScreenAlt, AnalyticsConstants.Property.question: title, AnalyticsConstants.Property.id: faq.id ?? ""], adjustToken: AnalyticsConstants.AdjustToken.faqClicked)
        if let urlString = faq.webview_url, !urlString.isEmpty, let url = URL(string: urlString) {
            presentedFaqUrl = LegalSheetItem(title: title, url: url)
        } else if let answer = faq.answer, !answer.isEmpty {
            presentedFaqHtml = FaqHtmlItem(title: title, html: answer)
        } else {
            toastState = .error
            toastMessage = PreferencesManager.shared.label("fc_v2_app_label_link_unavailable", fallback: "Link unavailable")
        }
    }

    private func openLegal(_ link: (title: String, url: String)) {
        guard !link.url.isEmpty, let url = URL(string: link.url) else {
            toastState = .error
            toastMessage = PreferencesManager.shared.label("fc_v2_app_label_link_unavailable", fallback: "Link unavailable")
            return
        }
        if link.title.lowercased().contains("privacy") {
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.privacyPolicyOpened, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.helpAndSupportScreenAlt], adjustToken: AnalyticsConstants.AdjustToken.privacyPolicyOpened)
        } else if link.title.lowercased().contains("terms") {
            // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.termsOfUseOpened, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.helpAndSupportScreenAlt], adjustToken: AnalyticsConstants.AdjustToken.termsOfUseOpened)
        }
        presentedLegal = LegalSheetItem(title: link.title, url: url)
    }

    // MARK: - Network

    private func load() async {
        do {
            let res = try await GetHelpSupportUseCase().execute(limit: 5)
            await MainActor.run {
                faqs = res.faqs
                var links: [(title: String, url: String)] = []
                let prefs = PreferencesManager.shared
                if let u = res.legalResolved?.terms_of_use?.webview_url { links.append((prefs.label("fc_v2_app_label_terms_of_use", fallback: "Terms of use"), u)) }
                if let u = res.legalResolved?.privacy_policy?.webview_url { links.append((prefs.label("fc_v2_app_label_privacy_policy", fallback: "Privacy policy"), u)) }
                legalLinks = links
                loading = false
            }
        } catch {
            await MainActor.run {
                loading = false
                toastState = .error
                toastMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - FaqSkeletonRow (UI_SETTINGS.md §5)

private struct FaqSkeletonRow: View {
    let showDivider: Bool
    @State private var phase: CGFloat = 0.35

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(ContentColors.borderDefault)
                    .opacity(phase)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(ContentColors.borderDefault)
                    .opacity(phase)
                    .frame(width: 24, height: 14)
            }
            .frame(height: 48)

            if showDivider {
                Rectangle()
                    .fill(ContentColors.borderDefault.opacity(0.35))
                    .frame(height: 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                phase = 0.75
            }
        }
    }
}

// MARK: - Sheet items

private struct LegalSheetItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

private struct FaqHtmlItem: Identifiable {
    let id = UUID()
    let title: String
    let html: String
}
