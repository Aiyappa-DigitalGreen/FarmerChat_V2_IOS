//
//  ChatHistoryView.swift
//  FarmerChat
//

import SwiftUI

struct ChatHistoryView: View {
    @Environment(AppNavigator.self) private var navigator
    @State private var viewModel = ChatHistoryViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // UI_CHAT_HISTORY.md §1 — neutral DefaultAppBar, menu left, no right slot.
            DefaultAppBar(
                title: PreferencesManager.shared.label("fc_v2_app_label_recent_chats", fallback: "Recent Chats"),
                leftIcon: "line.3.horizontal",
                onLeft: { navigator.showDrawer = true }
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ContentColors.surfacePrimary)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onAppear { ErrorNavigationManager.shared.setActiveScreen("chatHistory") }
    }

    @ViewBuilder
    private var content: some View {
        // §1 — initial loading path: full-screen vertical LogoSpinner, nothing else rendered.
        if viewModel.isInitialLoading {
            VStack {
                Spacer()
                LogoSpinner(type: .vertical, label: PreferencesManager.shared.label("fc_v2_app_label_loading_chats", fallback: "Loading chats..."))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.items.isEmpty {
            // Empty fallback (not in spec — initial-load errors navigate via
            // ErrorNavigationManager, so this only shows when the server returns [] cleanly).
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundStyle(ContentColors.foregroundSecondary)
                Text(PreferencesManager.shared.label("fc_v2_app_label_no_chats_yet", fallback: "No conversations yet"))
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(ContentColors.foregroundSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if viewModel.paginationError != nil {
                    paginationBanner
                }
                groupedList
            }
        }
    }

    // §5 — pagination error row: bodyMedium text + full-width 56pt PrimaryButton with chevron.
    // Copy is fixed ("Couldn't load more chats") per spec, not the server message.
    private var paginationBanner: some View {
        VStack(spacing: 12) {
            Text(PreferencesManager.shared.label("fc_v2_app_label_couldnt_load_more_chats", fallback: "Couldn't load more chats"))
                .font(AppTypography.bodyMedium())
                .foregroundStyle(ContentColors.foregroundSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            PrimaryButton(
                label: PreferencesManager.shared.label("fc_v2_app_label_try_again", fallback: "Try again"),
                state: .chevron,
                height: 56,
                icon: "chevron.right",
                iconPosition: .trailing
            ) {
                Task { await viewModel.loadNextPage() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var groupedList: some View {
        let sections = viewModel.sectionsFromApiGrouping
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    // §1 — section title (titleSmall/bold) with top 12 / bottom 8 padding.
                    Text(section.title)
                        .font(AppTypography.titleSmall())
                        .foregroundStyle(ContentColors.foregroundPrimary)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    ListCard {
                        ForEach(Array(section.items.enumerated()), id: \.offset) { idx, item in
                            ListItem(
                                label: item.displayTitle?.nonBlank ?? PreferencesManager.shared.label("fc_v2_app_label_new_conversation", fallback: "New conversation"),
                                icon: Self.messageTypeIcon(item.message_type),
                                showDivider: idx < section.items.count - 1,
                                action: {
                                    // AnalyticsManager.trackEvent(name: AnalyticsConstants.Event.newChatClickEvent, properties: [AnalyticsConstants.Property.screenName: AnalyticsConstants.Screen.chatHistoryScreen, AnalyticsConstants.Property.conversationId: item.displayId], adjustToken: AnalyticsConstants.AdjustToken.newChatClickEvent)
                                    navigator.navigate(to: .chat(conversationId: item.displayId))
                                }
                            )
                        }
                    }
                }

                // §4 — prefetch sentinel: fires next-page load as footer scrolls into view.
                if viewModel.canLoadMore && !viewModel.isLoadingMore && viewModel.paginationError == nil {
                    Color.clear
                        .frame(height: 1)
                        .onAppear { Task { await viewModel.loadNextPage() } }
                }
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        LogoSpinner(type: .horizontal, label: PreferencesManager.shared.label("fc_v2_app_label_loading_more", fallback: "Loading more..."))
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // §3 — map message_type → SF Symbol. Case-insensitive; unknown/nil falls back to generic card.
    private static func messageTypeIcon(_ type: String?) -> String {
        switch type?.lowercased() {
        case "image": return "camera.fill"
        case "audio", "voice": return "mic.fill"
        case "text": return "keyboard"
        default: return "bubble.left"
        }
    }
}

private extension String {
    var nonBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

/// UI_CHAT_HISTORY.md §7 — flat state model matching Android: items, isLoading, canLoadMore, paginationError.
/// Intentionally NOT using `Loadable`: refresh must not clear items (spec §1 initial-load path keys on
/// `items.isEmpty`, not on a transient loading union state), and a pagination failure leaves items visible.
@Observable
final class ChatHistoryViewModel {
    var items: [ConversationListItem] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var canLoadMore: Bool = true
    /// §5 — inline pagination banner (only when items already present).
    /// Initial-load failures route through `ErrorNavigationManager` → full-screen error.
    var paginationError: (message: String, isNetworkError: Bool)?
    private var currentPage = 1
    private let pageSize = 20
    private let getConversationListUseCase: GetConversationListUseCase

    /// §1 — full-screen loader path gate.
    var isInitialLoading: Bool { isLoading && items.isEmpty }

    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [ConversationListItem]
    }

    /// §2 — preserve first-occurrence section order and API item order within each section.
    /// Items missing `grouping` fall into an "Other" bucket rather than being dropped.
    var sectionsFromApiGrouping: [Section] {
        var order: [String] = []
        var buckets: [String: [ConversationListItem]] = [:]
        for item in items {
            let key = item.grouping ?? "Other"
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(item)
        }
        return order.map { Section(id: $0, title: $0, items: buckets[$0] ?? []) }
    }

    init(getConversationListUseCase: GetConversationListUseCase = GetConversationListUseCase()) {
        self.getConversationListUseCase = getConversationListUseCase
    }

    /// §5 — initial-load failure with no items → full-screen error via `ErrorNavigationManager`
    /// (retry closure re-enters `load()`). Failure with items already present → inline banner.
    /// On refresh, items stay visible until the new page 1 replaces them.
    func load() async {
        await MainActor.run {
            isLoading = true
            currentPage = 1
            canLoadMore = true
            paginationError = nil
        }
        do {
            let res = try await getConversationListUseCase.execute(page: 1)
            let list = res.getItems
            await MainActor.run {
                items = list
                canLoadMore = res.canLoadMore
                isLoading = false
            }
        } catch {
            let msg = error.localizedDescription
            let isNetwork = Self.classifyNetworkError(error)
            await MainActor.run {
                isLoading = false
                if items.isEmpty {
                    ErrorNavigationManager.shared.emit(
                        isNetworkError: isNetwork,
                        fromScreen: "chatHistory"
                    ) { [weak self] in
                        await self?.load()
                    }
                } else {
                    paginationError = (msg, isNetwork)
                }
            }
        }
    }

    /// §5 — pagination failures surface as the inline banner only. `currentPage` stays
    /// unchanged so Try-again re-requests the same page.
    func loadNextPage() async {
        guard canLoadMore, !isLoadingMore else { return }
        await MainActor.run {
            isLoadingMore = true
            paginationError = nil
        }
        let next = currentPage + 1
        do {
            let res = try await getConversationListUseCase.execute(page: next)
            let list = res.getItems
            await MainActor.run {
                currentPage = next
                items.append(contentsOf: list)
                canLoadMore = res.canLoadMore
                isLoadingMore = false
            }
        } catch {
            let msg = error.localizedDescription
            let isNetwork = Self.classifyNetworkError(error)
            await MainActor.run {
                isLoadingMore = false
                paginationError = (msg, isNetwork)
            }
        }
    }

    private static func classifyNetworkError(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let apiError = error as? APIError, case .network = apiError { return true }
        return false
    }
}
