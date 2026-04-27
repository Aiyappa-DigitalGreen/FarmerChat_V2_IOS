//
//  CountryCodePickerView.swift
//  FarmerChat
//
//  Country picker — matches UI_AUTH.md §4: neutral app bar, search inside scroll,
//  startsWith filter, RadioButton rows, 56pt save CTA.
//

import SwiftUI

struct CountryCodePickerView: View {
    let countries: [CountryItem]
    @Binding var selectedCountry: CountryItem
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var tempSelection: CountryItem

    init(countries: [CountryItem], selectedCountry: Binding<CountryItem>) {
        self.countries = countries
        _selectedCountry = selectedCountry
        _tempSelection = State(initialValue: selectedCountry.wrappedValue)
    }

    // UI_AUTH.md §4 — case-insensitive startsWith on name OR display_name/phone code.
    private var filteredCountries: [CountryItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return countries }
        let qLower = q.lowercased()
        return countries.filter { c in
            c.name.lowercased().hasPrefix(qLower)
            || c.phone_country_code.lowercased().hasPrefix(qLower)
            || c.code.lowercased().hasPrefix(qLower)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultAppBar(
                title: "Select country code",
                leftIcon: "chevron.left",
                onLeft: { dismiss() },
                background: ContentColors.surfacePrimary,
                foreground: ContentColors.foregroundPrimary
            )

            ScrollView {
                LazyVStack(spacing: 6) {
                    // Search input (scrolls with list per UI_AUTH.md §4).
                    SearchInput(text: $searchText, placeholder: "Search")
                        .padding(.bottom, 10)

                    ForEach(filteredCountries) { c in
                        SharedRadioButton(
                            label: "\(c.name) (\(c.phone_country_code))",
                            isSelected: tempSelection.id == c.id,
                            countryCode: c.code,
                            flagUrl: c.flag,
                            onTap: { tempSelection = c }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(ContentColors.surfacePrimary)

            // Bottom bar — 56pt PrimaryButton.
            PrimaryButton(
                label: "Save selection",
                height: 56,
                action: {
                    selectedCountry = tempSelection
                    dismiss()
                }
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .background(ContentColors.surfaceSecondary)
        }
        .background(ContentColors.surfacePrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Flag from URL or emoji fallback (reusable from AuthView)

struct CountryFlagView: View {
    let flagUrl: String
    let code: String

    private var url: URL? {
        let s = flagUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("http") else { return nil }
        return URL(string: s)
    }

    private var emojiFallback: String {
        let iso = code.uppercased()
        guard iso.count == 2 else { return "🌐" }
        let base: UInt32 = 0x1F1E6 - 65
        var scalars = String.UnicodeScalarView()
        for v in iso.unicodeScalars {
            guard let scalar = UnicodeScalar(base + v.value) else { continue }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Text(emojiFallback)
                            .font(.title2)
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.7)
                    @unknown default:
                        Text(emojiFallback)
                            .font(.title2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            } else {
                Text(emojiFallback)
                    .font(.title2)
            }
        }
    }
}
