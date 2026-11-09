//
//  AdminDocumentPipelineProgress.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'avanzamento di una pipeline del documento (indicizzazione o estrazione) a partire dal suo stato grezzo:
//  a che passo è, su quanti, la frazione 0…1 e l'etichetta del passo. Con la run attiva si affina: se la
//  fase corrente riporta i lotti (embedding), si aggiunge la frazione di lotti fatti dentro quel passo.
//  Uno stato sconosciuto o fuori dai passi non ha una frazione: la barra resta indeterminata.
//

import Foundation

/// Le due pipeline lato server e i passi, in ordine, che attraversano.
nonisolated enum AdminDocumentPipeline: String, Sendable, CaseIterable {
    case ingestion, extraction

    init?(pipelineType: String?) {
        guard let value = pipelineType?.lowercased() else { return nil }
        self.init(rawValue: value)
    }

    var steps: [AdminDocumentState] {
        switch self {
        case .ingestion: [.fetching, .parsing, .chunking, .embedding, .indexing]
        case .extraction: [.fetching, .parsing, .classifying, .extracting, .validating, .persisting]
        }
    }

    var title: String {
        switch self {
        case .ingestion: String(localized: "Indexing")
        case .extraction: String(localized: "Extraction")
        }
    }
}

nonisolated struct AdminDocumentPipelineProgress: Sendable, Equatable, Identifiable {
    enum Phase: Sendable, Equatable {
        /// In coda: nessun passo iniziato.
        case queued
        /// Lavora a uno dei passi.
        case running
        case finished, failed, canceled
        /// In pausa, in cancellazione o uno stato che l'app non conosce.
        case other
    }

    let pipeline: AdminDocumentPipeline
    let rawState: String
    let phase: Phase
    /// Il passo corrente da 1; 0 se non è a un passo (in coda, concluso, errore…).
    let step: Int
    let stepCount: Int
    /// 0…1; `nil` se non si può dire (barra indeterminata).
    let fraction: Double?
    let label: String

    var id: String { pipeline.rawValue }
    /// In coda o al lavoro.
    var isActive: Bool { phase == .queued || phase == .running }
    var isFinished: Bool { phase == .finished }
    var isFailed: Bool { phase == .failed }
    var isCanceled: Bool { phase == .canceled }

    /// Lo stato grezzo dà il passo (un passo fuori dalla lista della pipeline non ha frazione). `activeRun`,
    /// se è la run attiva della stessa pipeline, affina la frazione con i lotti della fase che lavora, ma solo
    /// se quella fase è lo stesso passo dello stato del documento (i due arrivano da richieste diverse).
    init(pipeline: AdminDocumentPipeline, rawState: String, activeRun: AdminDocumentRun? = nil) {
        let steps = pipeline.steps
        self.pipeline = pipeline
        self.rawState = rawState
        stepCount = steps.count
        label = AdminDocumentState.label(for: rawState)

        switch AdminDocumentState(rawValue: rawState) {
        case .queued?:
            phase = .queued
            step = 0
            fraction = 0
        case .completed?:
            phase = .finished
            step = steps.count
            fraction = 1
        case .failed?:
            phase = .failed
            step = 0
            fraction = nil
        case .canceled?:
            phase = .canceled
            step = 0
            fraction = nil
        case let state? where steps.contains(state):
            let index = steps.firstIndex(of: state) ?? 0
            let inner = Self.batchFraction(of: activeRun, steps: steps, index: index)
            phase = .running
            step = index + 1
            fraction = (Double(index) + inner) / Double(steps.count)
        default:
            phase = .other
            step = 0
            fraction = nil
        }
    }

    /// Quanto è fatto, da 0 a 1, del passo `index`, se la run lo dice (`batchesDone` / `totalBatches`).
    private static func batchFraction(of run: AdminDocumentRun?, steps: [AdminDocumentState], index: Int) -> Double {
        guard let run, run.isActive,
              let stage = run.stages.first(where: \.isRunning),
              let total = stage.totalBatches, total > 0,
              let named = AdminDocumentState(rawValue: stage.stage.lowercased()),
              steps.firstIndex(of: named) == index else { return 0 }
        return min(max(Double(stage.batchesDone ?? 0) / Double(total), 0), 1)
    }

    /// "Step 3 of 5 · Chunking", oppure solo l'etichetta ("Queued", "Completed", stato sconosciuto).
    /// Con `showingPipeline` in testa il nome della pipeline: serve se ne compaiono due insieme.
    func caption(showingPipeline: Bool = false) -> String {
        var text = label
        if phase == .running, fraction != nil {
            text = String(localized: "Step \(step) of \(stepCount)") + " · " + label
        }
        return showingPipeline ? pipeline.title + " · " + text : text
    }

    /// Il valore letto da VoiceOver: didascalia e percentuale, se c'è.
    var accessibilityValue: String {
        guard let fraction else { return caption() }
        return caption() + ", " + fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

nonisolated extension AdminDocument {
    /// L'avanzamento di una pipeline finché è attiva (in coda o al lavoro), altrimenti `nil`.
    /// `run` è la run attiva di quella pipeline, per l'avanzamento fine.
    func progress(for pipeline: AdminDocumentPipeline, run: AdminDocumentRun? = nil) -> AdminDocumentPipelineProgress? {
        guard !isDeleted else { return nil }
        let raw = switch pipeline {
        case .ingestion: ingestionState
        case .extraction: extractionState
        }
        guard let raw else { return nil }
        let progress = AdminDocumentPipelineProgress(pipeline: pipeline, rawState: raw, activeRun: run)
        return progress.isActive ? progress : nil
    }

    /// Le pipeline attive ora, indicizzazione prima.
    var activeProgress: [AdminDocumentPipelineProgress] {
        AdminDocumentPipeline.allCases.compactMap { progress(for: $0) }
    }
}
