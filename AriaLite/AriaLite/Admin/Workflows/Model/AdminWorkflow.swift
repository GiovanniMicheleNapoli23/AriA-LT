//
//  AdminWorkflow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un flusso (FlowDefinition del backend, chiavi in camelCase, id in `_id`). Lettura tollerante: servono
//  solo l'id e il nome; grafo, stato e date possono mancare. "Pubblicato" non è uno stato: un flusso con
//  `definitionVersion` > 0 ha almeno una versione pubblicata.
//

import Foundation

nonisolated struct AdminWorkflow: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    /// Valore grezzo (`draft`, `archived`), vedi AdminWorkflowStatus.
    let status: String?
    /// Per la concorrenza ottimistica: ogni azione la rimanda, il server risponde 409 se è cambiata.
    let revision: Int
    /// L'ultima versione pubblicata; 0 = mai pubblicato.
    let definitionVersion: Int
    let graph: AdminWorkflowGraph
    let createdAt: Date?
    let createdBy: String?
    let updatedAt: Date?
    let updatedBy: String?
    let archivedAt: Date?

    var knownStatus: AdminWorkflowStatus { status.flatMap(AdminWorkflowStatus.init(rawValue:)) ?? .draft }
    var isArchived: Bool { knownStatus == .archived }
    var isPublished: Bool { definitionVersion > 0 }

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, description, status, revision, definitionVersion, graph
        case createdAt, createdBy, updatedAt, updatedBy, archivedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Senza id il flusso non si può aprire né modificare: la riga si scarta.
        guard let id = try c.decodeIfPresent(String.self, forKey: .id), !id.isEmpty else {
            throw DecodingError.keyNotFound(
                CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "Missing _id"))
        }
        self.id = id
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        description = Self.text(c, .description)
        status = Self.text(c, .status)
        revision = (try? c.decodeIfPresent(Int.self, forKey: .revision)) ?? 0
        definitionVersion = (try? c.decodeIfPresent(Int.self, forKey: .definitionVersion)) ?? 0
        graph = (try? c.decodeIfPresent(AdminWorkflowGraph.self, forKey: .graph)) ?? AdminWorkflowGraph()
        createdAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .createdAt))?.value
        createdBy = Self.text(c, .createdBy)
        updatedAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .updatedAt))?.value
        updatedBy = Self.text(c, .updatedBy)
        archivedAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .archivedAt))?.value
    }

    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard let value = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// GET …/topologies: `items`, `total`, `skip`, `limit`. Una riga illeggibile si scarta.
nonisolated struct AdminWorkflowPage: Decodable, Sendable {
    let flows: [AdminWorkflow]
    let total: Int?

    private enum CodingKeys: String, CodingKey { case items, total }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flows = (try c.decodeIfPresent(AriaLossyArray<AdminWorkflow>.self, forKey: .items))?.items ?? []
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
    }
}
