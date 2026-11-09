//
//  AdminCraftedReportVersion.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le modifiche a un rapporto d'intervento come versioni (report-versions.ts della web). Il .docx non si
//  cambia mai sul server: si modifica la pagina come la disegna il lettore, un blocco (paragrafo) alla
//  volta, numerati in ordine di lettura. Ogni modifica ricorda il testo che sostituisce, così si applica
//  solo al blocco su cui è nata. Le versioni sono per rapporto e per lingua.
//

import Foundation

nonisolated struct AdminCraftedReportBlockEdit: Codable, Hashable, Sendable {
    /// Il testo del blocco com'è nel rapporto: quello che la modifica sostituisce.
    var before: String
    var after: String
}

nonisolated struct AdminCraftedReportEdits: Codable, Hashable, Sendable {
    /// Indice del blocco → la sua modifica. Sul file le chiavi sono stringhe, come sulla web.
    var blocks: [Int: AdminCraftedReportBlockEdit] = [:]

    static let none = AdminCraftedReportEdits()

    var isEmpty: Bool { blocks.isEmpty }

    init(blocks: [Int: AdminCraftedReportBlockEdit] = [:]) { self.blocks = blocks }

    // Un dizionario con chiavi Int si codificherebbe come array: qui le chiavi restano stringhe.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? c.decodeIfPresent([String: AdminCraftedReportBlockEdit].self, forKey: .blocks)) ?? [:]
        blocks = Dictionary(raw.compactMap { key, value in Int(key).map { ($0, value) } }) { first, _ in first }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Dictionary(uniqueKeysWithValues: blocks.map { (String($0.key), $0.value) }), forKey: .blocks)
    }

    enum CodingKeys: String, CodingKey { case blocks }
}

nonisolated struct AdminCraftedReportVersion: Codable, Identifiable, Hashable, Sendable {
    var id: String
    /// 2, 3, … — la 1 è il rapporto originale e non si salva.
    var number: Int
    var createdAt: Date
    var author: String?
    var kind: AdminCraftedVersionKind
    var restoredFrom: Int?
    var via: AdminCraftedAriaRequest?
    var edits: AdminCraftedReportEdits
}
