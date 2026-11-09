//
//  AdminCraftedVersion.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le modifiche a un artifact come versioni (crafted-versions.ts della web). La risposta di Aria non si
//  sovrascrive mai: è la versione 1 e non si salva; ogni salvataggio è una versione a sé, con tutto lo
//  stato modificato rispetto all'originale (non un delta). Ripristinarne una è una versione nuova.
//

import Foundation

nonisolated enum AdminCraftedVersionKind: String, Codable, Sendable {
    /// Scritta a mano, o da Aria su richiesta (`via`).
    case edit
    /// Una versione precedente rimessa com'era.
    case restore
}

nonisolated struct AdminCraftedArtifactVersion: Codable, Identifiable, Hashable, Sendable {
    var id: String
    /// 2, 3, … — la 1 è l'originale e non si salva.
    var number: Int
    var createdAt: Date
    /// Chi l'ha salvata, come si mostra; `nil` se il nome non si è potuto leggere.
    var author: String?
    var kind: AdminCraftedVersionKind
    /// La versione rimessa, se `kind` è `restore`.
    var restoredFrom: Int?
    /// Fatta da Aria su richiesta.
    var via: AdminCraftedAriaRequest?
    var edits: AdminCraftedArtifactEdits
}

nonisolated struct AdminCraftedArtifactEdits: Codable, Hashable, Sendable {
    /// Id del messaggio di Aria → il suo testo modificato.
    var texts: [String: String] = [:]
    /// Id della tabella → le sue righe modificate (le colonne restano quelle di Aria).
    var tables: [String: [AdminCraftedEditedRow]] = [:]

    static let none = AdminCraftedArtifactEdits()

    var isEmpty: Bool { texts.isEmpty && tables.isEmpty }

    init(texts: [String: String] = [:], tables: [String: [AdminCraftedEditedRow]] = [:]) {
        self.texts = texts
        self.tables = tables
    }

    // Tollerante: una chiave che manca è vuota, non un file da buttare.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        texts = (try? c.decodeIfPresent([String: String].self, forKey: .texts)) ?? [:]
        tables = (try? c.decodeIfPresent([String: [AdminCraftedEditedRow]].self, forKey: .tables)) ?? [:]
    }

    enum CodingKeys: String, CodingKey { case texts, tables }
}

/// Una riga come modificata, con un'identità sua: una riga tolta non deve leggersi come tutte le successive cambiate.
nonisolated struct AdminCraftedEditedRow: Codable, Hashable, Identifiable, Sendable {
    /// `o<indice>` per una riga di Aria; altro per una aggiunta a mano.
    var id: String
    var cells: [String: AdminCraftedCell]

    /// Un id per una riga aggiunta a mano.
    static func newID() -> String { "n-" + UUID().uuidString.prefix(8).lowercased() }
}

/// Una cella: stringa, numero o null nel JSON.
nonisolated enum AdminCraftedCell: Codable, Hashable, Sendable {
    case text(String)
    case number(Double)
    case empty

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .empty }
        else if let number = try? c.decode(Double.self) { self = .number(number) }
        else if let text = try? c.decode(String.self) { self = .text(text) }
        else if let flag = try? c.decode(Bool.self) { self = .text(String(flag)) }
        else { self = .empty }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let text): try c.encode(text)
        case .number(let number):
            // Gli interi restano interi (12, non 12.0).
            if let integer = Int(exactly: number) { try c.encode(integer) } else { try c.encode(number) }
        case .empty: try c.encodeNil()
        }
    }

    /// Come si legge in una cella (cellText della web): vuoto per null.
    var displayText: String {
        switch self {
        case .text(let text): text
        case .number(let number): Int(exactly: number).map(String.init) ?? String(number)
        case .empty: ""
        }
    }

    /// Da come arriva nella tabella di Aria; bool, liste e oggetti si leggono come testo.
    init(json: AriaJSON?) {
        switch json {
        case .string(let text)?: self = .text(text)
        case .number(let number)?: self = .number(number)
        case .bool(let flag)?: self = .text(String(flag))
        case .array?, .object?: self = .text(json?.compactDescription ?? "")
        case .null?, nil: self = .empty
        }
    }

    var json: AriaJSON {
        switch self {
        case .text(let text): .string(text)
        case .number(let number): .number(number)
        case .empty: .null
        }
    }
}
