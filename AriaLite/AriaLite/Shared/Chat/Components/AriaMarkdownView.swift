//
//  AriaMarkdownView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Markdown delle risposte di Aria: titoli, elenchi, tabelle, codice, citazioni.
//  Il testo in linea (grassetto, corsivo, codice, link) usa AttributedString.
//  I link relativi (/work-orders/12) si aprono sulla web app.
//

import SwiftUI

struct AriaMarkdownView: View {
    let text: String
    /// Font del testo; senza, .callout (16 pt) che segue il Dynamic Type.
    var font: Font? = nil

    // H1 e H2 stanno tra gli stili di testo (21 e 19 pt): misure scalate, crescono con il Dynamic Type.
    @ScaledMetric(relativeTo: .title3) private var h1Size: CGFloat = 21
    @ScaledMetric(relativeTo: .title3) private var h2Size: CGFloat = 19

    private var bodyFont: Font { font ?? .callout }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: h1Size, weight: .semibold)
        case 2: .system(size: h2Size, weight: .semibold)
        default: .headline
        }
    }

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
                .font(headingFont(level))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        case .paragraph(let content):
            Text(AriaMarkdown.inline(content))
                .font(bodyFont)
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
                .font(bodyFont)
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
                    .font(.system(.footnote, design: .monospaced))
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
                    .font(.subheadline.weight(.semibold).monospacedDigit())
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
                .font(bodyFont)
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
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider()
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(AriaMarkdown.inline(cell))
                            .font(.subheadline)
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
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                        ForEach(Array(zip(header.dropFirst(), row.dropFirst()).enumerated()), id: \.offset) { _, pair in
                            if !pair.1.isEmpty {
                                GridRow {
                                    Text(AriaMarkdown.inline(pair.0))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(AriaMarkdown.inline(pair.1))
                                        .font(.subheadline)
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

// MARK: - Link verso la web app

/// Apre i link relativi del backend (es. /work-orders/12) sulla web app. Passano solo gli schemi di
/// `AriaURLPolicy`: la risposta del modello può contenere qualsiasi link.
struct AriaLinkHandler: ViewModifier {
    let webBase: URL
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.environment(\.openURL, OpenURLAction { url in
            if url.scheme == nil {
                guard let absolute = URL(string: url.relativeString, relativeTo: webBase)?.absoluteURL,
                      let safe = AriaURLPolicy.external(absolute) else { return .discarded }
                openURL(safe)
                return .handled
            }
            return AriaURLPolicy.external(url) == nil ? .discarded : .systemAction
        })
    }
}

extension View {
    func ariaLinks(_ webBase: URL) -> some View { modifier(AriaLinkHandler(webBase: webBase)) }
}
