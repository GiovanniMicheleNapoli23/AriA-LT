//
//  AdminDocumentUploadViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il caricamento di documenti da Files: stabilimento, pipeline da avviare, file scelti. Prima di inviare
//  chiede al server quali nomi esistono già e fa scegliere: sostituirli o saltarli. I file partono uno alla volta.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDocumentUploadViewModel {
    let backend: AriaBackend

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

    private(set) var isUploading = false
    /// Avanzamento complessivo (0…1) e file in invio.
    private(set) var progress: Double = 0
    private(set) var currentFileName: String?
    private(set) var errorMessage: String?
    var showsConflictChoice = false
    /// Tutto inviato: la vista si chiude.
    private(set) var didFinish = false
    private(set) var uploadedCount = 0

    init(backend: AriaBackend, plantId: String?) {
        self.backend = backend
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
        return String(localized: "\(count) files already exist in this plant. Replace them, or upload only the new ones?")
    }

    // MARK: File

    /// I file scelti in Files: si leggono fuori dal main actor; un nome già in lista non si ripete.
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
                do {
                    let file = try await AdminDocumentUploadFile.read(url)
                    guard !(files + added).contains(where: { $0.filename == file.filename }) else { continue }
                    added.append(file)
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

    /// Invia i file uno alla volta. `replacing`: i doppioni sostituiscono i documenti esistenti;
    /// altrimenti si saltano. Quelli che falliscono restano in lista con il motivo.
    func upload(replacing: Bool) async {
        guard canUpload, let companyId = backend.activeCompanyId, let plantId else { return }
        let queue = replacing ? files : files.filter { !conflicts.contains($0.filename) }
        guard !queue.isEmpty else {
            didFinish = true
            return
        }
        isUploading = true
        errorMessage = nil
        progress = 0
        defer {
            isUploading = false
            currentFileName = nil
        }
        let uploader = AdminDocumentsUploader(api: backend.api)
        let pipelines = pipelines
        var failures: [String] = []
        for (index, file) in queue.enumerated() {
            currentFileName = file.filename
            let base = Double(index) / Double(queue.count)
            let share = 1 / Double(queue.count)
            do {
                try await uploader.upload(file, companyId: companyId, plantId: plantId, pipelines: pipelines,
                                          replaceExisting: replacing && conflicts.contains(file.filename)) { [weak self] sent in
                    let model = self
                    Task { @MainActor in model?.progress = base + sent * share }
                }
                files.removeAll { $0.id == file.id }
                uploadedCount += 1
            } catch {
                let reason = AdminDocumentsFailure.message(for: error, backend: backend) ?? error.localizedDescription
                failures.append("\(file.filename): \(reason)")
            }
            progress = base + share
        }
        if failures.isEmpty {
            didFinish = true
        } else {
            errorMessage = failures.joined(separator: "\n")
        }
    }
}

/// Per `.sheet(item:)`: ogni apertura è un caricamento nuovo.
extension AdminDocumentUploadViewModel: Identifiable {}
