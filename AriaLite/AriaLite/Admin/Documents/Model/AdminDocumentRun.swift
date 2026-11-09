//
//  AdminDocumentRun.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una run di pipeline del documento (RagIngestionRunResponse): indicizzazione o estrazione, con stato,
//  fasi, risultati e l'eventuale errore. Le fasi e i metadati dell'estrazione si leggono solo se ci sono.
//

import SwiftUI

nonisolated struct AdminDocumentRun: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    /// `ingestion`, `extraction`… (grezzo).
    let pipelineType: String?
    /// RunState grezzo: `queued`, `running`, `completed`, `completed_with_errors`, `failed`, `canceled`.
    let state: String?
    let stages: [AdminDocumentRunStage]
    let chunksCreated: Int?
    let vectorsStored: Int?
    let entitiesExtracted: Int?
    let classification: [String]
    let classificationConfidence: Double?
    let warnings: [String]
    let model: String?
    let error: String?
    let startedAt: Date?
    let finishedAt: Date?
    let createdAt: Date?

    var isActive: Bool { state == "queued" || state == "running" }

    var pipelineLabel: String {
        switch pipelineType?.lowercased() {
        case "ingestion": String(localized: "Indexing")
        case "extraction": String(localized: "Extraction")
        case let other?: AdminDocumentState.label(for: other)
        case nil: String(localized: "Pipeline run")
        }
    }

    var stateLabel: String {
        switch state {
        case "queued": String(localized: "Queued")
        case "running": String(localized: "Running")
        case "completed": String(localized: "Completed")
        case "completed_with_errors": String(localized: "Completed with errors")
        case "failed": String(localized: "Failed")
        case "canceled": String(localized: "Canceled")
        case let other?: AdminDocumentState.label(for: other)
        case nil: String(localized: "Unknown")
        }
    }

    var stateTint: Color {
        switch state {
        case "queued", "running": .blue
        case "completed": .green
        case "completed_with_errors", "failed": .orange
        default: .secondary
        }
    }

    /// Quanto è durata (o dura da) la run.
    var duration: Duration? {
        guard let startedAt else { return nil }
        let end = finishedAt ?? (isActive ? .now : nil)
        guard let end, end >= startedAt else { return nil }
        return .seconds(end.timeIntervalSince(startedAt).rounded())
    }

    private enum CodingKeys: String, CodingKey {
        case id, pipelineType, state, stages, outputs, extraction, error, startedAt, finishedAt, createdAt
    }
    private enum OutputKeys: String, CodingKey { case chunksCreated, vectorsStored }
    private enum ExtractionKeys: String, CodingKey { case classification, classificationConfidence, entitiesExtracted, warnings, provider, model }

    init(from decoder: any Decoder) throws {
        typealias D = AdminDocumentDecoding
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = D.date(c, .createdAt)
        let startedAt = D.date(c, .startedAt)
        // Senza id la riga resta visibile: si usa la data come identità.
        guard let id = D.text(c, .id) ?? (createdAt ?? startedAt).map({ "\($0.timeIntervalSince1970)" }) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "Run senza id"))
        }
        self.id = id
        self.createdAt = createdAt
        self.startedAt = startedAt
        pipelineType = D.text(c, .pipelineType)
        state = D.text(c, .state)
        stages = (try? c.decodeIfPresent(AriaLossyArray<AdminDocumentRunStage>.self, forKey: .stages))?.items ?? []
        error = D.errorMessage(c, .error)
        finishedAt = D.date(c, .finishedAt)

        let outputs = try? c.nestedContainer(keyedBy: OutputKeys.self, forKey: .outputs)
        chunksCreated = outputs.flatMap { D.int($0, .chunksCreated) }
        vectorsStored = outputs.flatMap { D.int($0, .vectorsStored) }

        let extraction = try? c.nestedContainer(keyedBy: ExtractionKeys.self, forKey: .extraction)
        entitiesExtracted = extraction.flatMap { D.int($0, .entitiesExtracted) }
        classification = extraction.map { D.strings($0, .classification) } ?? []
        classificationConfidence = extraction.flatMap { D.double($0, .classificationConfidence) }
        warnings = extraction.map { D.strings($0, .warnings) } ?? []
        model = extraction.flatMap { D.text($0, .model) ?? D.text($0, .provider) }
    }
}

/// Una fase della run (`parsing`, `embedding`…) con il suo esito (StageResponse). Il server manda `name` e
/// `state` (stringhe libere); le vecchie chiavi `stage`/`status` si leggono come ripiego.
nonisolated struct AdminDocumentRunStage: Decodable, Sendable, Hashable {
    let stage: String
    let status: String?
    let error: String?
    /// Lotti fatti e totali (`metrics`): l'embedding li riporta, permette un avanzamento più fine.
    let batchesDone: Int?
    let totalBatches: Int?

    var label: String { AdminDocumentState.label(for: stage) }
    var isFailed: Bool { normalizedStatus == "failed" || error != nil }
    var isDone: Bool { ["completed", "succeeded", "skipped"].contains(normalizedStatus) }
    /// È la fase che sta lavorando ora.
    var isRunning: Bool { ["running", "in_progress", "started"].contains(normalizedStatus) }

    private var normalizedStatus: String? { status?.lowercased() }

    init(stage: String, status: String? = nil, error: String? = nil, batchesDone: Int? = nil, totalBatches: Int? = nil) {
        self.stage = stage
        self.status = status
        self.error = error
        self.batchesDone = batchesDone
        self.totalBatches = totalBatches
    }

    private enum CodingKeys: String, CodingKey { case name, state, stage, status, error, metrics }
    private enum MetricsKeys: String, CodingKey { case batchesDone, totalBatches }

    init(from decoder: any Decoder) throws {
        typealias D = AdminDocumentDecoding
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let stage = D.text(c, .name) ?? D.text(c, .stage) else {
            throw DecodingError.keyNotFound(CodingKeys.name, .init(codingPath: c.codingPath, debugDescription: "Fase senza nome"))
        }
        self.stage = stage
        status = D.text(c, .state) ?? D.text(c, .status)
        error = D.errorMessage(c, .error)
        let metrics = try? c.nestedContainer(keyedBy: MetricsKeys.self, forKey: .metrics)
        batchesDone = metrics.flatMap { D.int($0, .batchesDone) }
        totalBatches = metrics.flatMap { D.int($0, .totalBatches) }
    }
}
