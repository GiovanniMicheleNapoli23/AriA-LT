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

    /// Interlinea del testo: sul telefono le righe fitte si leggono male.
    private static let lineSpacing: CGFloat = 4

    var body: some View {
        let blocks = AriaMarkdown.blocks(text)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                view(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, index == 0 ? 0 : spacing(before: block, after: blocks[index - 1]))
            }
        }
        .textSelection(.enabled)
    }

    /// Più aria prima di un titolo (apre una sezione), meno tra paragrafi e elenchi della stessa sezione.
    private func spacing(before block: AriaMarkdown.Block, after previous: AriaMarkdown.Block) -> CGFloat {
        switch block {
        case .heading: 22
        case .rule: 16
        default: previous.isHeading ? 8 : 14
        }
    }

    @ViewBuilder
    private func view(for block: AriaMarkdown.Block) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(AriaMarkdown.inline(content))
                .font(.system(size: level == 1 ? 21 : level == 2 ? 19 : 17, weight: .semibold))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        case .paragraph(let content):
            Text(AriaMarkdown.inline(content))
                .font(font)
                .lineSpacing(Self.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        case .list(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    listItem(item)
                }
            }
        case .quote(let content):
            Text(AriaMarkdown.inline(content))
                .font(font)
                .lineSpacing(Self.lineSpacing)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color.liteAccent.opacity(0.35)).frame(width: 3)
                }
        case .code(let content):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(3)
                    .padding(12)
            }
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .table(let header, let rows):
            // Due colonne stanno nello schermo; di più, ogni riga diventa una scheda da leggere dall'alto in basso.
            if header.count <= 2 {
                AriaMarkdownTable(header: header, rows: rows)
            } else {
                AriaMarkdownRowCards(header: header, rows: rows)
            }
        case .rule:
            Divider()
        }
    }

    /// Pallino o numero allineato alla prima riga; il testo che va a capo resta sotto il testo, non sotto il segno.
    private func listItem(_ item: AriaMarkdown.ListItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if item.isNumbered {
                Text(item.marker)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.liteAccent.opacity(0.75))
                    .frame(minWidth: 16, alignment: .trailing)
            } else {
                Circle()
                    .fill(Color.primary.opacity(item.depth == 0 ? 0.55 : 0.3))
                    .frame(width: 5, height: 5)
                    .frame(width: 14, alignment: .center)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            }
            Text(AriaMarkdown.inline(item.text))
                .font(font)
                .lineSpacing(Self.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, CGFloat(item.depth) * 20)
    }
}

/// Tabella piccola (fino a due colonne): sta tutta nello schermo, righe separate da un filo.
private struct AriaMarkdownTable: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                    Text(AriaMarkdown.inline(cell))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider()
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(AriaMarkdown.inline(cell))
                            .font(.system(size: 15))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 9)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill).opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Tabella larga: una scheda per riga, la prima colonna come titolo e le altre come "intestazione: valore".
private struct AriaMarkdownRowCards: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(AriaMarkdown.inline(row.first ?? ""))
                        .font(.system(size: 15, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                        ForEach(Array(zip(header.dropFirst(), row.dropFirst()).enumerated()), id: \.offset) { _, pair in
                            if !pair.1.isEmpty {
                                GridRow {
                                    Text(AriaMarkdown.inline(pair.0))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                    Text(AriaMarkdown.inline(pair.1))
                                        .font(.system(size: 15))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.tertiarySystemFill).opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

enum AriaMarkdown {
    struct ListItem {
        let marker: String
        let text: String
        let depth: Int

        var isNumbered: Bool { marker.first?.isNumber == true }
    }

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case list([ListItem])
        case quote(String)
        case code(String)
        case table([String], [[String]])
        case rule

        var isHeading: Bool { if case .heading = self { true } else { false } }
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
            } else if paragraph.isEmpty, listItems.isEmpty || lines[i - 1].trimmingCharacters(in: .whitespaces).isEmpty,
                      let bold = trimmed.firstMatch(of: /^(?:\*\*|__)([^*_]+?)(?:\*\*|__)(:?)$/) {
                // Una riga tutta in grassetto ("**Cause probabili:**") è un titolo di sezione scritto male.
                flush()
                blocks.append(.heading(3, String(bold.1) + String(bold.2)))
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
