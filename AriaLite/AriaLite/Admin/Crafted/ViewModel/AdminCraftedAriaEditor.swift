//
//  AdminCraftedAriaEditor.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  "Modifica con Aria" (askAriaToEdit e useAriaEdit della web): il documento va ad Aria come blocchi, lei
//  risponde con quelli che ha cambiato e quella è una proposta — i lettori la mostrano contro la versione
//  attuale e solo se accettata diventa una versione. Lo stesso turno della chat (POST /v1/responses),
//  in una sessione a parte. Qui lo stato: richieste, avanzamento, modifiche man mano, conversazione. Il
//  lavoro vero sta in +Run (le parti) e +Turn (un turno).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedAriaEditor {
    /// Quante parti sono pronte, di quante; `whole` mentre il documento si legge intero in una conversazione.
    struct Progress: Hashable {
        var done: Int
        var total: Int
        var whole: Bool
    }

    /// Una riga della conversazione: l'istruzione dell'operatore, o la risposta di Aria (o perché non ci è riuscita).
    struct Line: Identifiable, Hashable {
        let id = UUID()
        let isAria: Bool
        let text: String
    }

    /// Com'è finita una richiesta.
    enum Outcome {
        case proposal(AdminCraftedAriaProposal)
        case failed(String)
        case cancelled
    }

    let backend: AriaBackend
    let companyId: String?
    /// Lo stabilimento del documento, se ne ha uno suo (un rapporto); altrimenti quello attivo.
    var plantId: String?

    private(set) var isRunning = false
    private(set) var progress: Progress?
    /// Le modifiche arrivate finora, mentre le parti tornano.
    private(set) var partial: [AdminCraftedAriaChange] = []
    private(set) var thread: [Line] = []
    /// Le istruzioni date, in ordine: quello che la versione dirà di aver chiesto.
    private(set) var instructions: [String] = []
    /// La conversazione in cui Aria ha lavorato; un seguito si chiede nella stessa.
    private(set) var sessionId: String?

    @ObservationIgnored var task: Task<Void, Never>?
    @ObservationIgnored var generation = 0
    @ObservationIgnored var changesHandler: (@MainActor ([AdminCraftedAriaChange]) -> Void)?

    init(backend: AriaBackend, companyId: String?) {
        self.backend = backend
        self.companyId = companyId
    }

    // MARK: Stato

    /// Perché adesso non si può chiedere niente (nessuno stabilimento), altrimenti `nil`.
    var blockedReason: String? {
        (plantId ?? backend.activePlantId) == nil ? String(localized: "Pick a plant to ask Aria to make something.") : nil
    }

    var progressText: String? {
        guard let progress else { return nil }
        return progress.whole
            ? String(localized: "reading the whole document · \(progress.done) of \(progress.total) parts")
            : String(localized: "\(progress.done) of \(progress.total) parts done")
    }

    /// Cosa si dice della richiesta nella versione accettata; `nil` finché Aria non ha lavorato.
    func request(requestedBy: String?) -> AdminCraftedAriaRequest? {
        guard let sessionId, !instructions.isEmpty else { return nil }
        return AdminCraftedAriaRequest(instruction: instructions.joined(separator: " → "), requestedBy: requestedBy,
                                       sessionId: sessionId)
    }

    // MARK: Azioni

    /// Chiede ad Aria di cambiare `blocks`. Un seguito (dopo una prima risposta) va nella stessa sessione, e i
    /// blocchi sono il documento come la proposta già sulla pagina lo ha lasciato. `onChanges` dà le modifiche
    /// man mano che le parti tornano; `completion`, com'è finita.
    func ask(instruction: String, title: String, blocks: [AdminCraftedAriaBlock], focus: String? = nil, locale: String? = nil,
             onChanges: @escaping @MainActor ([AdminCraftedAriaChange]) -> Void,
             completion: @escaping @MainActor (Outcome) -> Void) {
        let text = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isRunning, !text.isEmpty, blockedReason == nil else { return }
        isRunning = true
        progress = nil
        partial = []
        thread.append(Line(isAria: false, text: text))
        changesHandler = { [weak self] changes in
            self?.partial = changes
            onChanges(changes)
        }
        let token = generation
        task = Task(name: "aria.crafted.edit") {
            let outcome: Outcome
            do {
                let proposal = try await self.perform(instruction: text, title: title, blocks: blocks, focus: focus,
                                                      locale: locale, continuing: self.sessionId)
                guard token == self.generation else { return }
                self.sessionId = proposal.sessionId
                self.instructions.append(text)
                let reply = proposal.note ?? (proposal.changes.isEmpty
                    ? String(localized: "Aria did not change anything")
                    : String(localized: "Done — the change is on the page."))
                self.thread.append(Line(isAria: true, text: reply))
                outcome = .proposal(proposal)
            } catch {
                guard token == self.generation else { return }
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                    outcome = .cancelled
                } else {
                    let message = self.failureText(error)
                    self.thread.append(Line(isAria: true, text: message))
                    outcome = .failed(message)
                }
            }
            self.isRunning = false
            self.progress = nil
            self.partial = []
            self.task = nil
            completion(outcome)
        }
    }

    /// Ferma la richiesta in corso; `completion` arriva con `.cancelled`.
    func cancel() { task?.cancel() }

    /// Chiude tutto: ferma quello che gira e dimentica la conversazione (si chiude il pannello).
    func reset() {
        generation += 1
        task?.cancel()
        task = nil
        isRunning = false
        progress = nil
        partial = []
        thread = []
        instructions = []
        sessionId = nil
        changesHandler = nil
    }

    // MARK: Per +Run

    func setProgress(done: Int, total: Int, whole: Bool) {
        progress = total > 1 ? Progress(done: done, total: total, whole: whole) : nil
    }

    // MARK: Errori

    /// Il vero motivo, non un "non ci sono riuscito" generico: le parole di Aria, cosa ha fatto il suo turno
    /// invece di rispondere, o quello che ha detto il server.
    private func failureText(_ error: any Error) -> String {
        if let error = error as? AdminCraftedAriaError {
            switch error {
            case .noEdit(let text, let reason):
                if !text.isEmpty { return String(text.prefix(600)) }
                return failedWith(reason ?? "empty answer")
            case .tooLong:
                return failedWith(String(localized: "the document is too long for Aria to read in one conversation"))
            case .instructionTooLong:
                return String(localized: "Your instruction is too long. Shorten it and try again.")
            }
        }
        switch error {
        // La richiesta non è mai arrivata: bloccata lungo la strada, o la connessione è caduta.
        case AriaError.wafBlocked, AriaError.serverOffline, is URLError:
            return String(localized: "The request did not reach Aria — it was refused on the way or the connection dropped. Try again.")
        default:
            let reason = AdminCraftedFailure.message(for: error, backend: backend) ?? error.localizedDescription
            return failedWith(String(reason.prefix(240)))
        }
    }

    private func failedWith(_ reason: String) -> String {
        String(localized: "Aria could not edit the document (\(reason)). Try again.")
    }
}
