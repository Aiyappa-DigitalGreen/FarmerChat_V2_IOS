//
//  TipsCarousel.swift
//  FarmerChat
//
//  Port of Android Tips.kt / Tip.kt — auto-advancing carousel of tip cards with
//  a progress-filled active indicator, shown at the bottom of the chat loading
//  state. Simplified from Android: no infinite virtual pager, no haptic tick —
//  a plain index cycle with a linear progress animation on the active dot.
//

import SwiftUI
import Foundation

struct TipData: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
}

// MARK: - Dynamic tips (Android ChatLoadingContent.kt port)

private let tipsLabelPrefix = "fc_v2_app_label_tips_"
private let titleSuffix = "_title"
private let statementSuffix = "_statement"

// Matches: fc_v2_app_label_tips_{name}_title_{lang}
private let titleKeyRegex = try! NSRegularExpression(
    pattern: "^\(NSRegularExpression.escapedPattern(for: tipsLabelPrefix))(.+)\(NSRegularExpression.escapedPattern(for: titleSuffix))_([a-z]{2,3})$"
)

private struct TipFallback {
    let titleKey: String; let titleDefault: String
    let statementKey: String; let statementDefault: String
}

private let fallbackTips: [TipFallback] = [
    TipFallback(
        titleKey: "fc_v2_app_label_tips_did_you_know", titleDefault: "Did you know?",
        statementKey: "fc_v2_app_label_tips_you_can_ask_followup_questions_to_get_more_details",
        statementDefault: "You can ask follow-up questions to get more details"
    ),
    TipFallback(
        titleKey: "fc_v2_app_label_tips_quick_tip", titleDefault: "Quick tip",
        statementKey: "fc_v2_app_label_tips_ask_specific_crops",
        statementDefault: "Try asking about specific crops or problems"
    ),
    TipFallback(
        titleKey: "fc_v2_app_label_tips_try_this", titleDefault: "Try this",
        statementKey: "fc_v2_app_label_tips_upload_photos_for_plant_disease_identification",
        statementDefault: "Upload photos for plant disease identification"
    ),
]

/// Port of Android `answerGenerationTips()` in ChatLoadingContent.kt.
/// Scans `LANGUAGE_LABELS` pref for keys matching the `fc_v2_app_label_tips_*` schema
/// (commit 2de8cca). Falls back to 3 hardcoded tips when no dynamic tips are found.
func answerGenerationTips() -> [TipData] {
    let prefs = PreferencesManager.shared
    let labels = prefs.languageLabels
    let langCode = (prefs.selectedLanguageCode ?? "en")
        .trimmingCharacters(in: .whitespaces).lowercased()
        .nonEmpty ?? "en"

    // Discover all unique tip names from label keys.
    var tipNames: [String] = []
    for key in labels.keys {
        let range = NSRange(key.startIndex..., in: key)
        if let match = titleKeyRegex.firstMatch(in: key, range: range),
           let nameRange = Range(match.range(at: 1), in: key) {
            let name = String(key[nameRange])
            if !tipNames.contains(name) { tipNames.append(name) }
        }
    }
    tipNames.sort()

    let dynamic: [TipData] = tipNames.compactMap { name in
        let titleBase  = "\(tipsLabelPrefix)\(name)\(titleSuffix)"
        let stmtBase   = "\(tipsLabelPrefix)\(name)\(statementSuffix)"
        guard let title = labels["\(titleBase)_\(langCode)"] ?? labels["\(titleBase)_en"],
              let body  = labels["\(stmtBase)_\(langCode)"]  ?? labels["\(stmtBase)_en"]
        else { return nil }
        return TipData(title: title, body: body)
    }

    if !dynamic.isEmpty { return dynamic }

    // Static fallbacks — key-resolved where possible, then English default.
    return fallbackTips.map { entry in
        let title = labels["\(entry.titleKey)_\(langCode)"]
            ?? labels["\(entry.titleKey)_en"]
            ?? entry.titleDefault
        let body  = labels["\(entry.statementKey)_\(langCode)"]
            ?? labels["\(entry.statementKey)_en"]
            ?? entry.statementDefault
        return TipData(title: title, body: body)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

struct TipsCarousel: View {
    let tips: [TipData]
    var showIcon: Bool = true

    private let slideDurationSeconds: Double = 8.0

    @State private var currentIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 14) {
            TabView(selection: $currentIndex) {
                ForEach(Array(tips.enumerated()), id: \.offset) { idx, tip in
                    TipCard(title: tip.title, bodyText: tip.body, showIcon: showIcon)
                        .tag(idx)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .allowsHitTesting(false)
            .frame(height: 90)

            TipPaginationIndicator(
                pageCount: tips.count,
                currentPage: currentIndex,
                progress: progress
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear { startCycle() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: currentIndex) { _, _ in restartProgress() }
    }

    private func startCycle() {
        restartProgress()
    }

    private func restartProgress() {
        timer?.invalidate()
        progress = 0
        withAnimation(.linear(duration: slideDurationSeconds)) {
            progress = 1
        }
        timer = Timer.scheduledTimer(withTimeInterval: slideDurationSeconds, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentIndex = (currentIndex + 1) % max(tips.count, 1)
            }
        }
    }
}

private struct TipCard: View {
    let title: String
    let bodyText: String
    let showIcon: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showIcon {
                ZStack {
                    Circle()
                        .fill(AppColors.green500)
                        .frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppTypography.labelLarge())
                    .foregroundStyle(ContentColors.foregroundPrimary)
                Text(bodyText)
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(ContentColors.foregroundPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ContentColors.surfaceActive)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TipPaginationIndicator: View {
    let pageCount: Int
    let currentPage: Int
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<pageCount, id: \.self) { idx in
                if idx == currentPage {
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.adaptiveFill)
                            .frame(width: 24, height: 6)
                        Capsule().fill(AppColors.green500)
                            .frame(width: 24 * progress, height: 6)
                    }
                    .frame(width: 24, height: 6)
                } else {
                    Circle()
                        .fill(AppColors.adaptiveFill)
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}
