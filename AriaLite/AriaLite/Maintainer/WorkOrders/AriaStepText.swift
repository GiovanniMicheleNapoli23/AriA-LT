//
//  AriaStepText.swift
//  AriaLite
//
//  Created by Giovanni Michele on 16/10/26.
//
//  Il testo di un passo diviso per leggerlo sul telefono, invece di un unico blocco in grassetto:
//
//  • un'etichetta in testa scritta in maiuscolo ("SAFETY FIRST: …") diventa una pastiglia;
//  • la prima frase è l'azione e resta in evidenza;
//  • un elenco dopo i due punti ("signs of overheating: a, b, c, or d") diventa un elenco puntato;
//  • le frasi successive sono le indicazioni che seguono, in corpo normale.
//
//  Le frasi si dividono con NLTokenizer, che conosce le abbreviazioni ("e.g.", "ecc.") meglio di una regex.
//

import Foundation
import NaturalLanguage

nonisolated struct AriaStepText: Equatable, Sendable {
    /// L'etichetta in maiuscolo davanti al passo, senza i due punti.
    var tag: String?
    var headline: String
    /// L'elenco della prima frase, se ne ha uno.
    var items: [String]
    /// Le frasi dopo la prima.
    var notes: [String]

    init(tag: String? = nil, headline: String, items: [String] = [], notes: [String] = []) {
        self.tag = tag
        self.headline = headline
        self.items = items
        self.notes = notes
    }

    init(_ text: String) {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tag: String?
        if let match = body.firstMatch(of: /^(\p{Lu}[\p{Lu}\s]+\p{Lu})\s*[:!]\s+/) {
            tag = String(match.1)
            body = String(body[match.range.upperBound...])
        }
        let sentences = Self.sentences(body)
        let first = sentences.first ?? body
        if let (intro, list) = Self.list(in: first) {
            self.init(tag: tag, headline: intro, items: list, notes: Array(sentences.dropFirst()))
        } else {
            self.init(tag: tag, headline: first, notes: Array(sentences.dropFirst()))
        }
    }

    /// Un avviso di sicurezza: la pastiglia è arancione, come la scheda di sicurezza dell'ordine.
    var isSafetyTag: Bool {
        guard let tag = tag?.lowercased() else { return false }
        return ["safety", "sicurezza", "warning", "attenzione", "danger", "pericolo", "caution", "loto"]
            .contains { tag.contains($0) }
    }

    static func sentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { out.append(sentence) }
            return true
        }
        return out.isEmpty ? [text] : out
    }

    /// "…signs of overheating: a, b, c, or d." → ("…signs of overheating:", [A, B, C, D]).
    /// Solo con almeno 3 voci brevi: una frase con una virgola qualunque dopo i due punti resta com'è.
    static func list(in sentence: String) -> (String, [String])? {
        guard let colon = sentence.firstIndex(of: ":") else { return nil }
        let intro = sentence[..<colon].trimmingCharacters(in: .whitespaces)
        var rest = sentence[sentence.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        if rest.hasSuffix(".") || rest.hasSuffix(";") { rest.removeLast() }
        let parts = rest.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !intro.isEmpty, parts.count >= 3 else { return nil }
        let items = parts.enumerated().map { i, part in
            let item = i == parts.count - 1
                ? part.replacing(/^(?:or|and|oppure|o|ed|e)\s+/.ignoresCase(), with: "")
                : part
            return item.prefix(1).uppercased() + item.dropFirst()
        }
        guard items.allSatisfy({ !$0.isEmpty && $0.count <= 60 }) else { return nil }
        return ("\(intro):", items)
    }
}
