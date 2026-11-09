//
//  AdminDocumentUploadCenter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  I caricamenti di documenti in corso, fuori dal foglio che li ha scelti: vive in AdminDocumentsViewModel,
//  quindi il foglio si chiude subito e l'invio continua (anche in background, con AdminDocumentUploadSession).
//  Ogni file ha la sua barra; uno fallito resta con il motivo per riprovarlo o toglierlo. Un 401 si riprova
//  da solo una volta con un token nuovo. All'avvio ritrova i caricamenti lasciati dall'esecuzione precedente.
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class AdminDocumentUploadCenter {
    private let backend: AriaBackend
    private let session: AdminDocumentUploadSession
    private let store: AdminDocumentUploadStore

    /// Un documento è arrivato al server: chi tiene la lista la ricarica.
    @ObservationIgnored var onUploaded: () -> Void = {}

    private(set) var jobs: [AdminDocumentUploadJob] = []
    /// Frazione inviata (0…1) dei job in corso.
    private(set) var progress: [UUID: Double] = [:]
    @ObservationIgnored private var didStart = false

    init(backend: AriaBackend, session: AdminDocumentUploadSession = .shared, store: AdminDocumentUploadStore = .shared) {
        self.backend = backend
        self.session = session
        self.store = store
    }

    var isEmpty: Bool { jobs.isEmpty }
    var activeCount: Int { jobs.count { !$0.isFailed } }

    /// Avanzamento complessivo dei job in corso, pesato sui byte.
    var overallProgress: Double {
        let active = jobs.filter { !$0.isFailed }
        let total = active.reduce(0) { $0 + max($1.size, 1) }
        guard total > 0 else { return 0 }
        let sent = active.reduce(0.0) { $0 + Double(max($1.size, 1)) * (progress[$1.id] ?? 0) }
        return sent / Double(total)
    }

    func progress(of job: AdminDocumentUploadJob) -> Double { progress[job.id] ?? 0 }

    // MARK: Avvio

    /// Ascolta la sessione e ritrova i job salvati: quelli che il sistema invia ancora riprendono la barra,
    /// gli altri (app chiusa prima di affidarli, o chiusa dall'utente) restano come interrotti.
    func start() async {
        guard !didStart else { return }
        didStart = true
        session.setListener { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        store.sweepOrphans()
        let saved = store.jobs()
        guard !saved.isEmpty else { return }
        if saved.contains(where: { !$0.isFailed }) {
            let live = await session.liveJobs()
            for job in saved where !job.isFailed {
                if let fraction = live[job.id] {
                    progress[job.id] = fraction
                } else {
                    store.markFailed(job.id, message: String(localized: "The upload was interrupted."))
                }
            }
        }
        jobs = store.jobs()
    }

    // MARK: Invio

    /// Affida i file scelti alla sessione in background. `replacing`: i nomi che sostituiscono un documento esistente.
    /// Restituisce i file che non si sono potuti affidare (job non salvato): restano a chi li ha scelti.
    func enqueue(_ files: [AdminDocumentUploadFile], companyId: String, plantId: String,
                 pipelines: [String], replacing: Set<String>) async -> [AdminDocumentUploadFile] {
        await start()
        // Il token e le richieste si preparano anche se l'utente esce subito dall'app. Se il tempo finisce prima,
        // iOS chiama la scadenza: il task si chiude lì (altrimenti chiude l'app) e i job restano da riprovare.
        let box = BackgroundTaskBox()
        box.id = UIApplication.shared.beginBackgroundTask(withName: "aria.documents.enqueue") {
            UIApplication.shared.endBackgroundTask(box.id)
            box.id = .invalid
        }
        defer { if box.id != .invalid { UIApplication.shared.endBackgroundTask(box.id) } }
        var notSaved: [AdminDocumentUploadFile] = []
        for file in files {
            let job = AdminDocumentUploadJob(file: file, companyId: companyId, plantId: plantId, pipelines: pipelines,
                                             replaceExisting: replacing.contains(file.filename))
            do {
                try store.save(job)
            } catch {
                notSaved.append(file)
                continue
            }
            jobs.append(job)
            progress[job.id] = 0
            await send(job)
        }
        return notSaved
    }

    func retry(_ job: AdminDocumentUploadJob) async {
        guard var job = store.job(job.id) else { return dismiss(job) }
        job.failure = nil
        job.authRetries = 0
        try? store.save(job)
        replace(job)
        progress[job.id] = 0
        await send(job)
    }

    /// Toglie il job dalla lista e ferma l'invio, se c'è.
    func dismiss(_ job: AdminDocumentUploadJob) {
        store.remove(job.id)
        jobs.removeAll { $0.id == job.id }
        progress[job.id] = nil
        let session = session
        Task { await session.cancel(job.id) }
    }

    /// Butta le copie dei file scelti e mai affidati (foglio chiuso senza caricare).
    func discardUnsentFiles() {
        store.sweepOrphans()
    }

    private func send(_ job: AdminDocumentUploadJob) async {
        do {
            let request = try await AdminDocumentsUploadRequest.make(for: job, api: backend.api)
            session.enqueue(request, jobId: job.id)
        } catch {
            fail(job.id, error)
        }
    }

    // MARK: Eventi

    private func handle(_ event: AdminDocumentUploadSession.Event) {
        switch event {
        case .progress(let id, let fraction):
            guard jobs.contains(where: { $0.id == id && !$0.isFailed }) else { return }
            progress[id] = fraction
        case .finished(let id, .uploaded):
            jobs.removeAll { $0.id == id }
            progress[id] = nil
            onUploaded()
        case .finished(let id, .unauthorized):
            guard var job = store.job(id) else { return }
            guard job.authRetries == 0 else { return fail(id, AriaError.http(status: 401, detail: "")) }
            job.failure = nil
            job.authRetries += 1
            try? store.save(job)
            replace(job)
            progress[id] = 0
            Task {
                await backend.api.auth.invalidate()
                await send(job)
            }
        case .finished(let id, .failed(let error)):
            fail(id, error)
        }
    }

    private func fail(_ id: UUID, _ error: any Error) {
        // Un job tolto dalla lista (invio annullato) non torna.
        guard jobs.contains(where: { $0.id == id }) else { return }
        let message = AdminDocumentsFailure.message(for: error, backend: backend) ?? error.localizedDescription
        store.markFailed(id, message: message)
        progress[id] = nil
        if let job = store.job(id) { replace(job) }
    }

    private func replace(_ job: AdminDocumentUploadJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) { jobs[index] = job }
    }

    /// All'uscita dall'account: niente invii né copie dei file dell'azienda precedente.
    func reset() {
        // Senza job (il caso di quasi ogni uscita) la sessione in background non si apre nemmeno.
        let hadJobs = !jobs.isEmpty || !store.jobs().isEmpty
        jobs = []
        progress = [:]
        store.removeAll()
        guard hadJobs else { return }
        let session = session
        Task { await session.cancelAll() }
    }
}

private final class BackgroundTaskBox {
    var id: UIBackgroundTaskIdentifier = .invalid
}
