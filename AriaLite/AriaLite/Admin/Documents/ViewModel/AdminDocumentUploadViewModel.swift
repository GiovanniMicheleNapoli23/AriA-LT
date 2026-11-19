//
//  AdminDocumentUploadViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il caricamento di documenti da Files: stabilimento, pipeline da avviare, file scelti. Prima di inviare
//  chiede al server quali nomi esistono già e fa scegliere: sostituirli o saltarli. L'invio lo fa
//  AdminDocumentUploadCenter, in background: il foglio si chiude appena i file gli sono affidati.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDocumentUploadViewModel {
    let backend: AriaBackend
    private let uploads: AdminDocumentUploadCenter
    private let store: AdminDocumentUploadStore

    var plantId: String?
    /// Indicizzazione (RAG): Aria può citare il documento nelle risposte.
    var runIndexing = true
    /// Estrazione (CMMS): asset, ricambi e procedure proposti per la revisione.
    var runExtraction = true

    private(set) var files: [AdminDocumentUploadFile] = []
    /// I nomi già presenti nello stabilimento scelto.
    private(set) var conflicts: Set<String> = []
    private(set) var isCheckingConflicts = false
    private(set) var conflictCheckError: String?
    private(set) var isReading = false

    /// I file si stanno affidando al caricamento in background (token, richieste): un attimo.
    private(set) var isUploading = false
    private(set) var errorMessage: String?
    var showsConflictChoice = false
    /// Tutto affidato: la vista si chiude.
    private(set) var didFinish = false

    init(backend: AriaBackend, plantId: String?, uploads: AdminDocumentUploadCenter,
         store: AdminDocumentUploadStore = .shared) {
        self.backend = backend
        self.uploads = uploads
        self.store = store
        self.plantId = plantId ?? backend.plants.first?.id
    }

    var plants: [AriaPlant] { backend.plants }

    var plantName: String? {
        guard let plantId else { return nil }
        return plants.first { $0.id == plantId }?.name
    }

    /// Cambia quando va rifatto il controllo dei nomi: stabilimento o file scelti.
    var conflictKey: String { "\(plantId ?? "-")|\(files.map(\.filename).joined(separator: "/"))" }

    var pipelines: [String] {
        (runIndexing ? ["ingestion"] : []) + (runExtraction ? ["extraction"] : [])
    }

    var canUpload: Bool {
        !files.isEmpty && plantId != nil && !pipelines.isEmpty && !isUploading && !isReading && !isCheckingConflicts
    }

    var totalSize: String {
        files.reduce(0) { $0 + $1.size }.formatted(.byteCount(style: .file))
    }

    func isConflicting(_ file: AdminDocumentUploadFile) -> Bool { conflicts.contains(file.filename) }

    var conflictMessage: String {
        let count = conflicts.count
        return String(localized: "\(count) files already exist on this site. Replace them, or upload only the new ones?")
    }

    // MARK: File

    /// I file scelti in Files: si copiano fuori dal main actor; un nome già in lista non si ripete.
    func filesImported(_ result: Result<[URL], any Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = AdminDocumentsFailure.message(for: error, backend: backend)
        case .success(let urls):
            isReading = true
            defer { isReading = false }
            var failed: [String] = []
            var added: [AdminDocumentUploadFile] = []
            for url in urls {
                guard !(files + added).contains(where: { $0.filename == url.lastPathComponent }) else { continue }
                do {
                    added.append(try await AdminDocumentUploadFile.read(url, into: store))
                } catch {
                    failed.append(url.lastPathComponent)
                }
            }
            // Tutti insieme: il controllo dei doppioni riparte una volta sola.
            files += added
            errorMessage = failed.isEmpty ? nil
                : String(localized: "Couldn't read \(failed.joined(separator: ", ")).")
        }
    }

    func remove(_ file: AdminDocumentUploadFile) {
        files.removeAll { $0.id == file.id }
        conflicts.remove(file.filename)
        store.discardBody(file.id)
    }

    /// Le copie dei file non affidati non servono più.
    private func discardUnsent() {
        files.forEach { store.discardBody($0.id) }
        files = []
    }

    // MARK: Conflitti

    /// Chiede al server quali nomi esistono già nello stabilimento.
    func checkConflicts() async {
        guard let companyId = backend.activeCompanyId, let plantId, !files.isEmpty else {
            conflicts = []
            conflictCheckError = nil
            return
        }
        let names = files.map(\.filename)
        isCheckingConflicts = true
        defer { isCheckingConflicts = false }
        do {
            let response = try await backend.api.call(AdminDocumentsAPI.conflicts(companyId: companyId, plantId: plantId, fileNames: names))
            guard !Task.isCancelled else { return }
            conflicts = AdminDocumentConflicts.names(in: response, requested: names)
            conflictCheckError = nil
        } catch {
            guard let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            // Non blocca: il caricamento resta possibile, solo senza la scelta sui doppioni.
            conflicts = []
            conflictCheckError = message
        }
    }

    // MARK: Invio

    /// "Upload": con doppioni si chiede prima cosa farne.
    func startUpload() async {
        if conflicts.isEmpty {
            await upload(replacing: false)
        } else {
            showsConflictChoice = true
        }
    }

    /// Affida i file al caricamento in background. `replacing`: i doppioni sostituiscono i documenti esistenti;
    /// altrimenti si saltano.
    func upload(replacing: Bool) async {
        guard canUpload, let companyId = backend.activeCompanyId, let plantId else { return }
        let queue = replacing ? files : files.filter { !conflicts.contains($0.filename) }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        let notSaved = await uploads.enqueue(queue, companyId: companyId, plantId: plantId, pipelines: pipelines,
                                             replacing: replacing ? conflicts : [])
        // Un file che non è partito resta nel foglio, con il motivo; i saltati si buttano.
        guard notSaved.isEmpty else {
            files = notSaved
            errorMessage = String(localized: "Couldn't start uploading \(notSaved.map(\.filename).joined(separator: ", ")).")
            return
        }
        files.removeAll { file in queue.contains { $0.id == file.id } }
        discardUnsent()
        didFinish = true
    }
}

/// Per `.sheet(item:)`: ogni apertura è un caricamento nuovo.
extension AdminDocumentUploadViewModel: Identifiable {}
