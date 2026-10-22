//
//  AdminKnowledgeGraphDocumentRun.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'elaborazione di un documento (RagIngestionRunResponse): stato, pezzi indicizzati, entità
//  estratte ed eventuale errore. Si chiede solo quando si apre il dettaglio del documento.
//

import Foundation

nonisolated struct AdminKnowledgeGraphDocumentRun: Decodable, Sendable, Hashable, Identifiable {
    let serverId: String?
    let pipelineType: String?
    let state: String?
    let chunksCreated: Int?
    let entitiesExtracted: Int?
    let classification: [String]
    let warnings: [String]
    let model: String?
    let errorMessage: String?
    let startedAt: Date?
    let finishedAt: Date?
    let createdAt: Date?

    /// Senza id si distingue per data e stato: basta per la lista a schermo.
    var id: String { serverId ?? "\(createdAt?.timeIntervalSince1970 ?? 0)|\(state ?? "")|\(pipelineType ?? "")" }

    init(from decoder: any Decoder) throws {
        let wire = try AdminKnowledgeGraphWire(decoder)
        serverId = wire.text("id")
        pipelineType = wire.text("pipelineType")
        state = wire.text("state")
        let outputs = wire.nested("outputs")
        chunksCreated = outputs?.integer("chunksCreated")
        let extraction = wire.nested("extraction")
        entitiesExtracted = extraction?.integer("entitiesExtracted")
        classification = extraction?.texts("classification") ?? []
        warnings = extraction?.texts("warnings") ?? []
        model = extraction?.text("model")
        errorMessage = wire.nested("error")?.text("message")
        startedAt = wire.date("startedAt")
        finishedAt = wire.date("finishedAt")
        createdAt = wire.date("createdAt")
    }

    /// La data più significativa da mostrare: fine, inizio o creazione.
    var date: Date? { finishedAt ?? startedAt ?? createdAt }
}
