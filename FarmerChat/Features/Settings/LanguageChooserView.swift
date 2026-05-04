//
//  LanguageChooserView.swift
//  FarmerChat
//
//  UI_SETTINGS.md §3 — DefaultAppBar with Menu, RadioButton list (5 preview +
//  "All Languages"), 56pt PrimaryButton "Save language" (Chevron/Loading),
//  "Language updated" toast on success.
//

import SwiftUI

struct LanguageChooserView: View {
    @Environment(AppNavigator.self) private var navigator
    @State private var viewModel: LanguageSelectionViewModel
    @State private var showAllLanguages = false
    @State private var userMadeSelection = false
    @State private var toastMessage: String? = nil
    @State private var toastState: ToastState = .success

    init() {
        _viewModel = State(initialValue: LanguageSelectionViewModel(apiClient: APIClient(), prefs: .shared))
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: PreferencesManager.shared.label("fc_v2_app_label_choose_your_language", fallback: "Choose your language"),
                leftIcon: "line.3.horizontal",
                onLeft: { navigator.showDrawer = true }
            )

            ScrollView {
                contentArea
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 20)
            }
            .background(ContentColors.surfacePrimary)

            bottomBar
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showAllLanguages) {
            AllLanguagesSelectionView(viewModel: viewModel, onSelect: {
                userMadeSelection = true
            })
        }
        .toastHost(message: $toastMessage, state: $toastState)
        .task { await viewModel.loadLanguages() }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.languageState {
        case .success(let langs):
            LazyVStack(spacing: 6) {
                ForEach(langs, id: \.id) { lang in
                    SharedRadioButton(
                        label: lang.display_name,
                        isSelected: viewModel.selectedLanguageId == String(lang.id),
                        background: ContentColors.surfacePrimary,
                        onTap: {
                            viewModel.selectedLanguageId = String(lang.id)
                            userMadeSelection = true
                        }
                    )
                }
                if !viewModel.expandedLanguages.isEmpty {
                    SecondaryButton(
                        label: PreferencesManager.shared.label("fc_v2_app_label_all_languages", fallback: "All Languages"),
                        height: 54,
                        action: { showAllLanguages = true }
                    )
                    .padding(.top, 6)
                }
            }
        default:
            LogoSpinner(type: .vertical, label: PreferencesManager.shared.label("fc_v2_app_label_loading_languages", fallback: "Loading languages..."), continuous: true)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            let canSubmit = userMadeSelection
                && !viewModel.selectedLanguageId.isEmpty
                && !viewModel.isSubmitting
            PrimaryButton(
                label: viewModel.isSubmitting ? PreferencesManager.shared.label("fc_v2_app_label_setting_language", fallback: "Setting language") : PreferencesManager.shared.label("fc_v2_app_label_save_language", fallback: "Save language"),
                state: viewModel.isSubmitting ? .loading : .chevron,
                height: 56,
                isEnabled: canSubmit,
                action: {
                    Task {
                        await viewModel.submitAndNavigate(onSuccess: {
                            toastState = .success
                            toastMessage = PreferencesManager.shared.label("fc_v2_app_label_language_updated", fallback: "Language updated")
                            Task {
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                await MainActor.run { navigator.popToHome() }
                            }
                        })
                    }
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(ContentColors.surfaceSecondary)
    }
}
