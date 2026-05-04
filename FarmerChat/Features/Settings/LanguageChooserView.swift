//
//  LanguageChooserView.swift
//  FarmerChat
//
//  UI_SETTINGS.md §3 — DefaultAppBar with Menu, RadioButton list (5 preview +
//  "All Languages"), 56pt PrimaryButton "Save language" (Chevron/Loading),
//  "Language updated" toast on success.
//

import SwiftUI

private let languagePreviewLimit = 5

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
                title: "Choose your language",
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
        .navigationDestination(isPresented: $showAllLanguages) {
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
                ForEach(Array(langs.prefix(languagePreviewLimit)), id: \.id) { lang in
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
                if langs.count > languagePreviewLimit {
                    SecondaryButton(
                        label: "All Languages",
                        height: 54,
                        action: { showAllLanguages = true }
                    )
                    .padding(.top, 6)
                }
            }
        default:
            LogoSpinner(type: .vertical, label: "Loading languages...")
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
                label: viewModel.isSubmitting ? "Setting language" : "Save language",
                state: viewModel.isSubmitting ? .loading : .chevron,
                height: 56,
                isEnabled: canSubmit,
                action: {
                    Task {
                        await viewModel.submitAndNavigate(onSuccess: {
                            toastState = .success
                            toastMessage = "Language updated"
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
