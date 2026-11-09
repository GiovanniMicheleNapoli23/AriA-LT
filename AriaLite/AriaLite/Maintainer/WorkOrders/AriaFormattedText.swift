//
//  AriaFormattedText.swift
//  AriaLite
//
//  Created by Giovanni Michele on 16/10/26.
//
//  Descrizione e note di un ordine arrivano come testo libero, scritto a mano o da un gestionale: righe
//  a capo a caso, elenchi con "-", "•" o "1)", titoli in maiuscolo, "Etichetta: valore", paragrafi
//  lunghissimi. `AriaFormattedText` li legge e li divide in blocchi (titolo, paragrafo, elenco puntato,
//  elenco numerato, campi) che `AriaFormattedTextView` disegna fuori dalla procedura di risoluzione.
//  Per i passi della procedura c'è `AriaStepText`.
//

import Foundation
import NaturalLanguage
import SwiftUI

nonisolated enum AriaTextBlock: Equatable, Sendable {
    case heading(String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case fields([Field])

    struct Field: Equatable, Sendable {
        var label: String
        var value: String
    }
}

nonisolated enum AriaFormattedText {
    /// Un paragrafo più lungo di così, con almeno tre frasi, si divide in gruppi di frasi.
    static let longParagraph = 280
    private static let paragraphTarget = 200

    static func parse(_ text: String) -> [AriaTextBlock] {
        var blocks: [AriaTextBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var fields: [AriaTextBlock.Field] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(contentsOf: paragraphs(paragraph.joined(separator: "\n"))) }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)) }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)) }
            if !fields.isEmpty { blocks.append(.fields(fields)) }
            paragraph = []; bullets = []; numbered = []; fields = []
        }

        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }

            if let title = heading(line) {
                flush()
                blocks.append(.heading(title))
            } else if let item = bullet(line) {
                if bullets.isEmpty { flush() }
                bullets.append(item)
            } else if let item = numberedItem(line) {
                if numbered.isEmpty { flush() }
                numbered.append(item)
            } else if let field = field(line) {
                if fields.isEmpty { flush() }
                fields.append(field)
            } else if !bullets.isEmpty || !numbered.isEmpty, raw.first?.isWhitespace == true {
                // Una riga rientrata sotto una voce continua la voce, non apre un paragrafo.
                if !bullets.isEmpty { bullets[bullets.count - 1] += " " + line } else { numbered[numbered.count - 1] += " " + line }
            } else {
                if paragraph.isEmpty { flush() }
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    // MARK: Righe

    /// "## Titolo", "ROOT CAUSE", "Root cause:" da solo sulla riga.
    private static func heading(_ line: String) -> String? {
        if let match = line.firstMatch(of: /^#{1,6}\s+(.+?)\s*#*$/) { return strip(String(match.1)) }
        let bare = line.hasSuffix(":") ? String(line.dropLast()).trimmingCharacters(in: .whitespaces) : line
        guard bare.count >= 3, bare.count <= 60, !bare.contains(":"), !bare.hasSuffix(".") else { return nil }
        let letters = bare.filter(\.isLetter)
        let isUppercase = letters.count >= 3 && letters.allSatisfy(\.isUppercase)
        guard isUppercase || line.hasSuffix(":") else { return nil }
        return strip(bare)
    }

    private static func bullet(_ line: String) -> String? {
        line.firstMatch(of: /^[-*•–·▪‣]\s+(.+)$/).map { String($0.1) }
    }

    private static func numberedItem(_ line: String) -> String? {
        line.firstMatch(of: /^\d{1,2}[.)]\s+(.+)$/).map { String($0.1) }
    }

    /// "Asset: Motor 10B": etichetta breve (fino a 4 parole) e un valore. Due punti dentro un'ora ("10:30") non contano.
    private static func field(_ line: String) -> AriaTextBlock.Field? {
        guard let match = line.firstMatch(of: /^([\p{L}][\p{L}\s\/&()'’.-]{0,38}?)\s*:\s+(\S.*)$/) else { return nil }
        let label = strip(String(match.1))
        guard !label.isEmpty, label.split(separator: " ").count <= 4 else { return nil }
        return .init(label: label, value: String(match.2))
    }

    /// Via il grassetto Markdown da un titolo: lo stile ce l'ha già.
    private static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
    }

    // MARK: Paragrafi

    /// Un blocco di righe: ogni riga resta una riga (chi va a capo lo fa apposta), ma un'unica riga
    /// lunghissima si divide a gruppi di frasi.
    private static func paragraphs(_ text: String) -> [AriaTextBlock] {
        text.split(separator: "\n").flatMap { line -> [AriaTextBlock] in
            let line = String(line)
            guard line.count > longParagraph else { return [.paragraph(line)] }
            let sentences = AriaStepText.sentences(line)
            guard sentences.count >= 3 else { return [.paragraph(line)] }
            var groups: [String] = []
            for sentence in sentences {
                if let last = groups.last, last.count + sentence.count < paragraphTarget {
                    groups[groups.count - 1] = last + " " + sentence
                } else {
                    groups.append(sentence)
                }
            }
            return groups.map(AriaTextBlock.paragraph)
        }
    }
}

// MARK: - Vista

/// I blocchi di `AriaFormattedText`. Con `collapsible` il testo lungo si ferma a una sfumatura e si apre con "Show more".
struct AriaFormattedTextView: View {
    let text: String
    var collapsible = false

    @State private var expanded = false

    private static let collapsedHeight: CGFloat = 132

    private var blocks: [AriaTextBlock] { AriaFormattedText.parse(text) }

    private var isLong: Bool {
        collapsible && (text.count > 220 || blocks.count > 3)
    }

    var body: some View {
        let blocks = blocks
        VStack(alignment: .leading, spacing: 8) {
            let folded = isLong && !expanded
            content(blocks)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: folded ? Self.collapsedHeight : nil, alignment: .top)
                .clipped()
                .mask {
                    VStack(spacing: 0) {
                        Color.black
                        if folded {
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 28)
                        }
                    }
                }
                .textSelection(.enabled)
            if isLong {
                Button(expanded ? "Show less" : "Show more") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .font(.footnote.weight(.semibold))
                .tint(Color.liteAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func content(_ blocks: [AriaTextBlock]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                view(for: block)
                    .padding(.top, isHeading(block) && index > 0 ? 4 : 0)
            }
        }
    }

    private func isHeading(_ block: AriaTextBlock) -> Bool {
        if case .heading = block { true } else { false }
    }

    @ViewBuilder
    private func view(for block: AriaTextBlock) -> some View {
        switch block {
        case .heading(let title):
            Text(inline(title))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        case .paragraph(let body):
            Text(inline(body))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    row(marker: Text(verbatim: "•"), item)
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    row(marker: Text(verbatim: "\(index + 1).").monospacedDigit(), item)
                }
            }
        case .fields(let fields):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(field.label)
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .foregroundStyle(.tertiary)
                        Text(inline(field.value))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func row(marker: Text, _ item: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            marker
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent.opacity(0.6))
                .frame(minWidth: 14, alignment: .trailing)
            Text(inline(item))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// **grassetto**, _corsivo_ e `codice` dentro la riga; se il Markdown non si legge, il testo com'è.
    /// Niente link: il testo è dei lavori o del modello, e un link toccato aprirebbe qualsiasi schema.
    private func inline(_ text: String) -> AttributedString {
        var styled = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
        for run in styled.runs where run.link != nil { styled[run.range].link = nil }
        return styled
    }
}

#Preview {
    ScrollView {
        AriaFormattedTextView(text: """
        Motor protection switch on line 10B tripped twice during the night shift.

        SYMPTOMS
        - Motor stops after about 3 minutes
        - Burning smell near the cabinet
        * **Overload relay** trips

        Asset: Motor 10B
        Zone: Packaging line 2

        Actions:
        1) Isolate the circuit
        2) Check the overload setting
        """, collapsible: true)
        .padding()
    }
}
