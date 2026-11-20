//
//  AdminDocumentDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un documento: metadati, stato delle pipeline, run e azioni (estrai, indicizza,
//  ferma, cancella) con conferma. Mentre una pipeline lavora si riaggiorna da solo (4, 8, 15, 30 s:
//  AdminDocumentPollSchedule), non con l'app non attiva e non senza rete; le novità passano alla lista (`onChange`).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDocumentDetailViewModel {
    let backend: AriaBackend
    private let onChange: (AdminDocument) -> Void
    private let onDelete: (String) -> Void

    @ObservationIgnored private let network: AriaNetworkMonitor

    /// La vista dice se l'app è attiva: altrimenti il ciclo di aggiornamento sta fermo.
    var isAppActive = true
    /// Cresce a ogni lettura forzata: un ciclo fermo per troppa calma riparte.
    private(set) var pollEpoch = 0

    private(set) var document: AdminDocument
    private(set) var runs: [AdminDocumentRun] = []
    private(set) var runsTotal: Int?
    private(set) var hasLoadedRuns = false
    private(set) var documentError: String?
    private(set) var runsError: String?
    private(set) var isPerforming = false

    /// Azione in attesa di conferma.
    var pendingAction: AdminDocumentAction?
    var showsConfirmation = false
    private(set) var failedAction: AdminDocumentAction?
    private(set) var actionError: String?
    var showsActionError = false
    /// Cancellato: la vista torna alla lista.
    private(set) var didDelete = false

    /// Il file scaricato che Quick Look mostra; la vista lo azzera chiudendo l'anteprima.
    var previewURL: URL?
    private(set) var isOpeningPreview = false
    private(set) var previewError: String?

    init(backend: AriaBackend, document: AdminDocument, network: AriaNetworkMonitor = .shared,
         onChange: @escaping (AdminDocument) -> Void, onDelete: @escaping (String) -> Void) {
        self.backend = backend
        self.network = network
        self.document = document
        self.onChange = onChange
        self.onDelete = onDelete
    }

    // MARK: Stato

    /// Qualcosa lavora: il documento o una delle sue run.
    var isWorking: Bool { document.isProcessing || runs.contains(where: \.isActive) }

    var pollKey: String { "\(document.id)|\(isWorking)|\(isAppActive)|\(pollEpoch)" }

    /// Stati e avanzamento di documento e run: se cambiano, il ritmo di aggiornamento riparte veloce.
    private var progressSignature: String {
        let runStates = runs.map { run in
            let stages = run.stages.map { "\($0.status ?? "")\($0.batchesDone ?? -1)" }.joined(separator: ",")
            return "\(run.id)|\(run.state ?? "")|\(stages)"
        }
        return "\(document.ingestionState ?? "")|\(document.extractionState ?? "")|" + runStates.joined(separator: ";")
    }

    var isDeleting: Bool { document.statusGroup == .deleting }
    var canCancel: Bool { isWorking && !isDeleting && !isPerforming }
    var canRerun: Bool { !isWorking && !isDeleting && !isPerforming && backend.activeCompanyId != nil }
    var canDelete: Bool { !isDeleting && !isPerforming }

    var ingestionLabel: String? { document.ingestionState.map(AdminDocumentState.label(for:)) }
    var extractionLabel: String? { document.extractionState.map(AdminDocumentState.label(for:)) }

    /// L'avanzamento di ciascuna pipeline finché è attiva, affinato con la sua ultima run in corso
    /// (le run sono ordinate dalla più recente).
    var ingestionProgress: AdminDocumentPipelineProgress? { progress(for: .ingestion) }
    var extractionProgress: AdminDocumentPipelineProgress? { progress(for: .extraction) }

    private func progress(for pipeline: AdminDocumentPipeline) -> AdminDocumentPipelineProgress? {
        let run = runs.first { AdminDocumentPipeline(pipelineType: $0.pipelineType) == pipeline && $0.isActive }
        return document.progress(for: pipeline, run: run)
    }

    /// La scheda "Details".
    var fields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "File name"), document.fileName)
        add(String(localized: "Type"), document.mimeType)
        add(String(localized: "Size"), document.sizeBytes.map { $0.formatted(.byteCount(style: .file)) })
        add(String(localized: "Pages"), document.pageCount.map { $0.formatted() })
        add(String(localized: "Language"), document.language.map { Locale.current.localizedString(forLanguageCode: $0) ?? $0 })
        add(String(localized: "Characters"), document.textLength.map { $0.formatted() })
        add(String(localized: "Source"), document.sourceType.map(AdminDocumentState.label(for:)))
        add(String(localized: "Uploaded"), document.createdAt.map { $0.formatted(date: .abbreviated, time: .shortened) })
        add(String(localized: "Last processed"), document.lastCompletedAt.map { $0.formatted(date: .abbreviated, time: .shortened) })
        return rows
    }

    /// I chunk dell'ultima indicizzazione completata, se la run lo dice.
    var chunkCount: Int? {
        runs.first { $0.pipelineType?.lowercased() == "ingestion" && $0.chunksCreated != nil }?.chunksCreated
    }

    // MARK: Anteprima

    /// Il server dà un link al file originale (per ora solo i documenti con `source.uri` https).
    var canPreview: Bool { document.fileURL != nil && !isDeleting }

    func openPreview() async {
        guard !isOpeningPreview, let url = document.fileURL else { return }
        isOpeningPreview = true
        defer { isOpeningPreview = false }
        do {
            let document = document
            previewURL = try await AdminDocumentsAPI.downloadFile(url, documentId: document.id,
                                                                  fileName: document.fileName, mimeType: document.mimeType)
            previewError = nil
        } catch {
            guard let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            previewError = String(localized: "Couldn't open the file: \(message)")
        }
    }

    // MARK: Caricamento

    func load() async {
        pollEpoch += 1
        async let documentTask: Void = loadDocument()
        async let runsTask: Void = loadRuns()
        _ = await (documentTask, runsTask)
    }

    private func loadDocument(silently: Bool = false) async {
        do {
            let fresh = try await backend.api.call(AdminDocumentsAPI.document(id: document.id))
            // Cancellazione conclusa (o 404 sotto): il documento non c'è più, si torna alla lista.
            guard !fresh.isDeleted else { return documentGone() }
            document = fresh
            documentError = nil
            onChange(fresh)
        } catch {
            if case .http(let status, _)? = error as? AriaError, status == 404, isDeleting { return documentGone() }
            guard !silently, let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            documentError = message
        }
    }

    private func documentGone() {
        onDelete(document.id)
        didDelete = true
    }

    private func loadRuns(silently: Bool = false) async {
        do {
            let page = try await backend.api.call(AdminDocumentsAPI.runs(id: document.id, limit: 20))
            runs = page.items.sorted { ($0.createdAt ?? $0.startedAt ?? .distantPast) > ($1.createdAt ?? $1.startedAt ?? .distantPast) }
            runsTotal = page.total
            hasLoadedRuns = true
            runsError = nil
        } catch {
            guard !silently, let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            runsError = message
        }
    }

    /// Finché una pipeline lavora, riaggiorna documento e run in silenzio, con attese crescenti
    /// (AdminDocumentPollSchedule). Senza rete salta il giro; si ferma con l'app non attiva o dopo troppa calma.
    func pollWhileWorking() async {
        var schedule = AdminDocumentPollSchedule()
        while isWorking, isAppActive, !didDelete, !schedule.isExhausted, !Task.isCancelled {
            do { try await Task.sleep(for: schedule.delay) } catch { return }
            // Offline: nessuna richiesta e nessun rallentamento, si riprova al giro dopo.
            guard network.isOnline else { continue }
            let before = progressSignature
            async let documentTask: Void = loadDocument(silently: true)
            async let runsTask: Void = loadRuns(silently: true)
            _ = await (documentTask, runsTask)
            schedule.recordTick(changed: progressSignature != before)
        }
    }

    // MARK: Azioni

    func ask(_ action: AdminDocumentAction) {
        pendingAction = action
        showsConfirmation = true
    }

    /// Esegue l'azione confermata. `removingExtractedData` vale solo per la cancellazione.
    func perform(_ action: AdminDocumentAction, removingExtractedData: Bool = false) async {
        guard !isPerforming else { return }
        isPerforming = true
        defer { isPerforming = false; pendingAction = nil }
        do {
            switch action {
            case .extract:
                _ = try await backend.api.call(AdminDocumentsAPI.extract(id: document.id, language: Self.language))
            case .ingest:
                guard let companyId = backend.activeCompanyId else { return }
                _ = try await backend.api.call(AdminDocumentsAPI.ingest(id: document.id, companyId: companyId))
            case .cancel:
                _ = try await backend.api.call(AdminDocumentsAPI.cancel(id: document.id))
            case .delete:
                _ = try await backend.api.call(AdminDocumentsAPI.delete(id: document.id, rollbackEntities: removingExtractedData))
                onDelete(document.id)
                didDelete = true
                return
            }
            // La pipeline è partita (o ferma): si rilegge, poi il ciclo di aggiornamento segue il resto.
            await load()
        } catch {
            guard let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            failedAction = action
            actionError = message
            showsActionError = true
        }
    }

    /// La lingua dei risultati dell'estrazione: quella dell'app.
    private static var language: String {
        Locale.current.language.languageCode?.identifier == "it" ? "it" : "en"
    }

    func makeChunksViewModel() -> AdminDocumentChunksViewModel {
        AdminDocumentChunksViewModel(backend: backend, documentId: document.id, title: document.displayName)
    }
}
