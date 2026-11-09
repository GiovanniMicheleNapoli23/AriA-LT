//
//  AdminCraftedGenerator.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Chiedere un artifact ad Aria senza lasciare Crafted (generate-artifact.ts della web): lo stesso turno
//  della chat — POST /v1/responses in streaming, in una sessione nuova per ogni artifact — piegato con
//  `AriaAgentMessage.apply`. Di quello che arriva si tengono i deliverable (AdminCraftedOutcome). Vive
//  nel VM di Crafted, non nella schermata: cambiare sezione non ferma il turno.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedGenerator {
    private let backend: AriaBackend
    private let store: AdminCraftedArtifactStore

    /// Gli artifact con un turno in corso su questo dispositivo.
    private(set) var running: Set<String> = []
    /// L'ultima risposta di ogni artifact: in arrivo, o appena finita (prima che il server l'abbia a registro).
    private(set) var live: [String: AriaAgentMessage] = [:]

    /// Un turno in corso: il token distingue il turno vecchio, fermato, da quello nuovo dello stesso artifact.
    private struct Run {
        let token: UUID
        let task: Task<Void, Never>
    }

    @ObservationIgnored private var runs: [String: Run] = [:]

    init(backend: AriaBackend, store: AdminCraftedArtifactStore) {
        self.backend = backend
        self.store = store
    }

    // MARK: Stato

    func isGenerating(_ id: String) -> Bool { running.contains(id) }

    /// La risposta di questo dispositivo: in streaming, o appena finita.
    func liveMessage(_ id: String) -> AriaAgentMessage? { live[id] }

    /// Nessun turno in corso (il VM può lasciar andare un generatore vecchio).
    var isIdle: Bool { running.isEmpty }

    /// Perché adesso non si può creare niente (nessuno stabilimento), altrimenti `nil`.
    var blockedReason: String? {
        backend.activePlantId == nil ? String(localized: "Pick a plant to ask Aria to make something.") : nil
    }

    // MARK: Azioni

    /// Crea la riga e fa partire il turno: la riga c'è prima che Aria abbia cominciato. `nil` senza stabilimento.
    @discardableResult
    func create(request: String) -> AdminCraftedArtifact? {
        let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard blockedReason == nil, !request.isEmpty else { return nil }
        let artifact = store.create(request: request, sessionId: AriaNanoID.make())
        start(artifact)
        return artifact
    }

    /// Riprova nella stessa sessione, con la stessa richiesta incorniciata.
    func retry(_ id: String) {
        guard !isGenerating(id), blockedReason == nil, let artifact = store.get(id) else { return }
        store.update(id, status: .generating, note: .some(nil))
        start(artifact)
    }

    /// Ferma il turno di un artifact, se ce n'è uno (un'eliminazione a metà). Il turno fermato non scrive più niente.
    func cancel(_ id: String) {
        runs[id]?.task.cancel()
        runs[id] = nil
        running.remove(id)
        live[id] = nil
    }

    /// All'uscita dall'account: ferma tutto.
    func cancelAll() {
        for id in Array(runs.keys) { cancel(id) }
    }

    /// Tiene la riga allineata alla sua conversazione com'è sul server (recordConversation della web): stato, nome e
    /// card, scritti solo se qualcosa è cambiato. Una riga ancora "generating", senza turno in corso e senza una
    /// risposta registrata, è una che un riavvio ha interrotto: diventa fallita, così si può riprovare.
    func record(_ id: String, messages: [AriaAgentMessage]) {
        guard !isGenerating(id), let artifact = store.get(id) else { return }
        guard messages.contains(where: { $0.role == .assistant }) else {
            if artifact.status == .generating, live[id] == nil {
                store.update(id, status: .failed, artifacts: [], note: .some(nil))
            }
            return
        }
        var outcome = AdminCraftedOutcome.of(messages)
        // Un nome dato a mano resta: il titolo della risposta vale solo finché la riga ha quello automatico.
        if artifact.title != AdminCraftedOutcome.titleFrom(artifact.request) { outcome.title = nil }
        let same = outcome.status == artifact.status
            && outcome.note == artifact.note
            && (outcome.title ?? artifact.title) == artifact.title
            && outcome.artifacts.count == artifact.artifacts.count
        if !same { store.update(id, outcome: outcome) }
    }

    // MARK: Turno

    /// La richiesta incorniciata come domanda di un artifact (compose.prompt della web).
    nonisolated static func framedPrompt(_ request: String) -> String {
        String(localized: "Make an artifact (a chart, a table, a dashboard or a plan, whichever fits best) for this request:")
            + "\n\n" + request
    }

    private func start(_ artifact: AdminCraftedArtifact) {
        let id = artifact.id
        guard runs[id] == nil else { return }
        live[id] = nil
        running.insert(id)
        let token = UUID()
        let task = Task(name: "aria.crafted.generate") {
            await self.generate(artifact, token: token)
        }
        runs[id] = Run(token: token, task: task)
    }

    private func finish(_ id: String, token: UUID) {
        guard runs[id]?.token == token else { return }
        runs[id] = nil
        running.remove(id)
    }

    private func generate(_ artifact: AdminCraftedArtifact, token: UUID) async {
        let id = artifact.id
        defer { finish(id, token: token) }
        var message = AriaAgentMessage(id: "crafted-\(id)", role: .assistant, finished: false)
        do {
            let ctx = await backend.api.context.snapshot()
            guard let plantId = ctx.plantId, !plantId.isEmpty else { throw AriaError.missingPlant }
            // Stile "auto"; `includeMetadataEvents` resta acceso: la griglia KPI arriva solo con i metadati.
            let request = AriaResponsesRequest(input: Self.framedPrompt(artifact.request), plantId: plantId,
                                               sessionId: artifact.sessionId, companyId: store.companyId,
                                               style: AriaChatStyle.auto.rawValue, locale: ctx.locale)
            for try await event in backend.api.stream(request) {
                guard !Task.isCancelled else { return }
                message.apply(event)
                live[id] = message
            }
            guard !Task.isCancelled else { return }
            message.finished = true
            live[id] = message
            let outcome = AdminCraftedOutcome.of([message])
            store.update(id, outcome: outcome)
            // Il server chiama la sessione col primo messaggio, cioè la frase di cornice: nella cronologia
            // della chat deve comparire per quello che è stato fatto.
            let title = outcome.title ?? store.get(id)?.title ?? artifact.title
            let chat = AriaChatAPI(api: backend.api)
            Task(name: "aria.crafted.rename") { _ = try? await chat.rename(sessionId: artifact.sessionId, title: title) }
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            let note = AriaHTTP.isOffline(error)
                ? AriaError.serverOffline.localizedDescription
                : (AdminCraftedFailure.message(for: error, backend: backend) ?? error.localizedDescription)
            store.update(id, status: .failed, artifacts: [], note: .some(note))
        }
    }
}
