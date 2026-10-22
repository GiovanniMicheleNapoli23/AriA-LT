//
//  AdminKnowledgeGraphWire.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lettura tollerante delle risposte del Knowledge Graph: un campo mancante, vuoto o di tipo diverso
//  diventa `nil` invece di far fallire tutta la lista. Le chiavi arrivano già in camelCase.
//

import Foundation

nonisolated struct AdminKnowledgeGraphWireKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ name: String) { stringValue = name }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

nonisolated struct AdminKnowledgeGraphWire {
    private let container: KeyedDecodingContainer<AdminKnowledgeGraphWireKey>

    init(_ decoder: any Decoder) throws {
        container = try decoder.container(keyedBy: AdminKnowledgeGraphWireKey.self)
    }

    private init(container: KeyedDecodingContainer<AdminKnowledgeGraphWireKey>) {
        self.container = container
    }

    /// Testo (o numero letto come testo), senza spazi ai bordi; vuoto = `nil`.
    func text(_ key: String) -> String? {
        guard let value = try? container.decodeIfPresent(AriaFlexibleID.self, forKey: .init(key))?.value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func number(_ key: String) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: .init(key)) { return value }
        return text(key).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }

    func integer(_ key: String) -> Int? { number(key).map { Int($0) } }

    func flag(_ key: String) -> Bool? { try? container.decodeIfPresent(Bool.self, forKey: .init(key)) }

    func date(_ key: String) -> Date? { (try? container.decodeIfPresent(AriaWireDate.self, forKey: .init(key)))?.value }

    /// Una lista di testi; gli elementi che non sono testo si saltano.
    func texts(_ key: String) -> [String] {
        guard let rows = try? container.decodeIfPresent(AriaLossyArray<AriaFlexibleID>.self, forKey: .init(key)) else { return [] }
        return rows.items.map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Un oggetto annidato (es. `source`, `status` di un documento).
    func nested(_ key: String) -> AdminKnowledgeGraphWire? {
        (try? container.nestedContainer(keyedBy: AdminKnowledgeGraphWireKey.self, forKey: .init(key)))
            .map(AdminKnowledgeGraphWire.init(container:))
    }
}
