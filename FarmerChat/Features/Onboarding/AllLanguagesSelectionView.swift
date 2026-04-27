//
//  AllLanguagesSelectionView.swift
//  FarmerChat
//
//  Full-screen language picker modal — matches Android SettingsAllLanguagesModal / AllLanguagesModal.
//  Tapping a row updates local modal state only; "Apply language" commits to the VM.
//  "Apply" is disabled until the user picks a language different from the current selection.
//

import SwiftUI

struct AllLanguagesSelectionView: View {
    let viewModel: LanguageSelectionViewModel
    var onSelect: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var modalSelectedId: String = ""

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: PreferencesManager.shared.label("fc_v2_app_label_all_languages", fallback: "All Languages"),
                leftIcon: "xmark",
                onLeft: { dismiss() }
            )

            let allLangs = viewModel.allLanguages
            if allLangs.isEmpty {
                LogoSpinner(type: .vertical, label: PreferencesManager.shared.label("fc_v2_app_label_loading_languages", fallback: "Loading languages..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(allLangs, id: \.id) { lang in
                            SharedRadioButton(
                                label: lang.display_name,
                                isSelected: modalSelectedId == String(lang.id),
                                background: ContentColors.surfacePrimary,
                                onTap: {
                                    modalSelectedId = String(lang.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }

            // Android parity: "Apply language" button — disabled until a new (different) selection is made.
            let hasNewSelection = !modalSelectedId.isEmpty && modalSelectedId != viewModel.selectedLanguageId
            VStack(spacing: 0) {
                PrimaryButton(
                    label: PreferencesManager.shared.label("fc_v2_app_label_apply_language", fallback: "Apply language"),
                    state: .default,
                    height: 56,
                    isEnabled: hasNewSelection,
                    action: {
                        viewModel.selectedLanguageId = modalSelectedId
                        onSelect()
                        dismiss()
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(ContentColors.surfaceSecondary)
        }
        .background(ContentColors.surfacePrimary)
        .onAppear {
            modalSelectedId = viewModel.selectedLanguageId
        }
    }
}
