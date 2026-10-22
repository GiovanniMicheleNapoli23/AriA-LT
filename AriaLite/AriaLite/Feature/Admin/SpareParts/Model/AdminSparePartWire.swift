//
//  AdminSparePartWire.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lettura tollerante delle risposte dei ricambi: da qui non si prova l'API dal vivo con un account admin,
//  quindi un campo che manca, un numero che arriva come Int o come Double, una stringa al posto di un numero
//  non fanno fallire la riga. Ogni chiave si cerca in camelCase (dopo `.convertFromSnakeCase`) e in snake_case.
//

import Foundation

/// Chiave libera: le chiavi si scelgono a runtime.
nonisolated struct AdminSparePartWireKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ name: String) { stringValue = name }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// I campi di un oggetto JSON letti senza mai lanciare: un valore illeggibile vale come assente.
nonisolated struct AdminSparePartWireReader {
    private let container: KeyedDecodingContainer<AdminSparePartWireKey>

    init(_ decoder: any Decoder) throws {
        container = try decoder.container(keyedBy: AdminSparePartWireKey.self)
    }

    /// Il valore grezzo; `null` conta come assente.
    func json(_ name: String) -> AriaJSON? {
        for candidate in Self.spellings(of: name) {
            let key = AdminSparePartWireKey(candidate)
            guard container.contains(key), let value = try? container.decode(AriaJSON.self, forKey: key),
                  value != .null else { continue }
            return value
        }
        return nil
    }

    /// Testo non vuoto; un numero diventa testo (gli id a volte arrivano come interi).
    func string(_ name: String) -> String? { json(name)?.nonEmptyString }

    func double(_ name: String) -> Double? {
        guard let value = json(name)?.doubleValue, value.isFinite else { return nil }
        return value
    }

    /// Intero anche se arriva come `12.0` o `"12"`.
    func int(_ name: String) -> Int? {
        guard let value = double(name), abs(value) < Double(Int.max) else { return nil }
        return Int(value.rounded())
    }

    func bool(_ name: String) -> Bool? {
        switch json(name) {
        case .bool(let value)?: value
        case .number(let value)?: value != 0
        case .string(let text)?: ["true", "1", "yes"].contains(text.lowercased())
        default: nil
        }
    }

    func date(_ name: String) -> Date? { string(name).flatMap(AriaWireDate.parse) }

    /// Lista di testi; una stringa sola con le virgole vale come lista.
    func strings(_ name: String) -> [String] {
        switch json(name) {
        case .array(let items)?: items.compactMap(\.nonEmptyString)
        case .string(let text)?: text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        default: []
        }
    }

    /// `partNumber` → [`partNumber`, `part_number`].
    static func spellings(of name: String) -> [String] {
        let snake = name.reduce(into: "") { out, character in
            if character.isUppercase { out += "_" + character.lowercased() } else { out.append(character) }
        }
        return snake == name ? [name] : [name, snake]
    }

    /// Lo stesso in un oggetto già letto come `AriaJSON` (storico prezzi): prima camelCase, poi snake_case.
    static func value(_ name: String, in object: AriaJSON) -> AriaJSON? {
        for candidate in spellings(of: name) {
            if let value = object[candidate], value != .null { return value }
        }
        return nil
    }
}

/// Un array di righe (`[...]`) o un oggetto che lo avvolge (`{"items": [...]}`): le righe illeggibili si saltano.
nonisolated struct AdminSparePartRows<Element: Decodable & Sendable>: Decodable, Sendable {
    let items: [Element]

    private static var wrapperKeys: [String] {
        ["items", "data", "results", "parts", "spareParts", "lowStock", "vendors"]
    }

    init(from decoder: any Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode(AriaLossyArray<Element>.self) {
            items = rows.items
            return
        }
        let container = try decoder.container(keyedBy: AdminSparePartWireKey.self)
        for name in Self.wrapperKeys {
            for candidate in AdminSparePartWireReader.spellings(of: name) {
                if let rows = try? container.decodeIfPresent(AriaLossyArray<Element>.self, forKey: .init(candidate)) {
                    items = rows.items
                    return
                }
            }
        }
        items = []
    }
}
