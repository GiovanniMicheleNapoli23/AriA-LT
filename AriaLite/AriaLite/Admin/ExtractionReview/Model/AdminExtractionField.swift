//
//  AdminExtractionField.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un campo modificabile nel dettaglio di revisione: chiave del server (snake_case), etichetta, tipo di
//  editor e valore attuale come testo. Gli elenchi si scrivono una voce per riga; i numeri come testo.
//

import Foundation

nonisolated struct AdminExtractionField: Sendable, Hashable, Identifiable {
    enum Editor: Sendable, Hashable {
        case text
        case multiline
        /// Una voce per riga; al server va come array di testi.
        case list
        case decimal
        case integer
        /// Valori ammessi (grezzo, etichetta). Il valore attuale sconosciuto resta fra le scelte.
        case choice([AdminExtractionChoice])
    }

    /// La chiave del body PATCH, in snake_case (`asset_tag`).
    let key: String
    let label: String
    let editor: Editor
    /// Il valore sul server, come testo (elenco = righe). Vuoto = nessun valore.
    let value: String
    /// Non si può svuotare (codice, nome): un testo vuoto non si manda.
    var isRequired = false

    var id: String { key }

    /// La chiave in camelCase, come la scrive un JSON già convertito (`assetTag`).
    var camelKey: String {
        let parts = key.split(separator: "_")
        guard let first = parts.first else { return key }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Il valore da mandare per un testo dell'editor; `nil` se non è valido (numero illeggibile, obbligatorio vuoto).
    func wireValue(for text: String) -> AriaJSON? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return isRequired ? nil : (editor == .list ? .array([]) : .null) }
        switch editor {
        case .text, .multiline, .choice:
            return .string(trimmed)
        case .list:
            return .array(Self.lines(trimmed).map(AriaJSON.string))
        case .decimal:
            return Self.decimal(trimmed).map(AriaJSON.number)
        case .integer:
            return Self.decimal(trimmed).map { .number($0.rounded()) }
        }
    }

    /// Il testo dell'editor è uguale al valore sul server (spazi e righe vuote non contano).
    func isUnchanged(_ text: String) -> Bool {
        switch editor {
        case .list: Self.lines(text) == Self.lines(value)
        case .decimal, .integer: Self.decimal(text) == Self.decimal(value)
        default: text.trimmingCharacters(in: .whitespacesAndNewlines) == value
        }
    }

    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func decimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    /// Un numero come testo per l'editor: senza decimali inutili.
    static func text(_ number: Double?) -> String {
        guard let number else { return "" }
        return number.formatted(.number.precision(.fractionLength(0...4)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}

nonisolated struct AdminExtractionChoice: Sendable, Hashable, Identifiable {
    let value: String
    let label: String
    var id: String { value }
}
