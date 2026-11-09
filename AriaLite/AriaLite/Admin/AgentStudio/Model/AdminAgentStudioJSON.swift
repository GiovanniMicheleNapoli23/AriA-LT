//
//  AdminAgentStudioJSON.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lettura tollerante delle risposte di Agent Studio: molte rotte non hanno uno schema (oggetti liberi),
//  le altre mescolano camelCase e snake_case. Ogni modello si costruisce da un AriaJSON e cerca
//  ogni campo sotto più nomi, così un campo nuovo o rinominato non fa fallire la schermata.
//

import Foundation

/// Un modello che si legge da JSON libero; `nil` se manca l'essenziale (di solito l'id).
nonisolated protocol AdminAgentStudioJSONModel: Sendable {
    init?(json: AriaJSON)
    /// Le chiavi sotto cui una risposta-lista può tenere gli elementi (`{"workflows": […]}`).
    static var listKeys: [String] { get }
}

/// Una risposta con un solo oggetto.
nonisolated struct AdminAgentStudioOne<Model: AdminAgentStudioJSONModel>: Decodable, Sendable {
    let value: Model

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        guard let value = Model(json: json) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unreadable \(Model.self)"))
        }
        self.value = value
    }
}

/// Una risposta-lista: array nudo o oggetto con l'array sotto una delle `listKeys`.
/// Gli elementi illeggibili si scartano; il resto dell'oggetto resta in `fields` (contatori, finestre…).
nonisolated struct AdminAgentStudioList<Model: AdminAgentStudioJSONModel>: Decodable, Sendable {
    let items: [Model]
    let fields: AdminAgentStudioFields

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        fields = AdminAgentStudioFields(json)
        items = Self.elements(in: json).compactMap(Model.init(json:))
    }

    private static func elements(in json: AriaJSON) -> [AriaJSON] {
        if case .array(let items) = json { return items }
        guard let object = json.objectValue else { return [] }
        if Model.listKeys.contains(where: { object[$0] != nil }) {
            return Model.listKeys.flatMap { object[$0]?.arrayValue ?? [] }
        }
        // Chiave sconosciuta: il primo array di oggetti della risposta.
        return object.values.first { $0.arrayValue.contains { $0.objectValue != nil } }?.arrayValue ?? []
    }
}

/// I campi di un oggetto JSON, cercati per nome. Ogni nome si prova anche in snake_case
/// (`workflowName` trova anche `workflow_name`); null e stringhe vuote contano come assenti.
nonisolated struct AdminAgentStudioFields: Sendable, Hashable {
    let raw: [String: AriaJSON]

    init(_ json: AriaJSON?) {
        raw = json?.objectValue ?? [:]
    }

    var isEmpty: Bool { raw.isEmpty }

    func value(_ keys: String...) -> AriaJSON? { lookup(keys) }

    func string(_ keys: String...) -> String? { lookup(keys)?.nonEmptyString }

    func int(_ keys: String...) -> Int? {
        guard let number = lookup(keys)?.doubleValue, number.isFinite, abs(number) < 1e15 else { return nil }
        return Int(number)
    }

    func double(_ keys: String...) -> Double? {
        guard let number = lookup(keys)?.doubleValue, number.isFinite else { return nil }
        return number
    }

    func bool(_ keys: String...) -> Bool? {
        switch lookup(keys) {
        case .bool(let value)?: value
        case .string(let text)?: ["true", "1", "yes"].contains(text.lowercased()) ? true
            : ["false", "0", "no"].contains(text.lowercased()) ? false : nil
        case .number(let number)?: number != 0
        default: nil
        }
    }

    func date(_ keys: String...) -> Date? { AdminAgentStudioDate.date(from: lookup(keys)) }

    /// Lista di testi; un testo solo diventa una lista di uno.
    func strings(_ keys: String...) -> [String] {
        guard let value = lookup(keys) else { return [] }
        if case .array(let items) = value { return items.compactMap(\.nonEmptyString) }
        return value.nonEmptyString.map { [$0] } ?? []
    }

    func array(_ keys: String...) -> [AriaJSON] { lookup(keys)?.arrayValue ?? [] }

    func object(_ keys: String...) -> AdminAgentStudioFields { AdminAgentStudioFields(lookup(keys)) }

    private func lookup(_ keys: [String]) -> AriaJSON? {
        for key in keys {
            for candidate in [key, Self.snakeCase(key)] {
                if let value = raw[candidate], value != .null { return value }
            }
        }
        return nil
    }

    private static func snakeCase(_ key: String) -> String {
        var out = ""
        for character in key {
            if character.isUppercase, !out.isEmpty { out.append("_") }
            out.append(contentsOf: character.lowercased())
        }
        return out
    }
}

/// Date di Agent Studio: interi in millisecondi (Date.now() della web) o secondi, a volte ISO 8601.
/// Zero vuol dire "non ancora" (es. `finishedAt` di un run in corso).
nonisolated enum AdminAgentStudioDate {
    static func date(from value: AriaJSON?) -> Date? {
        guard let value else { return nil }
        if case .number(let number) = value { return date(epoch: number) }
        guard let text = value.nonEmptyString else { return nil }
        if let number = Double(text) { return date(epoch: number) }
        return AriaDate.parse(text)
    }

    private static func date(epoch: Double) -> Date? {
        guard epoch.isFinite, epoch > 0 else { return nil }
        return Date(timeIntervalSince1970: epoch > 1e11 ? epoch / 1000 : epoch)
    }
}
