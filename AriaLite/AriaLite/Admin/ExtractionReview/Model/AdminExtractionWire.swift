//
//  AdminExtractionWire.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lettura tollerante di un oggetto JSON (allarmi, piani, risposte dell'AI): un campo che manca o con un
//  tipo diverso dal previsto vale come assente, non fa fallire la riga. Le chiavi si cercano in camelCase
//  (dopo `.snakeCased()`) e, se non ci sono, in snake_case.
//

import Foundation

nonisolated struct AdminExtractionWire: Sendable {
    let object: [String: AriaJSON]

    init(_ object: [String: AriaJSON]) { self.object = object }

    /// Legge l'oggetto intero dal decoder; un valore che non è un oggetto dà un oggetto vuoto.
    init(from decoder: any Decoder) throws {
        object = try AriaJSON(from: decoder).objectValue ?? [:]
    }

    func json(_ name: String) -> AriaJSON? {
        for key in Self.spellings(of: name) {
            if let value = object[key], value != .null { return value }
        }
        return nil
    }

    func string(_ name: String) -> String? { json(name)?.nonEmptyString }

    func double(_ name: String) -> Double? {
        guard let value = json(name)?.doubleValue, value.isFinite else { return nil }
        return value
    }

    func int(_ name: String) -> Int? {
        guard let value = double(name), abs(value) < 1e12 else { return nil }
        return Int(value.rounded())
    }

    func date(_ name: String) -> Date? { string(name).flatMap(AriaWireDate.parse) }

    /// Lista di testi: un array (anche di oggetti con un campo di testo) o un testo a righe.
    func strings(_ name: String) -> [String] {
        guard let value = json(name) else { return [] }
        return Self.lines(of: value)
    }

    /// Le voci di un elenco in un valore qualsiasi.
    static func lines(of value: AriaJSON) -> [String] {
        switch value {
        case .array(let items):
            return items.compactMap(itemText)
        case .string(let text):
            return text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).replacing(/^(\d+[.)]\s*|[-•*]\s*)/, with: "") }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    /// Una voce di elenco: testo, numero, o un oggetto con un campo di testo.
    static func itemText(_ item: AriaJSON) -> String? {
        if let text = item.nonEmptyString { return text }
        guard let object = item.objectValue else { return nil }
        return ["text", "description", "instruction", "title", "name", "step", "task", "content", "cause"]
            .lazy.compactMap { object[$0]?.nonEmptyString }.first
    }

    /// `assetTag` → [`assetTag`, `asset_tag`].
    static func spellings(of name: String) -> [String] {
        let snake = name.reduce(into: "") { out, character in
            if character.isUppercase { out += "_" + character.lowercased() } else { out.append(character) }
        }
        return snake == name ? [name] : [name, snake]
    }
}
