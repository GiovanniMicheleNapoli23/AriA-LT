//
//  AdminDocumentDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un documento: metadati, stato delle pipeline, run e azioni (estrai, indicizza,
//  ferma, cancella) con conferma. Mentre una pipeline lavora si riaggiorna da solo ogni pochi secondi.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDocumentDetailViewModel {
    let backend: AriaBackend
    private let onChange: (AdminDocument) -> Void
    private let onDelete: (String) -> Void

    static let pollInterval: Duration = .seconds(4)

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

    init(backend: AriaBackend, document: AdminDocument,
         onChange: @escaping (AdminDocument) -> Void, onDelete: @escaping (String) -> Void) {
        self.backend = backend
        self.document = document
        self.onChange = onChange
        self.onDelete = onDelete
    }

    // MARK: Stato

    /// Qualcosa lavora: il documento o una delle sue run.
    var isWorking: Bool { document.isProcessing || runs.contains(where: \.isActive) }

    var pollKey: String { "\(document.id)|\(isWorking)" }

    var isDeleting: Bool { document.statusGroup == .deleting }
    var canCancel: Bool { isWorking && !isDeleting && !isPerforming }
    var canRerun: Bool { !isWorking && !isDeleting && !isPerforming && backend.activeCompanyId != nil }
    var canDelete: Bool { !isDeleting && !isPerforming }

    var ingestionLabel: String? { document.ingestionState.map(AdminDocumentState.label(for:)) }
    var extractionLabel: String? { document.extractionState.map(AdminDocumentState.label(for:)) }

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

    // MARK: Caricamento

    func load() async {
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

    /// Finché una pipeline lavora, riaggiorna documento e run in silenzio.
    func pollWhileWorking() async {
        while isWorking, !didDelete, !Task.isCancelled {
            do { try await Task.sleep(for: Self.pollInterval) } catch { return }
            async let documentTask: Void = loadDocument(silently: true)
            async let runsTask: Void = loadRuns(silently: true)
            _ = await (documentTask, runsTask)
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
