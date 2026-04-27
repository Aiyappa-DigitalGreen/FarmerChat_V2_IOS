//
//  AllLanguagesSelectionView.swift
//  FarmerChat
//
//  UI_LANGUAGE.md §5 — full language list. DefaultAppBar with back arrow (no glow),
//  RadioButton rows, 20pt horizontal / 24pt vertical padding, 6pt spacing.
//  Tapping a language commits selection and pops back.
//

import SwiftUI

struct AllLanguagesSelectionView: View {
    let viewModel: LanguageSelectionViewModel
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: "Choose your language",
                leftIcon: "chevron.left",
                onLeft: { dismiss() }
            )

            Group {
                switch viewModel.languageState {
                case .success(let langs):
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(langs, id: \.id) { lang in
                                SharedRadioButton(
                                    label: lang.display_name,
                                    isSelected: viewModel.selectedLanguageId == String(lang.id),
                                    background: ContentColors.surfacePrimary,
                                    onTap: {
                                        viewModel.selectedLanguageId = String(lang.id)
                                        onSelect()
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                default:
                    LogoSpinner(type: .vertical, label: "Loading languages...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
