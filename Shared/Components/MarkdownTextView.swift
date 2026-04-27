//
//  MarkdownTextView.swift
//  FarmerChat
//
//  Custom ~250-line markdown renderer matching Android MarkdownText composable.
//  Parses: # headers, **bold**, *italic*, bullet/numbered lists, --- dividers.
//  No external libraries — uses AttributedString for inline and VStack for blocks.
//

import SwiftUI

// MARK: - Block model

private enum MarkdownBlock {
    case header(level: Int, text: String)
    case paragraph(text: String)
    case bullet(text: String, nested: Bool)
    case numbered(number: Int, text: String)
    case divider
}

// MARK: - Parser

private func parseBlocks(_ raw: String) -> [MarkdownBlock] {
    let lines = raw.components(separatedBy: "\n")
    var blocks: [MarkdownBlock] = []
    let numberedRegex = try? NSRegularExpression(pattern: #"^(\d+)\.\s+(.*)"#)

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }

        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            blocks.append(.divider)
            continue
        }
        if trimmed.hasPrefix("### ") {
            blocks.append(.header(level: 3, text: String(trimmed.dropFirst(4))))
            continue
        }
        if trimmed.hasPrefix("## ") {
            blocks.append(.header(level: 2, text: String(trimmed.dropFirst(3))))
            continue
        }
        if trimmed.hasPrefix("# ") {
            blocks.append(.header(level: 1, text: String(trimmed.dropFirst(2))))
            continue
        }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            let text = String(trimmed.dropFirst(2))
            blocks.append(.bullet(text: text, nested: leadingSpaces >= 2))
            continue
        }
        if let regex = numberedRegex {
            let nsLine = trimmed as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if let match = regex.firstMatch(in: trimmed, range: range) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                let text = nsLine.substring(with: match.range(at: 2))
                blocks.append(.numbered(number: Int(numStr) ?? 1, text: String(text)))
                continue
            }
        }
        blocks.append(.paragraph(text: trimmed))
    }
    return blocks
}

// MARK: - Inline formatting (**bold** and *italic*)

private func formatInline(_ text: String, baseFont: UIFont, color: Color) -> AttributedString {
    var result = AttributedString()
    let chars = Array(text)
    let count = chars.count
    var i = 0

    let baseSwiftFont = Font(baseFont)
    let boldFont = Font(UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold))
    let italicFont = Font(UIFont.italicSystemFont(ofSize: baseFont.pointSize))

    while i < count {
        if i + 1 < count && chars[i] == "*" && chars[i + 1] == "*" {
            if let end = findClosing(chars: chars, from: i + 2, marker: "**") {
                let inner = String(chars[(i + 2)..<end])
                var seg = AttributedString(inner)
                seg.font = boldFont
                seg.foregroundColor = color
                result.append(seg)
                i = end + 2
                continue
            }
        }
        if chars[i] == "*" && (i + 1 >= count || chars[i + 1] != "*") {
            if let end = findClosingSingle(chars: chars, from: i + 1) {
                let inner = String(chars[(i + 1)..<end])
                var seg = AttributedString(inner)
                seg.font = italicFont
                seg.foregroundColor = color
                result.append(seg)
                i = end + 1
                continue
            }
        }
        var plain = ""
        while i < count {
            if chars[i] == "*" { break }
            plain.append(chars[i])
            i += 1
        }
        if !plain.isEmpty {
            var seg = AttributedString(plain)
            seg.font = baseSwiftFont
            seg.foregroundColor = color
            result.append(seg)
        }
    }
    return result
}

private func findClosing(chars: [Character], from start: Int, marker: String) -> Int? {
    let markerChars = Array(marker)
    let len = markerChars.count
    var i = start
    while i + len - 1 < chars.count {
        if Array(chars[i..<(i + len)]) == markerChars { return i }
        i += 1
    }
    return nil
}

private func findClosingSingle(chars: [Character], from start: Int) -> Int? {
    var i = start
    while i < chars.count {
        if chars[i] == "*" {
            if i + 1 < chars.count && chars[i + 1] == "*" {
                i += 2
                continue
            }
            return i
        }
        i += 1
    }
    return nil
}

// MARK: - Spacing logic

private func spacingBefore(current: MarkdownBlock, previous: MarkdownBlock?) -> CGFloat {
    guard let prev = previous else { return 0 }
    switch current {
    case .divider: return 24
    case .header: return 24
    default: break
    }
    switch prev {
    case .divider: return 24
    case .header: return 20
    default: break
    }
    if isBullet(current) && isBullet(prev) { return 5 }
    if isNumbered(current) && isNumbered(prev) { return 5 }
    return 12
}

private func isBullet(_ b: MarkdownBlock) -> Bool {
    if case .bullet = b { return true }
    return false
}

private func isNumbered(_ b: MarkdownBlock) -> Bool {
    if case .numbered = b { return true }
    return false
}

// MARK: - View

struct MarkdownTextView: View {
    let text: String
    var textColor: Color = AppColors.adaptiveLabel

    private var blocks: [MarkdownBlock] { parseBlocks(text) }

    var body: some View {
        let parsed = blocks
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parsed.enumerated()), id: \.offset) { idx, block in
                let prev: MarkdownBlock? = idx > 0 ? parsed[idx - 1] : nil
                let spacing = spacingBefore(current: block, previous: prev)

                blockView(block)
                    .padding(.top, spacing)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .header(let level, let text):
            headerView(level: level, text: text)

        case .paragraph(let text):
            Text(formatInline(text, baseFont: bodyFont, color: textColor))
                .lineSpacing(4)

        case .bullet(let text, let nested):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(textColor)
                    .frame(width: 5, height: 5)
                Text(formatInline(text, baseFont: bodyFont, color: textColor))
                    .lineSpacing(4)
            }
            .padding(.leading, nested ? 36 : 20)

        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(number).")
                    .font(Font(bodyFont))
                    .foregroundStyle(textColor)
                Text(formatInline(text, baseFont: bodyFont, color: textColor))
                    .lineSpacing(4)
            }
            .padding(.leading, 20)

        case .divider:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppColors.adaptiveSeparator)
                .frame(height: 3)
        }
    }

    private func headerView(level: Int, text: String) -> some View {
        let font: UIFont
        switch level {
        case 1: font = .systemFont(ofSize: 22, weight: .bold)
        case 2: font = .systemFont(ofSize: 18, weight: .bold)
        default: font = .systemFont(ofSize: 16, weight: .bold)
        }
        return Text(formatInline(text, baseFont: font, color: textColor))
            .tracking(level == 2 ? 0.5 : 0)
            .lineSpacing(4)
    }

    private var bodyFont: UIFont {
        .systemFont(ofSize: 17, weight: .regular)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ScrollView {
        MarkdownTextView(text: """
        # Welcome to FarmerChat

        ## Growing Tips

        Here is some **bold text** and *italic text* mixed together.

        ### Bullet List

        - First item
        - Second item with **bold**
          - Nested item
        - Third item

        ---

        ### Numbered List

        1. Plant the seeds
        2. Water **regularly**
        3. Harvest after *6 weeks*

        Plain paragraph at the end.
        """)
        .padding()
    }
}
#endif
