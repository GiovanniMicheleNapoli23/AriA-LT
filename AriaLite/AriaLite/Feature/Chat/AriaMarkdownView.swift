//
//  AriaMarkdownView.swift
//  AriaLite
//
//  Markdown delle risposte di Aria: titoli, elenchi, tabelle, codice, citazioni.
//  Il testo in linea (grassetto, corsivo, codice, link) usa AttributedString.
//  I link relativi (/work-orders/12) si aprono sulla web app.
//

import SwiftUI

struct AriaMarkdownView: View {
    let text: String
    var font: Font = .system(size: 16)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(AriaMarkdown.blocks(text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: AriaMarkdown.Block) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(AriaMarkdown.inline(content))
                .font(.system(size: level == 1 ? 20 : level == 2 ? 18 : 16, weight: .semibold))
        case .paragraph(let content):
            Text(AriaMarkdown.inline(content)).font(font)
        case .list(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(item.marker)
                            .font(font.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(AriaMarkdown.inline(item.text)).font(font)
                    }
                    .padding(.leading, CGFloat(item.depth) * 16)
                }
            }
        case .quote(let content):
            Text(AriaMarkdown.inline(content))
                .font(font)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color.liteAccent.opacity(0.35)).frame(width: 3)
                }
        case .code(let content):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
            }
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        case .table(let header, let rows):
            AriaMarkdownTable(header: header, rows: rows)
        case .rule:
            Divider()
        }
    }
}

private struct AriaMarkdownTable: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(AriaMarkdown.inline(cell)).font(.system(size: 13, weight: .semibold))
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(AriaMarkdown.inline(cell)).font(.system(size: 13))
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color(.tertiarySystemFill).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }
}

enum AriaMarkdown {
    struct ListItem {
        let marker: String
        let text: String
        let depth: Int
    }

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case list([ListItem])
        case quote(String)
        case code(String)
        case table([String], [[String]])
        case rule
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    static func blocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var listItems: [ListItem] = []
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph = []
        }
        func flushList() {
            if !listItems.isEmpty { blocks.append(.list(listItems)) }
            listItems = []
        }
        func flush() { flushParagraph(); flushList() }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Codice
            if trimmed.hasPrefix("```") {
                flush()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.code(code.joined(separator: "\n")))
                i += 1
                continue
            }

            if trimmed.isEmpty {
                flush()
                i += 1
                continue
            }

            // Tabella GFM: riga di intestazione + riga di separazione
            if trimmed.hasPrefix("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flush()
                let header = cells(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    var row = cells(lines[i])
                    row += Array(repeating: "", count: max(0, header.count - row.count))
                    rows.append(Array(row.prefix(header.count)))
                    i += 1
                }
                blocks.append(.table(header, rows))
                continue
            }

            if let heading = trimmed.firstMatch(of: /^(#{1,6})\s+(.*)$/) {
                flush()
                blocks.append(.heading(heading.1.count, String(heading.2)))
            } else if trimmed.firstMatch(of: /^(-{3,}|\*{3,}|_{3,})$/) != nil {
                flush()
                blocks.append(.rule)
            } else if trimmed.hasPrefix(">") {
                flush()
                blocks.append(.quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else if let item = line.firstMatch(of: /^(\s*)([-*+]|\d{1,3}[.)])\s+(.*)$/) {
                flushParagraph()
                let depth = item.1.count / 2
                let marker = item.2.first?.isNumber == true ? String(item.2) : "•"
                listItems.append(ListItem(marker: marker, text: String(item.3), depth: min(depth, 3)))
            } else if !listItems.isEmpty, line.first?.isWhitespace == true {
                // Riga di continuazione dell'ultimo punto
                let last = listItems.removeLast()
                listItems.append(ListItem(marker: last.marker, text: last.text + " " + trimmed, depth: last.depth))
            } else {
                flushList()
                paragraph.append(line)
            }
            i += 1
        }
        flush()
        return blocks
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.allSatisfy { "|-: ".contains($0) } && t.contains("-")
    }

    private static func cells(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - Link verso la web app

/// Apre i link relativi del backend (es. /work-orders/12) sulla web app; gli altri come sempre.
struct AriaLinkHandler: ViewModifier {
    let webBase: URL
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.environment(\.openURL, OpenURLAction { url in
            if url.scheme == nil, let absolute = URL(string: url.relativeString, relativeTo: webBase)?.absoluteURL {
                openURL(absolute)
                return .handled
            }
            return .systemAction
        })
    }
}

extension View {
    func ariaLinks(_ webBase: URL) -> some View { modifier(AriaLinkHandler(webBase: webBase)) }
}
