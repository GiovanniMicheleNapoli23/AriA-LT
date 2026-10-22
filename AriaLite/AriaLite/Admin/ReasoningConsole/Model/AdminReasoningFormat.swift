//
//  AdminReasoningFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la console scrive numeri, tempi, punteggi e JSON libero: in un tipo suo, non in estensioni
//  di AriaJSON (altre sezioni potrebbero aggiungere membri con lo stesso nome).
//

import Foundation

nonisolated enum AdminReasoningFormat {
    /// Oltre questa lunghezza il JSON a schermo si taglia: il testo intero si condivide.
    static let previewLimit = 4_000

    /// "850 ms", "2.4 s", "1 min, 12 s".
    static func duration(ms: Double) -> String {
        if ms < 1_000 { return Duration.milliseconds(Int(ms.rounded())).formatted(.units(allowed: [.milliseconds], width: .abbreviated)) }
        return Duration.milliseconds(Int(ms.rounded())).formatted(
            .units(allowed: [.minutes, .seconds], width: .abbreviated, maximumUnitCount: 2,
                   fractionalPart: ms < 60_000 ? .show(length: 1) : .hide))
    }

    static func duration(ms: Int?) -> String? { ms.map { duration(ms: Double($0)) } }

    /// Il testo senza spazi ai bordi, `nil` se manca o resta vuoto.
    static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// Punteggi 0…1 come percentuale.
    static func percent(_ value: Double?) -> String? {
        value.map { $0.formatted(.percent.precision(.fractionLength(0))) }
    }

    /// Somiglianza del coseno: due decimali bastano.
    static func score(_ value: Double?) -> String? {
        value.map { $0.formatted(.number.precision(.fractionLength(2))) }
    }

    static func number(_ value: Double) -> String {
        if let int = Int(exactly: value) { return int.formatted() }
        return value.formatted(.number.precision(.significantDigits(1...4)))
    }

    /// `groundingScore`, `node_work_ms` → "Grounding score", "Node work ms".
    static func humanize(_ key: String) -> String {
        var words: [String] = []
        var current = ""
        for char in key {
            if char == "_" || char == "-" || char == " " {
                if !current.isEmpty { words.append(current) }
                current = ""
            } else if char.isUppercase, let last = current.last, last.isLowercase || last.isNumber {
                words.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { words.append(current) }
        let sentence = words.map { $0.lowercased() }.joined(separator: " ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    /// Un valore scalare in una riga; `nil` per oggetti, liste e testi lunghi (vanno in un blocco).
    static func inline(_ value: AriaJSON, key: String) -> String? {
        switch value {
        case .null: return "—"
        case .bool(let flag): return flag ? String(localized: "Yes") : String(localized: "No")
        case .number(let number):
            // Le chiavi che finiscono in "Ms" sono millisecondi.
            if key.hasSuffix("Ms") || key.lowercased().hasSuffix("_ms") { return duration(ms: number) }
            return self.number(number)
        case .string(let text):
            guard text.count <= 120, !text.contains("\n") else { return nil }
            return text.isEmpty ? "—" : text
        case .array(let items) where items.isEmpty: return String(localized: "None")
        case .object(let object) where object.isEmpty: return "—"
        default: return nil
        }
    }

    /// JSON leggibile (indentato, chiavi in ordine). Un testo semplice resta testo.
    static func pretty(_ value: AriaJSON) -> String {
        if case .string(let text) = value { return text }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Quanti elementi ha un blocco: "12 items", "4 keys", "2,300 characters".
    static func size(of value: AriaJSON) -> String {
        switch value {
        case .array(let items): String(localized: "\(items.count) items")
        case .object(let object): String(localized: "\(object.count) keys")
        case .string(let text): String(localized: "\(text.count) characters")
        default: ""
        }
    }

    /// Divide un oggetto in righe (valori brevi) e blocchi (oggetti, liste, testi lunghi), in ordine di chiave.
    static func split(_ object: [String: AriaJSON], excluding: Set<String> = [])
        -> (fields: [AdminAssetField], blocks: [AdminReasoningJSONBlock]) {
        var fields: [AdminAssetField] = []
        var blocks: [AdminReasoningJSONBlock] = []
        for key in object.keys.sorted() where !excluding.contains(key) {
            guard let value = object[key] else { continue }
            if let text = inline(value, key: key) {
                fields.append(AdminAssetField(title: humanize(key), value: text))
            } else {
                blocks.append(AdminReasoningJSONBlock(key: key, value: value))
            }
        }
        return (fields, blocks)
    }
}

/// Un pezzo di JSON da leggere in monospace: anteprima tagliata a schermo, testo intero da condividere.
nonisolated struct AdminReasoningJSONBlock: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let size: String
    let preview: String
    let fullText: String
    var isTruncated: Bool { preview.count < fullText.count }

    init(key: String, value: AriaJSON) {
        id = key
        title = AdminReasoningFormat.humanize(key)
        size = AdminReasoningFormat.size(of: value)
        fullText = AdminReasoningFormat.pretty(value)
        preview = String(fullText.prefix(AdminReasoningFormat.previewLimit))
    }
}

/// Un numero in evidenza in cima a una schermata.
nonisolated struct AdminReasoningStat: Identifiable, Sendable, Hashable {
    let title: String
    let value: String
    let systemImage: String
    var id: String { title }
}
